# frozen_string_literal: true

# Cascade events: every `oscar_transition!` fires ONE generic
# ActiveSupport::Notifications event, regardless of which transition ran —
# there is no special-cased "restore event" distinct from this. A
# transition named `restore` (or anything else) fires the exact same event
# shape; whatever a subscriber does with `verb: :restore` is entirely up to
# that subscriber. Oscar itself never inspects or reacts to the verb name —
# "restore is mechanical-only" holds by construction, not by a runtime
# special case.
#
# Payload is deliberately data-minimal (GID + state symbols + verb, no
# domain data) — see docs/design.md's Cascade section. Sibling-engine
# concerns resolve the GID to the live record themselves
# (`GlobalID::Locator.locate`) rather than receiving it directly, and should
# query unscoped once resolved (the default-scope trap — moot given Oscar
# never installs one, but still a live risk for a *host* app's own scopes).
#
# Registered subscribers are independent: no hook reads another's output, no
# hook can halt the set for reasons other than raising, and — because
# `instrument_transition` is always called from inside the same `with_lock`
# transaction that appended the status card — a raise in ANY subscriber
# rolls back that card's creation along with every other subscriber's DB
# writes from this same transition. This is NOT literal threads (a
# `Thread.new` subscriber would get its own DB connection and could never
# join that transaction).
module WhittakerTech::Oscar
  TRANSITION_EVENT = 'oscar.transition'

  # @param record [ActiveRecord::Base] the resource that just transitioned
  # @param from [Symbol] the state transitioned out of
  # @param to [Symbol] the state transitioned into
  # @param verb [Symbol, String] the transition name that produced this change
  def self.instrument_transition(record, from:, to:, verb:)
    ActiveSupport::Notifications.instrument(
      TRANSITION_EVENT,
      resource_gid: record.to_global_id.to_s,
      from: from.to_sym,
      to: to.to_sym,
      verb: verb.to_sym
    )
  end

  # Registers a subscriber for every Oscar transition, across every
  # Oscar-managed model. Returns the subscriber object
  # (`ActiveSupport::Notifications.unsubscribe(subscriber)` to remove it).
  #
  # @yieldparam payload [Hash] `{resource_gid:, from:, to:, verb:}`
  def self.on_transition(&)
    ActiveSupport::Notifications.subscribe(TRANSITION_EVENT) do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      yield(event.payload)
    end
  end
end
