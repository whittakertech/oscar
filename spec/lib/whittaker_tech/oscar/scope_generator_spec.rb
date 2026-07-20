# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Oscar::ScopeGenerator do
  describe 'generated state scopes' do
    it 'returns only records currently in that state' do
      draft = Widget.create!(name: 'a')
      published = Widget.create!(name: 'b')
      published.publish!

      expect(Widget.draft).to contain_exactly(draft)
      expect(Widget.published).to contain_exactly(published)
    end

    it 'composes with a host-defined scope' do
      published = Widget.create!(name: 'findme')
      published.publish!
      Widget.create!(name: 'findme') # draft, should not match

      expect(Widget.published.named('findme')).to contain_exactly(published)
    end

    it 'provides an all_states escape hatch that ignores state entirely' do
      draft = Widget.create!(name: 'a')
      published = Widget.create!(name: 'b')
      published.publish!

      expect(Widget.all_states).to contain_exactly(draft, published)
    end
  end

  describe 'no default_scope regression guard' do
    it 'never installs a default_scope on the host class' do
      expect(Widget.default_scopes).to be_empty
      expect(Gadget.default_scopes).to be_empty
    end
  end

  describe 'cross-model leak guard' do
    it "never returns another Oscar-managed model's rows from a same-named state scope" do
      widget = Widget.create!(name: 'w')
      widget.publish!

      gadget = Gadget.create!(name: 'g')
      gadget.publish!

      expect(Widget.published).to contain_exactly(widget)
      expect(Gadget.published).to contain_exactly(gadget)
    end
  end

  describe 'non-uuid host primary keys' do
    it 'works against a bigint-PK host exactly like a uuid-PK host' do
      draft = Gizmo.create!(name: 'a')
      published = Gizmo.create!(name: 'b')
      published.publish!

      expect(Gizmo.draft).to contain_exactly(draft)
      expect(Gizmo.published).to contain_exactly(published)
    end
  end
end
