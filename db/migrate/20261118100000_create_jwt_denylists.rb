# frozen_string_literal: true

class CreateJwtDenylists < ActiveRecord::Migration[8.1]
  def change
    create_table :jwt_denylists do |t|
      t.string :jti, null: false, index: { unique: true }
      t.datetime :exp, null: false, index: true
      t.timestamps
    end
  end
end
