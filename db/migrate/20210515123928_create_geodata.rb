class CreateGeodata < ActiveRecord::Migration[6.1]
  def change
    create_table :geodata do |t|
      t.integer :pincode
      t.string :place
      t.string :admin1
      t.string :admin2
      t.string :admin3
      t.decimal :lat
      t.decimal :lon
      t.integer :accuracy
      t.timestamps
    end
  end
end
