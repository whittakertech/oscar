# frozen_string_literal: true

class CreatePackages < ActiveRecord::Migration[7.1]
  def change
    create_table :packages, id: :uuid do |t|
      t.string :name, null: false

      t.timestamps
    end

    # Locked-until-purge, documented behavior (see docs/design.md): a plain
    # unique index is legal because the name frees only when the
    # terminal-state (purged) row is actually destroyed.
    add_index :packages, :name, unique: true
  end
end
