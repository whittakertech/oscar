# frozen_string_literal: true

class AddFlagsToWidgets < ActiveRecord::Migration[7.1]
  def change
    add_column :widgets, :flag_a, :boolean, null: false, default: false
    add_column :widgets, :flag_b, :boolean, null: false, default: false
  end
end
