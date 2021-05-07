class CreateCenters < ActiveRecord::Migration[6.1]
  def change
    create_table :centers do |t|
      t.string :name, null: false
      t.integer :pincode, null: false, index: true
      t.text :address
      t.text :block
      t.time :open
      t.time :close
      t.string :fee_type
      t.references :district, null: false, index: true, foreign_key: true
      t.timestamps
    end
  end
end
