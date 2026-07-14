# frozen_string_literal: true

class CreateCrates < ActiveRecord::Migration[7.1]
  def change
    create_table :crates, id: :uuid do |t|
      t.string :name

      t.timestamps
    end

    add_reference :widgets, :crate, type: :uuid, foreign_key: false
  end
end
