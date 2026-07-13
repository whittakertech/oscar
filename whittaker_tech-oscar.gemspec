# frozen_string_literal: true

require_relative 'lib/whittaker_tech/oscar/version'

Gem::Specification.new do |spec|
  spec.name        = 'whittaker_tech-oscar'
  spec.version     = WhittakerTech::Oscar::VERSION
  spec.authors     = ['Lee Whittaker']
  spec.email       = ['lee@whittakertech.com']
  spec.homepage    = 'https://github.com/whittakertech/oscar'
  spec.summary     = 'Configurable lifecycle-visibility state machine engine for Rails'
  spec.description = 'A Rails engine that owns lifecycle visibility for host models via a ' \
                     'taxonomy-driven, configurable state machine (WordPress-shaped: draft, ' \
                     'published, archived, trashed, purged). States are exclusive, transitions ' \
                     'are declared, and history persists via Poly::Stack.'
  spec.license     = 'MIT'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri']   = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.required_ruby_version = '>= 3.2'

  spec.add_dependency 'pg', '>= 1.1'
  spec.add_dependency 'poly', '~> 1.1'
  spec.add_dependency 'rails', '>= 7.1', '< 8.0'
end
