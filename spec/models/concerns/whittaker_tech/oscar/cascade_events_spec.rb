# frozen_string_literal: true

require 'rails_helper'

# This is an integration spec for the cascade-events behavior spanning
# WhittakerTech::Oscar::Events and Stateful#oscar_transition!, not a
# single-class unit spec, hence the filename doesn't mirror `described_class`.
# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe WhittakerTech::Oscar do
  let(:widget) { Widget.create!(name: 'w') }
  let(:subscribers) { [] }

  after { subscribers.each { |s| ActiveSupport::Notifications.unsubscribe(s) } }

  def subscribe_for(record, &)
    subscriber = ActiveSupport::Notifications.subscribe(WhittakerTech::Oscar::TRANSITION_EVENT) do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      next unless event.payload[:resource_gid] == record.to_global_id.to_s

      yield(event.payload)
    end
    subscribers << subscriber
    subscriber
  end

  it 'fires one event per transition with resource gid, from, to, verb — no domain data' do
    payloads = []
    subscribe_for(widget) { |payload| payloads << payload }

    widget.publish!

    expect(payloads.size).to eq(1)
    expect(payloads.first).to eq(
      resource_gid: widget.to_global_id.to_s, from: :draft, to: :published, verb: :publish
    )
  end

  it 'runs independent subscribers commutatively regardless of subscribe order' do
    subscribe_for(widget) { widget.update!(flag_a: true) }
    subscribe_for(widget) { widget.update!(flag_b: true) }
    widget.publish!
    widget.reload

    other = Widget.create!(name: 'w2')
    subscribe_for(other) { other.update!(flag_b: true) }
    subscribe_for(other) { other.update!(flag_a: true) }
    other.publish!
    other.reload

    expect([widget.flag_a, widget.flag_b]).to eq([true, true])
    expect([other.flag_a, other.flag_b]).to eq([true, true])
  end

  it "rolls back the whole transition, including other subscribers' writes, when one subscriber raises" do
    subscribe_for(widget) { widget.update!(flag_a: true) }
    subscribe_for(widget) { raise 'boom' }

    expect { widget.publish! }.to raise_error('boom')

    widget.reload
    expect(widget.flag_a).to be(false)
    expect(widget.oscar_state).to eq(:draft)
    expect(widget.oscar_statuses.count).to eq(1) # only the initial-state stamp card survives
  end

  it 'fires the same generic event for a restore-shaped transition with no implied subscriber obligation' do
    widget.oscar_transition!(:trash)
    verbs_seen = []
    subscribe_for(widget) { |payload| verbs_seen << payload[:verb] }

    expect { widget.oscar_transition!(:restore) }.not_to raise_error

    expect(verbs_seen).to eq([:restore])
    expect(widget.oscar_state).to eq(:draft)
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
