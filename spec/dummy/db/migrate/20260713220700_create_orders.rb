# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders, id: :uuid do |t|
      t.references :package, type: :uuid, null: false, foreign_key: false

      t.timestamps
    end
  end
end
