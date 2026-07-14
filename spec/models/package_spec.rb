# frozen_string_literal: true

require 'rails_helper'

# T6: Hello Dancer scenario — the canonical Package-retirement case study.
# Retiring stops new orders but persists history; the name stays
# locked-until-purge (documented behavior, no partial-index machinery).
RSpec.describe Package do
  it 'rejects a new-order-style transition once retired' do
    package = described_class.create!(name: 'Gold Plan')
    package.publish!
    package.retire!

    expect(package.retired?).to be(true)
    expect { package.publish! }
      .to raise_error(WhittakerTech::Oscar::UndeclaredTransitionError, /cannot publish from :retired/)
  end

  it 'keeps historical associations readable after retirement' do
    package = described_class.create!(name: 'Silver Plan')
    package.publish!
    order = Order.create!(package: package)

    package.retire!

    expect(Order.exists?(order.id)).to be(true)
    expect(package.orders.reload).to contain_exactly(order)
  end

  it 'blocks name reuse until the retired package is purged (locked-until-purge)' do
    original = described_class.create!(name: 'Bronze Plan')
    original.publish!
    original.retire!

    expect { described_class.create!(name: 'Bronze Plan') }
      .to raise_error(ActiveRecord::RecordNotUnique)

    original.purge!
    original.destroy!

    expect { described_class.create!(name: 'Bronze Plan') }.not_to raise_error
    expect(WhittakerTech::Oscar::Status.where(resource_type: 'Package', resource_id: original.id)).to be_empty
  end
end
