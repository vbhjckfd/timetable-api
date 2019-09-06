class Route < ApplicationRecord

    has_many :routes_stops, -> { order(position: :asc).limit(100500) }
    has_many :stops, through: :routes_stops

    TRAM = 1
    TROL = 2
    BUS = 3

    def stops_after stop
        all_stops = stops
        stop_index = all_stops.index stop
        raise "Route #{self.id} does not have stop #{stop.id} (code: #{stop.code})" if stop_index.nil?
        
        all_stops.slice stop_index..-1
    end

end
