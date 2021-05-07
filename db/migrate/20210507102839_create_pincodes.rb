class CreatePincodes < ActiveRecord::Migration[6.1]
  def change
    create_table :pincodes do |t|
      t.decimal :lat, null: false, default: 0
      t.decimal :lon, null: false, default: 0
      t.timestamps
    end
  end
end
