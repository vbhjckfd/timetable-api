class CreateStops < ActiveRecord::Migration[6.0]
  def change
    create_table :stops do |t|
      t.integer :code
      t.string :name
      t.float :longitude
      t.float :latitude
      t.integer :external_id
      t.integer :easyway_id

      t.timestamps
    end
    add_index :stops, :code, unique: true
  end
end
