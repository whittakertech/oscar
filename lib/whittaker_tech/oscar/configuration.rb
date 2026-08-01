# frozen_string_literal: true

# Holds root-level configuration for the Oscar engine.
#
# @example Registering named taxonomy bases in an initializer
#   WhittakerTech::Oscar.configure do |config|
#     config.bases = {
#       blog_post_visibility: {
#         initial: :draft,
#         states: { draft: {}, published: {}, trashed: {}, purged: { destroyable: true, locked: true } },
#         transitions: { publish: { from: :draft, to: :published, past: :published }, ... }
#       }
#     }
#   end
#
# Host models select which (if any) named base to inherit from via the
# `base:` keyword on the `oscar_taxonomy` class macro from
# WhittakerTech::Oscar::Stateful — see docs/design.md. No base is
# pre-registered by the gem itself; a host app must register
# `blog_post_visibility` (or any other name) in its own initializer to use
# it.
class WhittakerTech::Oscar::Configuration
  # @!attribute [rw] bases
  #   Named taxonomy bases available for host models to inherit from via
  #   `oscar_taxonomy base: <name>`. Each entry is eagerly validated as a
  #   complete WhittakerTech::Oscar::Taxonomy when
  #   WhittakerTech::Oscar.configure's block finishes — an invalid entry
  #   raises WhittakerTech::Oscar::InvalidTaxonomyError immediately, not at
  #   first use.
  #   @return [Hash{Symbol => Hash}] (default: +{}+)
  attr_accessor :bases

  def initialize
    @bases = {}
  end
end
