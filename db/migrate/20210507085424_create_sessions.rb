class CreateSessions < ActiveRecord::Migration[6.1]
  def change
    create_table :sessions, id: :uuid do |t|
      t.date :date, null: false
      t.integer :availability, null: false, default: 0
      t.string :vaccine, null: false
      t.integer :min_age, null: false
      t.references :center, null: false, foreign_key: true
      t.timestamps
    end
  end
end
