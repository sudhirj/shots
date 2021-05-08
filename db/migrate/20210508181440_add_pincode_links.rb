class AddPincodeLinks < ActiveRecord::Migration[6.1]
  def change
    change_table :pincodes do |t|
      t.string :map_url
      t.string :map_image
    end
  end
end
