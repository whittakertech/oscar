# frozen_string_literal: true

# Bigint-PK host model, deliberately NOT :uuid -- regression coverage for the
# resource_id::text cast in ScopeGenerator (a host app on an integer PK
# convention, e.g. Subscribify, must work identically to a uuid-PK host).
class CreateGizmos < ActiveRecord::Migration[7.1]
  def change
    create_table :gizmos do |t|
      t.string :name

      t.timestamps
    end
  end
end
