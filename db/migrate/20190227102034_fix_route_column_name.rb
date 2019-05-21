class FixRouteColumnName < ActiveRecord::Migration[6.0]
  def change
    rename_column 'routes', 'type', 'vehicle_type'
  end
end
