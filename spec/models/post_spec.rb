# frozen_string_literal: true

require 'rails_helper'

# T6: WordPress-taxonomy demo proof — the exact canonical shape documented in
# docs/design.md, exercised end-to-end through a real destroy.
RSpec.describe Post do
  it 'flows draft -> published -> trashed -> (locked) purged -> real destroy' do
    post = described_class.create!(title: 'Hello World')
    expect(post.oscar_state).to eq(:draft)

    post.publish!
    expect(post.published?).to be(true)

    post.trash!
    expect(post.trashed?).to be(true)

    post.purge!
    expect(post.purged?).to be(true)
    expect(described_class.oscar_taxonomy_config.locked?(:purged)).to be(true)

    expect { post.destroy! }.not_to raise_error
    expect(described_class.exists?(post.id)).to be(false)
    expect(WhittakerTech::Oscar::Status.where(resource_type: 'Post', resource_id: post.id)).to be_empty
  end

  it 'rejects destroy before reaching the purged (destroyable) state' do
    post = described_class.create!(title: 'Still draft')

    expect { post.destroy! }.to raise_error(WhittakerTech::Oscar::LockedStateError)
    expect(described_class.exists?(post.id)).to be(true)
  end

  it 'exposes the taxonomy states as admin tab-bar scopes' do
    draft = described_class.create!(title: 'a')
    published = described_class.create!(title: 'b')
    published.publish!

    expect(described_class.draft).to contain_exactly(draft)
    expect(described_class.published).to contain_exactly(published)
    expect(described_class.all_states).to contain_exactly(draft, published)
  end
end
