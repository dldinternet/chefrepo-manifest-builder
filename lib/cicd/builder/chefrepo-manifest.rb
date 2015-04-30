require 'cicd/builder/manifest'

module CiCd
  module Builder
    _lib=File.dirname(__FILE__)
    $:.unshift(_lib) unless $:.include?(_lib)

    require 'cicd/builder/chefrepo-manifest/version'

    module ChefRepoManifest
      class Runner < Manifest::Runner
        require 'cicd/builder/chefrepo-manifest/mixlib/build'
        include CiCd::Builder::ChefRepoManifest::Build
        require 'cicd/builder/chefrepo-manifest/mixlib/repo'
        include CiCd::Builder::ChefRepoManifest::Repo

        # ---------------------------------------------------------------------------------------------------------------
        def initialize()
          super
          @klass = 'CiCd::Builder::ChefRepoManifest'
          @default_options[:builder] = VERSION
        end

        # ---------------------------------------------------------------------------------------------------------------
        def getBuilderVersion
          {
              version:  VERSION,
              major:    MAJOR,
              minor:    MINOR,
              patch:    PATCH,
          }
        end

        # ---------------------------------------------------------------------------------------------------------------
        def setup()
          $stdout.write("ChefRepoManifestBuilder v#{CiCd::Builder::ChefRepoManifest::VERSION}\n")
          @default_options[:env_keys] << %w(
                                            REPO_PRODUCTS
                                           )
          @default_options[:env_keys] = @default_options[:env_keys].select{|key| key !~ /^CLASSES/}
          super
        end

      end
    end

  end
end
