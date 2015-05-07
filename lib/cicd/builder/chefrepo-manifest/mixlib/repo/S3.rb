require "cicd/builder/mixlib/repo/S3"

module CiCd
  module Builder
    # noinspection RubySuperCallWithoutSuperclassInspection
    module ChefRepoManifest
      module Repo
        class S3 < CiCd::Builder::Repo::S3

          # ---------------------------------------------------------------------------------------------------------------
          def uploadToRepo(artifacts)
            @logger.info CLASS+'::'+__method__.to_s
            raise "This builder is not meant to upload to S3"
          end

        end
      end
    end
  end
end
