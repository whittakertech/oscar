# frozen_string_literal: true

require 'poly'

# Abstract base class for all Oscar ActiveRecord models.
#
# Sets the +oscar_+ table name prefix so every subclass automatically maps to
# the correct table (e.g. +WhittakerTech::Oscar::Status+ → +oscar_statuses+)
# without needing to repeat the prefix in each model.
class WhittakerTech::Oscar::ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  self.table_name_prefix = 'oscar_'
end
