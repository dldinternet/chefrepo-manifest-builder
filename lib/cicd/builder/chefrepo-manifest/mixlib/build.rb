
module CiCd
  module Builder
    # noinspection RubySuperCallWithoutSuperclassInspection
    module ChefRepoManifest
      module Build

        # ---------------------------------------------------------------------------------------------------------------
        # noinspection RubyHashKeysTypesInspection
        def prepareBuild()
          super
          if @vars[:return_code] == 0
          end
          @vars[:return_code]
        end

        # ---------------------------------------------------------------------------------------------------------------
        def packageBuild()
          @logger.step __method__.to_s
          if isSameDirectory(Dir.pwd, ENV['WORKSPACE'])
            if @vars.has_key?(:components) and not @vars[:components].empty?
              @vars[:return_code] = 0

              clazz = getRepoClass('S3')
              @logger.debug "Repo class == '#{clazz}'"
              if clazz.is_a?(Class) and not clazz.nil?
                @repo = clazz.new(self)

                if @vars[:return_code] == 0
                  lines             = []
                  @vars[:artifacts] = []
                  # Deal with all artifacts of each component
                  @vars[:components].each { |comp|
                    processComponent(comp, lines)
                  }
                  if @vars[:return_code] == 0
                    cleanupAfterPackaging(lines)
                  end

                else
                  @logger.fatal "S3 repo error: Bucket #{ENV['AWS_S3_BUCKET']}"
                end
              else
                @logger.error "CiCd::Builder::Repo::#{type} is not a valid repo class"
                @vars[:return_code] = Errors::BUILDER_REPO_TYPE
              end
            else
              @logger.error 'No components found during preparation?'
              @vars[:return_code] = Errors::NO_COMPONENTS
            end
          else
            @logger.error "Not in WORKSPACE? '#{pwd}' does not match WORKSPACE='#{workspace}'"
            @vars[:return_code] = Errors::WORKSPACE_DIR
          end

          @vars[:return_code]
        end

      end
    end
  end
end
