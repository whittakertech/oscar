# frozen_string_literal: true

class CreateWidgets < ActiveRecord::Migration[7.1]
  def change
    create_table :widgets, id: :uuid do |t|
      t.string :name

      t.timestamps
    end
  end
end
