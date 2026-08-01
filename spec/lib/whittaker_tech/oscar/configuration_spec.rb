# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Oscar::Configuration do
  let(:blog_post_visibility) do
    {
      initial: :draft,
      states: { draft: {}, published: {}, purged: { destroyable: true, locked: true } },
      transitions: {
        publish: { from: :draft, to: :published, past: :published },
        purge: { from: :published, to: :purged, past: :purged }
      }
    }
  end

  after { WhittakerTech::Oscar.reset_configuration! }

  it 'defaults bases to an empty hash' do
    expect(described_class.new.bases).to eq({})
  end

  it 'does not respond to the removed taxonomy= API' do
    expect(described_class.new).not_to respond_to(:taxonomy=)
    expect(described_class.new).not_to respond_to(:taxonomy)
  end

  it 'registers a valid named base via WhittakerTech::Oscar.configure' do
    WhittakerTech::Oscar.configure { |config| config.bases = { blog_post_visibility: blog_post_visibility } }

    expect(WhittakerTech::Oscar.configuration.bases[:blog_post_visibility]).to eq(blog_post_visibility)
  end

  it 'eagerly validates each named base at configure time' do
    invalid_base = blog_post_visibility.except(:initial)

    expect do
      WhittakerTech::Oscar.configure { |config| config.bases = { broken: invalid_base } }
    end.to raise_error(WhittakerTech::Oscar::InvalidTaxonomyError, /no :initial state/)
  end

  it 'defines UnknownBaseError in the same error family, not yet wired to any call site' do
    expect(WhittakerTech::Oscar::UnknownBaseError.ancestors).to include(WhittakerTech::Oscar::Error)
  end
end
