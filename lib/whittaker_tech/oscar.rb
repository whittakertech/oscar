# frozen_string_literal: true

# Top-level namespace for all WhittakerTech engines.
module WhittakerTech; end

# Oscar owns lifecycle visibility; nothing else. It is a configurable,
# taxonomy-driven lifecycle-state machine (WordPress-shaped: draft, published,
# archived, trashed, purged) — see docs/design.md for the full identity,
# taxonomy hash schema, and boundary tripwires.
module WhittakerTech::Oscar # rubocop:disable Style/OneClassPerFile
  # Returns the +oscar_+ table name prefix used by all Oscar ActiveRecord models.
  # @return [String] the table prefix
  def self.table_name_prefix
    'oscar_'
  end
end

require 'whittaker_tech/oscar/version'
require 'whittaker_tech/oscar/engine'
