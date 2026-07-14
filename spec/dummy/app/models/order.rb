# frozen_string_literal: true

# Plain (non-Oscar) associated record, standing in for whatever historical
# data a real order-placement flow would attach to a Package. Proves
# retiring/purging a Package's lifecycle doesn't touch unrelated history.
class Order < ApplicationRecord
  belongs_to :package
end
