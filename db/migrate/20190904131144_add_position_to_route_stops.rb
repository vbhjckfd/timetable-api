class AddPositionToRouteStops < ActiveRecord::Migration[6.0]
  def change
    add_column :routes_stops, :position, :integer
  end
end
