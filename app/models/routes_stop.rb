class RoutesStop < ApplicationRecord

    self.primary_keys = :route_id, :stop_id

    belongs_to :route
    belongs_to :stop
    acts_as_list scope: :route

end
