# frozen_string_literal: true

# Parent fixture for T2's `dependent: :destroy` spec: proves a parent's
# dependent: :destroy fails against a live (non-destroyable-state) Widget and
# succeeds against a purge-eligible one.
class Crate < ApplicationRecord
  has_many :widgets, dependent: :destroy
end
