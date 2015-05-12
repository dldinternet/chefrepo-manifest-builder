
module CiCd
  module Builder
    # noinspection RubySuperCallWithoutSuperclassInspection
    module ChefRepoManifest
      CLASS = 'CiCd::Builder::ChefRepoManifest'
      module Build

        # ---------------------------------------------------------------------------------------------------------------
        # noinspection RubyHashKeysTypesInspection
        def prepareBuild()
          @logger.step CLASS+'::'+__method__.to_s
          super
          if 0 == @vars[:return_code]
            # We throw away the Manifest builder's hard work on components because they don't apply to us]
            # We still call super because the grandparent does useful things we don't want to duplicate ... ;)
            @vars[:components] = {}
            # Now we need to dig the URL for the latest build of this BRANCH out of the INVENTORY for each of the set of products ... :(
            # Get the repo a little earlier than the typical build which uses it as a write target iso a read source
            getRepoInstance('S3')
            ENV['REPO_PRODUCTS'].split(/,\s+/).each do |product|
              if 0 == @vars[:return_code]
                key,json,over = @repo.pullInventory(product)
                if json.nil?
                  @logger.error "Bad repo/inventory specified. s3://#{ENV['AWS_S3_BUCKET']}/#{key}"
                  @vars[:return_code] = Errors::PRUNE_BAD_REPO
                else
                  versrels = nil
                  if json['container'] and json['container']['variants']
                    # but does not have our variant ...
                    variants = json['container']['variants']
                    @logger.info "\tVariants: #{variants.keys.size} \n#{variants.keys.ai}"
                    variants.each do |variant,varianth|
                      # If the inventory 'latest' format is up to date ...
                      bmax, bmin, releases, versions, versrels = @repo.getVariantVersionsAndReleases(varianth)
                      s = "Variant: #{variant}
                      \t#{varianth['builds'].size} builds
                      \t#{varianth['branches'].size} branches:\n#{varianth['branches'].ai}
                      \tBuild numbers: #{bmin}-#{bmax}
                      \tVersions: #{versions.ai}
                      \tReleases: #{releases.ai}
                      \tVersions per Release: #{versrels.ai}
                      "
                      @logger.info s.gsub(/\n\s+/, "\n\t")
                    end
                    if variants[@vars[:variant]]
                      varianth = variants[@vars[:variant]]
                      if varianth['latest'] and varianth['latest'].is_a?(Hash)
                        latest    = varianth['latest']['build']
                        builds    = varianth['builds']
                        branches  = varianth['branches']
                        versions  = varianth['versions']

                        drawer = if builds.size > latest
                                   builds[latest]
                                 else
                                   nil
                                 end
                        if drawer
                          ver = @repo._getVersion(@vars, drawer)
                          rel = @repo._getRelease(@vars, drawer)
                          bra = @repo._getBranch(@vars, drawer)
                          name = drawer['build_name'] rescue drawer['build']
                          var = @repo._getMatches(@vars, name, :variant)
                          num = @repo._getMatches(@vars, name, :build)
                          unless  var == @vars[:variant] &&
                                  ver == @vars[:version] &&
                                  rel == @vars[:release] &&
                                  bra == @vars[:branch]
                            drawer = nil
                          end
                        end
                        unless drawer
                          if branches.include?(@vars[:branch])
                            survivors = builds.select{ |dwr|
                              bra = @repo._getBranch(@vars, dwr)
                              bra == @vars[:branch]
                            }
                            builds = survivors
                            if versions.include?(@vars[:version])
                              survivors = builds.select{ |draw|
                                ver = @repo._getVersion(@vars, draw)
                                ver == @vars[:version]
                              }
                              builds = survivors
                              if versrels and versrels.include?("#{@vars[:version]}-#{@vars[:release]}")
                                survivors = builds.select{ |draw|
                                  rel = @repo._getRelease(@vars, draw)
                                  rel == @vars[:release]
                                }
                                builds = survivors
                                drawer = builds[-1]
                              else
                                @logger.error "Cannot manifest the version '#{@vars[:version]}' from variant '#{@vars[:variant]}'"
                                @vars[:return_code] = Errors::REPO_BAD_VERSION
                              end
                            else
                              @logger.error "Cannot manifest the version '#{@vars[:version]}' from variant '#{@vars[:variant]}'"
                              @vars[:return_code] = Errors::REPO_BAD_VERSION
                            end
                          else
                            @logger.error "Cannot manifest the branch '#{@vars[:branch]}' from variant '#{@vars[:variant]}'"
                            @vars[:return_code] = Errors::REPO_BAD_BRANCH
                          end
                        end
                        if drawer
                          # Get the artifacts ...
                          assembly = drawer['assembly'] || json['container']['assembly']
                          artifacts = drawer['artifacts'].select{|art|
                            art =~ /\.#{assembly['extension']}$/
                          }
                          if artifacts.size > 0
                            @logger.info "Found these artifacts: #{artifacts.ai}"
                            key = "#{product}/#{@vars[:variant]}/#{drawer['drawer']}/#{artifacts[0]}"
                            obj = @repo.maybeS3Object(key)
                            if obj
                              ver = @repo._getVersion(@vars, drawer)
                              rel = @repo._getRelease(@vars, drawer)
                              bra = @repo._getBranch(@vars, drawer)
                              name = drawer['build_name'] rescue drawer['build']
                              var = @repo._getMatches(@vars, name, :variant)
                              num = @repo._getMatches(@vars, name, :build)

                              @vars[:components][product] = {
                                  name: product,
                                  url: obj.public_url,
                                  version: ver,
                                  release: rel,
                                  branch: bra,
                                  variant: var,
                                  build: num,
                                  s3_bucket: ENV['AWS_S3_BUCKET'],
                                  s3_key: key,
                                  file_name: product,
                                  file_ext: assembly['extension'],
                              }

                              chksms = drawer['artifacts'].select{|art|
                                art =~ /\.checksum$/
                              }
                              if chksms.size > 0
                                chk = "#{product}/#{@vars[:variant]}/#{drawer['drawer']}/#{chksms[0]}"
                                chk_obj = @repo.maybeS3Object(chk)
                                if chk_obj
                                  out = chk_obj.get()
                                  if out
                                    sha256 = Digest::SHA256.new
                                    sha256.update(out[:body].is_a?(String) ? out[:body] : out[:body].read)
                                    @vars[:components][product][:sha256] = sha256.hexdigest
                                  end
                                end
                              end
                            else
                              @logger.error "Cannot manifest for #{key} ???"
                              @vars[:return_code] = Errors::REPO_NO_BUILD
                            end
                          else
                            @logger.error "No artifacts to manifest for #{key} ???"
                            @vars[:return_code] = Errors::REPO_NO_BUILD
                          end
                        else
                          @logger.error "Cannot find a build to manifest for #{product}-#{@vars[:version]}-release-#{@vars[:release]}-#{@vars[:branch]}-#{@vars[:variant]}"
                          @vars[:return_code] = Errors::REPO_NO_BUILD
                        end
                      else
                        # Start over ... too old/ incompatible
                        @logger.error 'Repo too old or incompatible to manifest. No [container][variants][VARIANT][latest].'
                        @vars[:return_code] = Errors::PRUNE_TOO_OLD
                      end
                    else
                      @logger.error 'Our variant has not been built!?'
                      @vars[:return_code] = Errors::REPO_NO_VARIANT
                    end
                  else
                    # Start over ... too old/ incompatible
                    @logger.error 'Repo too old or incompatible to manifest. No [container][variants].'
                    @vars[:return_code] = Errors::PRUNE_TOO_OLD
                  end
                end
              end
            end
          end

          @vars[:return_code]
        end

        # # ---------------------------------------------------------------------------------------------------------------
        # def packageBuild()
        #   @logger.info CLASS+'::'+__method__.to_s
        #   @vars[:return_code]
        # end

      end
    end
  end
end
