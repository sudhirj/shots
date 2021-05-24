class CreatePlaces < ActiveRecord::Migration[6.1]
  def change
    create_table :places do |t|
      t.integer :pincode
      t.string :area
      t.string :city
      t.string :area_slug
      t.string :city_slug
      t.timestamps
    end
    add_index :places, [:city_slug, :area_slug, :pincode], unique: true
    add_index :places, :pincode
  end
end
