class CreateRoutes < ActiveRecord::Migration[6.0]
  def change
    create_table :routes do |t|
      t.string :name
      t.integer :type
      t.integer :external_id

      t.timestamps
    end
  end
end
