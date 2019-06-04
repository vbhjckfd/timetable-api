require 'json'

class StopController < ApplicationController

  def show
    stop_id = params[:id]
    stop = Stop.where(code: stop_id).first

    return render(status: :bad_request, text: "No stop with code #{stop_id}") unless stop

    timetable = stop.get_timetable
    response = stop.as_json.symbolize_keys.slice(:name, :longitude, :latitude, :code).merge timetable: timetable || []

    response[:routes] = stop.routes.map { |r|
      {
        name: r.name,
        type: r.vehicle_type,
      }
    }

    render json: response
  end

  def closest
    coords = params.require [:longitude, :latitude]
    accuracy = 300.to_f / 1000 * 2

    point = coords.map {|c| c.to_f.round(3) }

    stops = Rails.cache.fetch("#{point.to_s}/closest_stops", expires_in: 24.hours) do
      Stop.in_lviv
        .within(accuracy, origin: point)
        .by_distance(origin: point)
        .map do |stop| 
          {
            code: stop.code, 
            name: stop.name, 
            longitude: stop.longitude, 
            latitude: stop.latitude
          } 
        end
    end

    render json: stops
  end

end
