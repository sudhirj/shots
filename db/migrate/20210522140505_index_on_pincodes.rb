class IndexOnPincodes < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!
  def change
    add_index :geodata, :pincode, algorithm: :concurrently
  end
end
