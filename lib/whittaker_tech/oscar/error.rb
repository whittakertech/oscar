# frozen_string_literal: true

module WhittakerTech # rubocop:disable Style/ClassAndModuleChildren
  module Oscar
    # Base class for all Oscar-raised errors.
    class Error < StandardError; end

    # Raised at taxonomy declaration time (config load or `oscar_taxonomy`
    # class macro) on any malformed taxonomy shape: unknown keys, states
    # unreachable via any declared transition, transitions referencing
    # undeclared states, or a transition missing its declared past-tense form.
    class InvalidTaxonomyError < Error; end

    # Raised when `oscar_transition!` is called with a transition name the
    # taxonomy doesn't declare, or whose `from` list doesn't include the
    # record's current state.
    class UndeclaredTransitionError < Error; end

    # Raised when `oscar_transition!` is attempted from a locked state via a
    # transition that doesn't explicitly declare `escapes_lock: true`, or when
    # `destroy` is attempted from a non-destroyable state.
    class LockedStateError < Error; end

    # Raised at `oscar_taxonomy` declaration time when a transition name or
    # declared past form is a protected verb (`destroy`/`delete`/`update`),
    # or when the method Oscar would generate already exists on the host
    # class (and would silently be overridden).
    class ProtectedVerbError < Error; end

    # Raised at `oscar_taxonomy` declaration time when the `base:` keyword
    # names a symbol not registered in `WhittakerTech::Oscar.configuration.bases`.
    class UnknownBaseError < Error; end
  end
end
