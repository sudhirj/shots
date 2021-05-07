class AddMapLinks < ActiveRecord::Migration[6.1]
  def change
    change_table :centers do |t|
      t.string :map_url
      t.string :map_image
      t.decimal :lat
      t.decimal :lon
    end
  end
end
