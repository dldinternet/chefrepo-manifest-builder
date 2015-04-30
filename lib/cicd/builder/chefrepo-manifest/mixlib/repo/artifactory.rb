require 'artifactory'
require 'tmpdir'
require "cicd/builder/manifest/mixlib/repo/artifactory"

module CiCd
  module Builder
    # noinspection RubySuperCallWithoutSuperclassInspection
    module ChefRepoManifest
      module Repo
        class Artifactory < CiCd::Builder::Manifest::Repo::Artifactory

          # # ---------------------------------------------------------------------------------------------------------------
          # def handleManifests()
          #   if @vars[:return_code] == 0
          #     # Preserve the manifest (maybeUploadArtifactoryObject will add everything we upload to the instance var)
          #     manifest = @manifest.dup
          #     # Create a manifest for each product and store it.
          #     createProductManifests(manifest)
          #     @manifest = manifest
          #   end
          #   @vars[:return_code]
          # end

        end
      end
    end
  end
end
