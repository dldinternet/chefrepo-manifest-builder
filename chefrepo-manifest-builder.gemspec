# -*- encoding: utf-8 -*-

require File.expand_path('../lib/cicd/builder/chefrepo-manifest/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = 'chefrepo-manifest-builder'
  gem.version       = CiCd::Builder::ChefRepoManifest::VERSION
  gem.summary       = %q{ChefRepo builder for a software manifest}
  gem.description   = %q{ChefRepo builder of the software manifest for Continuous Integration/Continuous Delivery artifact promotion style deployments}
  gem.license       = "Apachev2"
  gem.authors       = ["Christo De Lange"]
  gem.email         = "rubygems@dldinternet.com"
  gem.homepage      = "https://rubygems.org/gems/manifest-builder"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_dependency 'manifest-builder', '>= 0.7.0', '< 1.1'
  gem.add_dependency 'json', '>= 1.8.1', '< 1.9'
  gem.add_dependency 's3etag', '>= 0.0.1', '< 0.1.0'
  gem.add_dependency 'archive-tar-minitar', '= 0.5.2'

  gem.add_development_dependency 'bundler', '>= 1.7', '< 2.0'
  gem.add_development_dependency 'rake', '>= 10.3', '< 11'
  gem.add_development_dependency 'rubygems-tasks', '>= 0.2', '< 1.1'
  gem.add_development_dependency 'cucumber', '>= 0.10.7', '< 0.11'
  gem.add_development_dependency 'rspec', '>= 2.99', '< 3.0'
end
