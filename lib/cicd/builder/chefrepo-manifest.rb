require 'cicd/builder/manifest'

module CiCd
  module Builder
    _lib=File.dirname(__FILE__)
    $:.unshift(_lib) unless $:.include?(_lib)

    require 'cicd/builder/chefrepo-manifest/version'

    module ChefRepoManifest
      class Runner < Manifest::Runner

        # ---------------------------------------------------------------------------------------------------------------
        def initialize()
          super
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
          super
        end

      end
    end

  end
end
