require 'artifactory'
require 'tmpdir'

module CiCd
  module Builder
    # noinspection RubySuperCallWithoutSuperclassInspection
    module Manifest
      module Repo
        class Artifactory < CiCd::Builder::Repo::Artifactory
          # include ::Artifactory::Resource

          # ---------------------------------------------------------------------------------------------------------------
          def initialize(builder)
            super
          end

          # ---------------------------------------------------------------------------------------------------------------
          def uploadToRepo(artifacts)
            @manifest = {}
            super
            if @vars[:return_code] == 0
              # Preserve the manifest (maybeUploadArtifactoryObject will add everything we upload to the instance var)
              manifest = @manifest.dup
              # Create a manifest for each product and store it.
              createProductManifests(manifest)
              # Get a super manifest of all products and store as learning-manifest
              createSuperManifest(manifest) # -#{@vars[:variant]}
              @manifest = manifest
            end
            # If we are asked to produce a PROJECTS_FILE then we do that from the manifest and components.
            unless ENV['PROJECTS_FILE'].nil?
              if @vars[:return_code] == 0
                if File.directory?(File.realdirpath(File.dirname(ENV['PROJECTS_FILE'])))
                  createProjectsFile
                else
                  @logger.error "The path to the PROJECTS_FILE (#{File.dirname(ENV['PROJECTS_FILE'])}) does not exist!"
                  @vars[:return_code] = Errors::NO_PROJECTS_PATH
                end
              end
            end
            @vars[:artifacts].each do |art|
              if art[:data][:temp].is_a?(FalseClass)
                if File.exists?(art[:data][:file])
                  File.unlink(art[:data][:file]) if File.exists?(art[:data][:file])
                  art[:data].delete(:file)
                  art[:data].delete(:temp)
                else
                  @logger.warn "Temporary file disappeared: #{data.ai}"
                  @vars[:return_code] = Errors::TEMP_FILE_MISSING
                end
              end
            end
            @vars[:return_code]
          end

          # ---------------------------------------------------------------------------------------------------------------
          def createProjectsFile
            @logger.info __method__.to_s
            projects = {}
            project_names = loadProjectNames()
            exts = {}
            exts = Hash[@vars[:artifacts].map { |a| [a[:data][:name], File.basename(a[:data][:file]).match(CiCd::Builder::Manifest::Build::EXT_RGX)[1]] }]

            createClassesFile()

            @vars[:artifacts].each do |art|
              prod = art[:data][:name]
              mod  = art[:data][:module]
              projects[prod] = {
                                         name: project_names[prod] || prod,
                                       module: mod,
                                          ext: exts[prod],
                                 class_filter: @vars[:filters][prod] || @vars[:filters][prod.gsub(/-manifest$/, '')],
                               }
            end

            require 'chef/mash'
            require 'chef/mixin/deep_merge'

            projects_hash = File.exists?(ENV['PROJECTS_FILE']) ? loadConfigFile(ENV['PROJECTS_FILE']) : {}
            old_projects = ::Chef::Mash.new(projects_hash)
            projects = ::Chef::Mash.new(projects)
            projects = ::Chef::Mash.new(::Chef::Mixin::DeepMerge.deep_merge(projects, old_projects))
            saveConfigFile(ENV['PROJECTS_FILE'], projects)
            data = {
                          name: 'projects-file',
                        module: 'projects-file',
                          file: ENV['PROJECTS_FILE'],
                       version: @vars[:build_ver],
                         build: @vars[:build_num],
                    properties: @properties_matrix,
                          temp: false,
                          sha1: Digest::SHA1.file(ENV['PROJECTS_FILE']).hexdigest,
                           md5: Digest::MD5.file(ENV['PROJECTS_FILE']).hexdigest,
                   }

            maybeUploadArtifactoryObject(
                                                     data: data,
                                          artifact_module: data[:name],
                                         artifact_version: data[:version] || @vars[:version],
                                                file_name: '',
                                                 file_ext: (ENV['PROJECTS_FILE'] and ENV['PROJECTS_FILE'].downcase.match(/\.ya?ml$/)) ? 'yaml' : 'json'
                                        )
          end

          # ---------------------------------------------------------------------------------------------------------------
          # noinspection RubyHashKeysTypesInspection
          def createClassesFile()
            @logger.info __method__.to_s
            project_names = loadProjectNames()

            @vars[:classes] = YAML.load(IO.read(ENV['CLASSES_MANIFEST_FILE']))
            # keys = Hash[classes.keys.map.with_index.to_a].keys.sort

            @vars[:filters] = {}
            filters = {}
            @vars[:classes].each do |role,apps|
              apps.map{ |app|
                filters[app] ||= []
                filters[app] << role
              }
            end
            filters.each do |app,roles|
              @vars[:filters][app] = Hash[roles.map.with_index.to_a].keys.join('|')
            end

            saveConfigFile(ENV['CLASSES_FILE'],@vars[:classes])
            data = {
                              name: 'classes-file',
                            module: 'classes-file',
                              file: ENV['CLASSES_FILE'],
                           version: @vars[:build_ver],
                             build: @vars[:build_num],
                        properties: @properties_matrix,
                              temp: false,
                              sha1: Digest::SHA1.file(ENV['CLASSES_FILE']).hexdigest,
                               md5: Digest::MD5.file(ENV['CLASSES_FILE']).hexdigest,
                    }

            maybeUploadArtifactoryObject(
                                                     data: data,
                                          artifact_module: data[:name],
                                         artifact_version: data[:version] || @vars[:version],
                                                file_name: '',
                                                 file_ext: 'yaml'
                                        )
          end

          def saveConfigFile(file, projects)
            @logger.info "Save config file: #{file}"
            ext = file.gsub(/\.(\w+)$/, '\1')
            IO.write(file, case ext.downcase
                           when /ya?ml/
                             projects.to_hash.to_yaml line_width: 1024, indentation: 4, canonical: false
                           when /json|js/
                             JSON.pretty_generate(projects.to_hash, {indent: "\t", space: ' '})
                           else
                             raise "Unsupported extension: #{ext}"
                           end)
          end

          def loadConfigFile(file)
            ext = file.gsub(/\.(\w+)$/, '\1')
            hash = case ext.downcase
                   when /ya?ml/
                     YAML.load_file(ENV['PROJECTS_FILE'])
                   when /json|js/
                     JSON.load(IO.read(ENV['PROJECTS_FILE']))
                   else
                     raise "Unsupported extension: #{ext}"
                   end
          end

          def loadProjectNames(fresh=false)
            if fresh
              @project_names = nil
            end
            unless @project_names
              @project_names = {}
              unless ENV['PROJECT_NAMES'].nil?
                if File.exists?(ENV['PROJECT_NAMES'])
                  @logger.info "Load PROJECT_NAMES: #{ENV['PROJECT_NAMES']}"
                  @project_names = JSON.load(IO.read(ENV['PROJECT_NAMES'])) || {}
                else
                  @logger.error "The PROJECT_NAMES file (#{ENV['PROJECT_NAMES']}) does not exist!"
                  @vars[:return_code] = Errors::NO_PROJECT_NAMES
                end
              end
            end
            @project_names
          end

          def createSuperManifest(manifest)
            manifest_data = ''
            manifest.each do |mod, man|
              man.each do |k, v|
                manifest_data += "#{k}=#{v}\n"
              end
            end
            amn = artifactory_manifest_name # Just using a local iso invoking method_missing repeatedly ... ;)
            data = {module: amn, data: manifest_data, version: @vars[:build_ver], build: @vars[:build_num], properties: @properties_matrix}
            # tempArtifactFile(amn, data)

            data[:file] = Dir::Tmpname.create(amn) do |tmpnam, n, opts|
              mode = File::RDWR|File::CREAT|File::EXCL
              perm = 0600
              opts = perm
            end + '.properties'
            IO.write(data[:file], data[:data])
            data[:temp] = false
            data[:sha1] = Digest::SHA1.file(data[:file]).hexdigest
            data[:md5]  = Digest::MD5.file(data[:file]).hexdigest
            data[:name] = amn
            @vars[:artifacts] << {
                                    key: amn,
                                   data: data.dup,
                                 }
            # manifest[amn]={ amn => "#{@vars[:build_ver]}-#{@vars[:build_num]}" }

            maybeUploadArtifactoryObject(data: data, artifact_module: amn, artifact_version: data[:version] || @vars[:version], file_name: '', file_ext: 'properties')
          end

          # ---------------------------------------------------------------------------------------------------------------
          def createProductManifests(manifest)
            manifest.dup.each do |mod, man|
              manifest_data = ''
              man.each do |k, v|
                manifest_data += "#{k}=#{v}\n"
              end
              data = {
                            name: "#{mod}-manifest",
                          module: "#{mod}-manifest",
                       component: mod,
                            data: manifest_data,
                         version: @vars[:build_ver],
                           build: @vars[:build_num],
                      properties: @properties_matrix
              }
              # tempArtifactFile("#{mod}-manifest", data)

              data[:file] = Dir::Tmpname.create("#{mod}-manifest") do |tmpnam, n, opts|
                mode = File::RDWR|File::CREAT|File::EXCL
                perm = 0600
                opts = perm
              end + '.properties'
              IO.write(data[:file], data[:data])
              data[:temp] = false
              data[:sha1] = Digest::SHA1.file(data[:file]).hexdigest
              data[:md5]  = Digest::MD5.file(data[:file]).hexdigest
              @vars[:artifacts] << {
                                       key: "#{mod}-manifest",
                                      data: data.dup,
                                   }
              # noinspection RubyStringKeysInHashInspection
              # manifest["#{mod}-manifest"]={ "#{mod}-manifest" => "#{@vars[:build_ver]}-#{@vars[:build_num]}" }

              maybeUploadArtifactoryObject(data: data, artifact_module: data[:name], artifact_version: data[:version] || @vars[:version], file_name: '', file_ext: 'properties') # -#{@vars[:variant]}
            end
          end

          # ---------------------------------------------------------------------------------------------------------------
          def maybeUploadArtifactoryObject(args)
            super
            if @vars[:return_code] == 0
              data             = args[:data]
              artifact_module  = args[:artifact_module]
              artifact_version = args[:artifact_version]
              # file_ext         = args[:file_ext]
              # file_name        = args[:file_name]
              if @manifest[artifact_module].nil?
                @manifest[artifact_module] = {}
                file_name = artifact_module
              else
                file_name, _ = get_artifact_file_name_ext(data)
                if file_name.empty?
                  file_name = artifact_module
                else
                  file_name = "#{artifact_module}#{file_name}"
                end
              end
              @manifest[artifact_module][file_name] = artifact_version
            end

            @vars[:return_code]
          end

          private :createProductManifests, :createProjectsFile, :createSuperManifest
        end
      end
    end
  end
end

=begin

                {
                    "test-project": {
                        "name": "test-project",
                        "module": "test-server",
                        "ext": "war",
                        "class_filter": "role.role-1"
                    },
                    "test-project-2": {
                        "name": "test-project-2",
                        "module": "test-server2",
                        "ext": "zip",
                        "class_filter": "role.role-2"
                    },
                    "test-manifest": {
                        "name": "test-manifest",
                        "module": "test-manifest",
                        "ext": "properties",
                        "class_filter": ""
                    },
                    "test-manifest2": {
                        "name": "test-manifest2",
                        "module": "test-manifest2",
                        "ext": "properties",
                        "class_filter": ""
                    }
                }

=end
