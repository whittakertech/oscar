# frozen_string_literal: true

class CreateGadgets < ActiveRecord::Migration[7.1]
  def change
    create_table :gadgets, id: :uuid do |t|
      t.string :name

      t.timestamps
    end
  end
end
