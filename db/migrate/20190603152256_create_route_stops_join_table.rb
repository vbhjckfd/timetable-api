class CreateRouteStopsJoinTable < ActiveRecord::Migration[6.0]
  def change
    create_table :route_stops, id: false do |t|
      t.belongs_to :route, index: true
      t.belongs_to :stop, index: true
      t.integer :position
    end

  end
end
