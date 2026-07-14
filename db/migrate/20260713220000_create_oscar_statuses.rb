# frozen_string_literal: true

class CreateOscarStatuses < ActiveRecord::Migration[7.1]
  include Poly::Migration

  def change
    create_table :oscar_statuses, id: :uuid do |t|
      poly_resource t, :resource, id_type: :uuid
      poly_role t, :resource
      poly_stack t, id_type: :uuid

      t.string :state, null: false
      t.string :verb, null: false
      t.datetime :transitioned_at, null: false

      t.timestamps
    end

    poly_resource_index :oscar_statuses, :resource
    poly_prime_index :oscar_statuses, :resource
  end
end
