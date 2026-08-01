# frozen_string_literal: true

# Top-level namespace for all WhittakerTech engines.
module WhittakerTech; end

# Oscar owns lifecycle visibility; nothing else. It is a configurable,
# taxonomy-driven lifecycle-state machine (blog-post-shaped: draft, published,
# archived, trashed, purged) — see docs/design.md for the full identity,
# taxonomy hash schema, and boundary tripwires.
module WhittakerTech::Oscar # rubocop:disable Style/OneClassPerFile
  # Returns the +oscar_+ table name prefix used by all Oscar ActiveRecord models.
  # @return [String] the table prefix
  def self.table_name_prefix
    'oscar_'
  end

  # Returns the global {Configuration} instance, initialising it on first call.
  # @return [Configuration]
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Yields the global {Configuration} instance for block-style setup, then
  # eagerly validates every entry in `config.bases` as a complete
  # {Taxonomy} — an invalid named base raises InvalidTaxonomyError here, at
  # configure time, rather than later at first `oscar_taxonomy` use.
  # @yieldparam config [Configuration] the mutable configuration object
  # @return [void]
  def self.configure
    yield(configuration)
    configuration.bases.each_value { |taxonomy_hash| Taxonomy.new(taxonomy_hash) }
  end

  # Resets the global configuration to its defaults. Intended for use in test
  # +after+ blocks when configuration has been mutated.
  # @return [Configuration] the new default configuration
  def self.reset_configuration!
    @configuration = Configuration.new
  end
end

require 'whittaker_tech/oscar/version'
require 'whittaker_tech/oscar/error'
require 'whittaker_tech/oscar/taxonomy'
require 'whittaker_tech/oscar/configuration'
require 'whittaker_tech/oscar/verb_generator'
require 'whittaker_tech/oscar/scope_generator'
require 'whittaker_tech/oscar/events'
require 'whittaker_tech/oscar/engine'
