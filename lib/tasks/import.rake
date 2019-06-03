require 'protobuf'
require 'google/transit/gtfs-realtime.pb'
require 'net/http'
require 'uri'
require 'csv'
require 'open-uri'
require 'zip'

namespace :import do
  
  desc "Import GTFS Static (stops, routes)"
  task static: :environment do
    # content = open('http://track.ua-gis.com/gtfs/lviv/static.zip')
    content = open('/Users/mholyak/Downloads/static.zip')

    Zip::File.open_buffer(content) do |zip|
      data = {
        trips: {},
        stop_times: {},
      }

      zip.each do |entry|
        content = entry.get_input_stream.read

        CSV.parse(content, headers: true, liberal_parsing: true) do |row|
          row = row.to_hash.symbolize_keys

          case entry.name
          when 'stops.txt'
            begin
              import_stop row
            rescue ArgumentError
            rescue Exception => e
             p e.message
             p row
            end
          when 'routes.txt'
            import_route row
          when 'trips.txt'
            data[:trips][row[:trip_id]] = row[:route_id]
          when 'stop_times.txt'
            data[:stop_times][row[:trip_id]] = {} unless data[:stop_times].has_key? row[:trip_id]
            data[:stop_times][row[:trip_id]][row[:stop_id]] = true
          end
        end
      end

      routes_stops = {}
      data[:stop_times].each do |trip_id, stops|
        route_id = data[:trips][trip_id]
        routes_stops[route_id] = {} unless routes_stops.has_key? route_id

        routes_stops[route_id].merge! stops
      end
      routes_stops.each {|k, v| routes_stops[k] = v.keys }

      data = nil # Save as much memory as we can

      import_route_stops routes_stops
    end
  end

  desc "TODO"
  task realtime: :environment do
  end

  def import_stop(row)
    # {:stop_id=>"5129", :stop_code=>"153", :stop_name=>"\xD0\x90\xD0\xB5\xD1\x80\xD0\xBE\xD0\xBF\xD0\xBE\xD1\x80\xD1\x82", :stop_desc=>nil, :stop_lat=>"49.812833637475", :stop_lon=>"23.96170735359192", :zone_id=>"lviv_city", :stop_url=>nil, :location_type=>"0", :parent_station=>nil, :stop_timezone=>nil, :wheelchair_boarding=>"0"}
    [:stop_name, :stop_desc].each {|k| row[k] = row[k].to_s.force_encoding("UTF-8") }

    code = /(\(\d+\))/.match row[:stop_name]
    raise "No code for #{row[:stop_desc]}" if code.nil?
    code = code[1][1..-2]

    begin
      Integer(code)
    rescue
      raise "Code #{row[:stop_code]} for #{row[:stop_desc]} is bad value"
    end

    stop_name = row[:stop_name]
    ["00#{code}", "0#{code}", code, '()', '" "', '(Т6)', '(0)', 'уточнити' , /^"{1}/ , /\s+$/, "\\"].each { |s| stop_name.sub! s, '' }
    stop_name.sub! '""', '"'
    stop_name.sub! /"{1}$/, '' if stop_name.count('"') > 0 && 0 != stop_name.count('"') % 2

    stop = Stop.find_or_initialize_by(external_id: row[:stop_id])

    stop.external_id = row[:stop_id]
    stop.code = code
    stop.name = stop_name
    stop.longitude = row[:stop_lon]
    stop.latitude = row[:stop_lat]
    stop.save

    #p [stop.code, stop.name]
  end

  def import_route(row)
    # {:route_id=>"1002", :agency_id=>"52", :route_short_name=>"\xD0\x9005", :route_long_name=>"\xD0\x9C\xD0\xB0\xD1\x80\xD1\x88\xD1\x80\xD1\x83\xD1\x82 \xE2\x84\x96\xD0\x9005 (\xD0\xBC. \xD0\x92\xD0\xB8\xD0\xBD\xD0\xBD\xD0\xB8\xD0\xBA\xD0\xB8 - \xD0\xBF\xD0\xBB. \xD0\xA0\xD1\x96\xD0\xB7\xD0\xBD\xD1\x96)-\xD1\x80\xD0\xB5\xD0\xBC", :route_type=>"3", :route_desc=>nil, :route_url=>nil, :route_color=>nil, :route_text_color=>nil}

    route = Route.find_or_initialize_by(external_id: row[:route_id])
    [:route_short_name, :route_long_name].each {|k| row[k] = row[k].force_encoding("UTF-8") }

    route.name = row[:route_short_name].sub '-А', ''
    #route.name = "#{row[:route_short_name]}: #{row[:route_long_name]}"

    route.vehicle_type = case row[:route_type]
      when '0'
        Route::TRAM
      when '3'
        route.name.start_with?('Тр') ? Route::TROL : Route::BUS
      else
        Route::BUS
    end

    route.save
    #p [route.name, row[:route_short_name], row[:route_long_name]]
  end

  def import_route_stops(stops_per_route)
    stops_per_route.each do |route_id, stops|
      route = Route.find_by(external_id: route_id)
      route.stops.clear
      route.stops = []

      stops.each do |stop_id|
        stop = Stop.find_by(external_id: stop_id)
        route.stops << stop if stop
      end

      route.save

      #p [route.name, route.stops.count]
    end
  end

end
