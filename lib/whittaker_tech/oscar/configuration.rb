# frozen_string_literal: true

# Holds root-level configuration for the Oscar engine.
#
# @example Configuring root taxonomy defaults in an initializer
#   WhittakerTech::Oscar.configure do |config|
#     config.taxonomy = {
#       initial: :draft,
#       states: { draft: {}, published: {}, trashed: {}, purged: { destroyable: true, locked: true } },
#       transitions: { publish: { from: :draft, to: :published, past: :published }, ... }
#     }
#   end
#
# Host models declare their own taxonomy (merged over these root defaults)
# via the `oscar_taxonomy` class macro from WhittakerTech::Oscar::Stateful —
# see docs/design.md.
class WhittakerTech::Oscar::Configuration
  # @!attribute [rw] taxonomy
  #   Root-level taxonomy defaults, merged under every per-model
  #   `oscar_taxonomy` declaration.
  #   @return [Hash] (default: +{}+)
  attr_accessor :taxonomy

  def initialize
    @taxonomy = {}
  end
end
