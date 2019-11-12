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
    content = open('http://track.ua-gis.com/gtfs/lviv/static.zip')
    #content = open('/Users/mholyak/Downloads/static.zip')

    Zip::File.open_buffer(content) do |zip|
      data = {
        trips: {},
        stop_times: {},
        stops: {},
      }

      imported_stop_codes = []
      zip.each do |entry|
        content = entry.get_input_stream.read.force_encoding 'UTF-8'

        CSV.parse(content, headers: true, liberal_parsing: true) do |row|
          row = row.to_hash.symbolize_keys

          case entry.name
          when 'stops.txt'
            begin
              data[:stops][row[:stop_id]] = row
              imported_stop_codes << import_stop(row)
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

      # Clean stops, which are NOT in Microgiz db
      Stop.where.not(code: imported_stop_codes).destroy_all

      route_with_stops = {}
      data[:stop_times].each do |trip_id, stops|
        route_id = data[:trips][trip_id]
        route_with_stops[route_id] = [] unless route_with_stops.has_key? route_id
        route_with_stops[route_id] << stops
      end
      route_with_stops = route_with_stops.map {|k, v| 
        stops = v.map {|h| h.keys}

        counts = {}
        stops.each {|stops| counts[stops.to_s] = 0 }.each {|stops| counts[stops.to_s] += 1 }
        counts = counts.sort_by {|_key, value| value}.slice(-2..-1).to_h

        new_stops = stops.select{|stops| counts.has_key? stops.to_s }.uniq

        [k, new_stops]
      }.to_h

      routes_stops = route_with_stops.map {|k, v| 
        stops = v.flatten.uniq
        [k, stops]
      }.to_h
      import_route_stops routes_stops

      # let_stops = let_stops.map { |code|
      #   s = Stop.find_by code: code
      #   routes = s.routes.map {|r| 
      #     current_route_with_trips = route_with_stops[r.external_id.to_s]
      #     current_trip = current_route_with_trips.detect { |stops| stops.include?(s.external_id.to_s) or stops.last == s.external_id.to_s}
      #     back_trip = current_route_with_trips.detect { |stops| stops != current_trip}

      #     end_stop = data[:stops][back_trip.first]
      #     end_stop_name = end_stop[:stop_name]

      #     start_stop = data[:stops][current_trip.first]
      #     start_stop_name = start_stop[:stop_name]

      #     [
      #       '(висадка) 0083', 
      #       '(висадка)',
      #       '-висадка', 
      #       'висадка', 
      #       ' (зв)', 
      #       /\(\d+\-?\d*\)/
      #     ].each {|k,v| 
      #       end_stop_name.sub!(k,'')
      #       start_stop_name.sub!(k,'')
      #     }

      #     [
      #       r.name, 
      #       ' ',
      #       start_stop_name.squish,
      #       ' - ',
      #       end_stop_name.squish
      #     ].join('')
      #   }.reject(&:nil?).sort

      #   [s.name, s.code, routes].flatten
      # }
      
      # require 'csv'
      # CSV.open("/Users/mholyak/Downloads/myfile.csv", "w") do |csv|
      #   let_stops.each do |l|
      #     p l
      #     csv << l
      #   end
      # end

    end
  end

  desc "Map easyway ids"
  task easyway: :environment do
    easyway_map = [{:code=>2, :easyway_id=>2752}, {:code=>3, :easyway_id=>2751}, {:code=>4, :easyway_id=>222480}, {:code=>5, :easyway_id=>222505}, {:code=>6, :easyway_id=>222298}, {:code=>7, :easyway_id=>167246}, {:code=>8, :easyway_id=>4298}, {:code=>9, :easyway_id=>167324}, {:code=>10, :easyway_id=>3564}, {:code=>11, :easyway_id=>222156}, {:code=>12, :easyway_id=>222155}, {:code=>13, :easyway_id=>222235}, {:code=>14, :easyway_id=>222216}, {:code=>15, :easyway_id=>3747}, {:code=>16, :easyway_id=>3751}, {:code=>17, :easyway_id=>222123}, {:code=>18, :easyway_id=>3749}, {:code=>19, :easyway_id=>2076}, {:code=>20, :easyway_id=>222440}, {:code=>21, :easyway_id=>28515}, {:code=>22, :easyway_id=>62649}, {:code=>23, :easyway_id=>2749}, {:code=>24, :easyway_id=>1429}, {:code=>25, :easyway_id=>1432}, {:code=>27, :easyway_id=>2078}, {:code=>28, :easyway_id=>2758}, {:code=>29, :easyway_id=>176954}, {:code=>31, :easyway_id=>2073}, {:code=>32, :easyway_id=>2756}, {:code=>33, :easyway_id=>14300}, {:code=>34, :easyway_id=>2074}, {:code=>35, :easyway_id=>2071}, {:code=>36, :easyway_id=>2072}, {:code=>37, :easyway_id=>222409}, {:code=>38, :easyway_id=>167321}, {:code=>39, :easyway_id=>76733}, {:code=>40, :easyway_id=>3753}, {:code=>41, :easyway_id=>172132}, {:code=>42, :easyway_id=>2453}, {:code=>43, :easyway_id=>222162}, {:code=>44, :easyway_id=>9939}, {:code=>45, :easyway_id=>7888}, {:code=>46, :easyway_id=>8255}, {:code=>47, :easyway_id=>2054}, {:code=>48, :easyway_id=>14}, {:code=>49, :easyway_id=>193302}, {:code=>49, :easyway_id=>222292}, {:code=>50, :easyway_id=>2063}, {:code=>51, :easyway_id=>2062}, {:code=>52, :easyway_id=>2061}, {:code=>53, :easyway_id=>52419}, {:code=>54, :easyway_id=>1868}, {:code=>55, :easyway_id=>47794}, {:code=>56, :easyway_id=>47817}, {:code=>57, :easyway_id=>2754}, {:code=>58, :easyway_id=>2067}, {:code=>59, :easyway_id=>2753}, {:code=>60, :easyway_id=>222399}, {:code=>61, :easyway_id=>2065}, {:code=>62, :easyway_id=>3563}, {:code=>63, :easyway_id=>2066}, {:code=>64, :easyway_id=>222275}, {:code=>65, :easyway_id=>222154}, {:code=>66, :easyway_id=>2057}, {:code=>67, :easyway_id=>51636}, {:code=>68, :easyway_id=>167244}, {:code=>69, :easyway_id=>152906}, {:code=>70, :easyway_id=>222433}, {:code=>71, :easyway_id=>86499}, {:code=>73, :easyway_id=>4300}, {:code=>74, :easyway_id=>2632}, {:code=>75, :easyway_id=>576}, {:code=>76, :easyway_id=>579}, {:code=>77, :easyway_id=>4738}, {:code=>78, :easyway_id=>15}, {:code=>79, :easyway_id=>835}, {:code=>80, :easyway_id=>581}, {:code=>81, :easyway_id=>580}, {:code=>82, :easyway_id=>47048}, {:code=>83, :easyway_id=>171999}, {:code=>84, :easyway_id=>41645}, {:code=>85, :easyway_id=>50033}, {:code=>86, :easyway_id=>816}, {:code=>87, :easyway_id=>167277}, {:code=>89, :easyway_id=>167273}, {:code=>90, :easyway_id=>15714}, {:code=>91, :easyway_id=>167278}, {:code=>92, :easyway_id=>167274}, {:code=>93, :easyway_id=>167276}, {:code=>94, :easyway_id=>3750}, {:code=>95, :easyway_id=>167280}, {:code=>96, :easyway_id=>830}, {:code=>97, :easyway_id=>825}, {:code=>98, :easyway_id=>823}, {:code=>99, :easyway_id=>819}, {:code=>100, :easyway_id=>826}, {:code=>101, :easyway_id=>824}, {:code=>102, :easyway_id=>3746}, {:code=>103, :easyway_id=>3743}, {:code=>104, :easyway_id=>820}, {:code=>105, :easyway_id=>222138}, {:code=>106, :easyway_id=>3745}, {:code=>107, :easyway_id=>3744}, {:code=>108, :easyway_id=>222445}, {:code=>109, :easyway_id=>167279}, {:code=>110, :easyway_id=>222209}, {:code=>111, :easyway_id=>222150}, {:code=>113, :easyway_id=>222206}, {:code=>114, :easyway_id=>827}, {:code=>115, :easyway_id=>817}, {:code=>116, :easyway_id=>818}, {:code=>117, :easyway_id=>201533}, {:code=>118, :easyway_id=>167533}, {:code=>119, :easyway_id=>821}, {:code=>120, :easyway_id=>385}, {:code=>121, :easyway_id=>822}, {:code=>122, :easyway_id=>384}, {:code=>124, :easyway_id=>167237}, {:code=>125, :easyway_id=>6046}, {:code=>126, :easyway_id=>32211}, {:code=>127, :easyway_id=>6047}, {:code=>128, :easyway_id=>382}, {:code=>129, :easyway_id=>379}, {:code=>130, :easyway_id=>2617}, {:code=>131, :easyway_id=>377}, {:code=>132, :easyway_id=>76732}, {:code=>133, :easyway_id=>381}, {:code=>134, :easyway_id=>380}, {:code=>135, :easyway_id=>378}, {:code=>136, :easyway_id=>7}, {:code=>137, :easyway_id=>8}, {:code=>138, :easyway_id=>5}, {:code=>139, :easyway_id=>6323}, {:code=>140, :easyway_id=>15720}, {:code=>141, :easyway_id=>15719}, {:code=>142, :easyway_id=>6322}, {:code=>143, :easyway_id=>51635}, {:code=>144, :easyway_id=>51634}, {:code=>145, :easyway_id=>6321}, {:code=>146, :easyway_id=>982}, {:code=>147, :easyway_id=>984}, {:code=>148, :easyway_id=>981}, {:code=>149, :easyway_id=>983}, {:code=>150, :easyway_id=>222191}, {:code=>151, :easyway_id=>978}, {:code=>152, :easyway_id=>977}, {:code=>153, :easyway_id=>167286}, {:code=>154, :easyway_id=>979}, {:code=>155, :easyway_id=>167287}, {:code=>156, :easyway_id=>192251}, {:code=>157, :easyway_id=>157426}, {:code=>158, :easyway_id=>157428}, {:code=>159, :easyway_id=>157427}, {:code=>160, :easyway_id=>157425}, {:code=>162, :easyway_id=>51633}, {:code=>163, :easyway_id=>51632}, {:code=>164, :easyway_id=>15717}, {:code=>165, :easyway_id=>15718}, {:code=>166, :easyway_id=>389}, {:code=>167, :easyway_id=>387}, {:code=>168, :easyway_id=>386}, {:code=>169, :easyway_id=>388}, {:code=>170, :easyway_id=>35217}, {:code=>172, :easyway_id=>167305}, {:code=>173, :easyway_id=>167304}, {:code=>174, :easyway_id=>15571}, {:code=>175, :easyway_id=>1637}, {:code=>176, :easyway_id=>1638}, {:code=>177, :easyway_id=>1640}, {:code=>178, :easyway_id=>157423}, {:code=>179, :easyway_id=>1631}, {:code=>180, :easyway_id=>1630}, {:code=>181, :easyway_id=>1632}, {:code=>182, :easyway_id=>4735}, {:code=>183, :easyway_id=>4733}, {:code=>184, :easyway_id=>4742}, {:code=>185, :easyway_id=>201534}, {:code=>186, :easyway_id=>4743}, {:code=>187, :easyway_id=>2053}, {:code=>188, :easyway_id=>222137}, {:code=>189, :easyway_id=>222159}, {:code=>190, :easyway_id=>222262}, {:code=>191, :easyway_id=>189490}, {:code=>192, :easyway_id=>1635}, {:code=>193, :easyway_id=>167272}, {:code=>194, :easyway_id=>1636}, {:code=>195, :easyway_id=>1634}, {:code=>196, :easyway_id=>1633}, {:code=>197, :easyway_id=>222428}, {:code=>198, :easyway_id=>9086}, {:code=>199, :easyway_id=>9089}, {:code=>200, :easyway_id=>9090}, {:code=>201, :easyway_id=>9105}, {:code=>202, :easyway_id=>222454}, {:code=>203, :easyway_id=>25158}, {:code=>204, :easyway_id=>25157}, {:code=>205, :easyway_id=>10336}, {:code=>206, :easyway_id=>10334}, {:code=>208, :easyway_id=>174030}, {:code=>209, :easyway_id=>47055}, {:code=>210, :easyway_id=>222391}, {:code=>211, :easyway_id=>174031}, {:code=>212, :easyway_id=>10332}, {:code=>213, :easyway_id=>10335}, {:code=>214, :easyway_id=>7893}, {:code=>215, :easyway_id=>7891}, {:code=>216, :easyway_id=>7889}, {:code=>217, :easyway_id=>167326}, {:code=>219, :easyway_id=>1428}, {:code=>220, :easyway_id=>143873}, {:code=>221, :easyway_id=>143872}, {:code=>222, :easyway_id=>1431}, {:code=>223, :easyway_id=>1433}, {:code=>224, :easyway_id=>1434}, {:code=>225, :easyway_id=>13737}, {:code=>226, :easyway_id=>222449}, {:code=>227, :easyway_id=>13736}, {:code=>228, :easyway_id=>80799}, {:code=>229, :easyway_id=>80800}, {:code=>230, :easyway_id=>80797}, {:code=>231, :easyway_id=>53634}, {:code=>233, :easyway_id=>35221}, {:code=>234, :easyway_id=>35220}, {:code=>235, :easyway_id=>222264}, {:code=>236, :easyway_id=>53635}, {:code=>237, :easyway_id=>53636}, {:code=>238, :easyway_id=>222429}, {:code=>239, :easyway_id=>222430}, {:code=>240, :easyway_id=>222125}, {:code=>241, :easyway_id=>2455}, {:code=>242, :easyway_id=>2454}, {:code=>243, :easyway_id=>222493}, {:code=>245, :easyway_id=>167242}, {:code=>246, :easyway_id=>222495}, {:code=>247, :easyway_id=>222506}, {:code=>253, :easyway_id=>161610}, {:code=>254, :easyway_id=>4520}, {:code=>255, :easyway_id=>222517}, {:code=>256, :easyway_id=>207452}, {:code=>257, :easyway_id=>29064}, {:code=>258, :easyway_id=>16641}, {:code=>259, :easyway_id=>16643}, {:code=>261, :easyway_id=>16642}, {:code=>262, :easyway_id=>16644}, {:code=>263, :easyway_id=>12398}, {:code=>264, :easyway_id=>12399}, {:code=>265, :easyway_id=>12397}, {:code=>266, :easyway_id=>12396}, {:code=>267, :easyway_id=>7902}, {:code=>268, :easyway_id=>7904}, {:code=>269, :easyway_id=>7903}, {:code=>270, :easyway_id=>7906}, {:code=>272, :easyway_id=>174028}, {:code=>273, :easyway_id=>9094}, {:code=>274, :easyway_id=>9093}, {:code=>275, :easyway_id=>169431}, {:code=>277, :easyway_id=>35219}, {:code=>278, :easyway_id=>7908}, {:code=>279, :easyway_id=>7907}, {:code=>280, :easyway_id=>222141}, {:code=>281, :easyway_id=>7901}, {:code=>282, :easyway_id=>7896}, {:code=>283, :easyway_id=>7897}, {:code=>285, :easyway_id=>7909}, {:code=>287, :easyway_id=>7899}, {:code=>288, :easyway_id=>80798}, {:code=>289, :easyway_id=>9092}, {:code=>290, :easyway_id=>174403}, {:code=>291, :easyway_id=>583}, {:code=>292, :easyway_id=>582}, {:code=>293, :easyway_id=>2626}, {:code=>294, :easyway_id=>2627}, {:code=>295, :easyway_id=>88650}, {:code=>296, :easyway_id=>222404}, {:code=>297, :easyway_id=>222405}, {:code=>302, :easyway_id=>222403}, {:code=>303, :easyway_id=>222402}, {:code=>310, :easyway_id=>167353}, {:code=>311, :easyway_id=>41641}, {:code=>312, :easyway_id=>41642}, {:code=>313, :easyway_id=>222490}, {:code=>314, :easyway_id=>222197}, {:code=>315, :easyway_id=>167295}, {:code=>316, :easyway_id=>167294}, {:code=>320, :easyway_id=>172133}, {:code=>322, :easyway_id=>222401}, {:code=>326, :easyway_id=>222272}, {:code=>354, :easyway_id=>23696}, {:code=>355, :easyway_id=>7232}, {:code=>356, :easyway_id=>7231}, {:code=>358, :easyway_id=>167322}, {:code=>359, :easyway_id=>167323}, {:code=>362, :easyway_id=>7235}, {:code=>363, :easyway_id=>7892}, {:code=>364, :easyway_id=>7894}, {:code=>365, :easyway_id=>7890}, {:code=>366, :easyway_id=>21937}, {:code=>367, :easyway_id=>222273}, {:code=>368, :easyway_id=>73457}, {:code=>369, :easyway_id=>143874}, {:code=>370, :easyway_id=>1436}, {:code=>371, :easyway_id=>167328}, {:code=>372, :easyway_id=>1435}, {:code=>373, :easyway_id=>1437}, {:code=>374, :easyway_id=>167327}, {:code=>375, :easyway_id=>222461}, {:code=>376, :easyway_id=>7230}, {:code=>377, :easyway_id=>1439}, {:code=>378, :easyway_id=>167303}, {:code=>379, :easyway_id=>1440}, {:code=>380, :easyway_id=>7229}, {:code=>381, :easyway_id=>167301}, {:code=>382, :easyway_id=>1442}, {:code=>384, :easyway_id=>17956}, {:code=>385, :easyway_id=>1445}, {:code=>386, :easyway_id=>1443}, {:code=>387, :easyway_id=>1444}, {:code=>388, :easyway_id=>167300}, {:code=>389, :easyway_id=>1446}, {:code=>390, :easyway_id=>17440}, {:code=>391, :easyway_id=>167297}, {:code=>392, :easyway_id=>222266}, {:code=>393, :easyway_id=>48340}, {:code=>394, :easyway_id=>167302}, {:code=>395, :easyway_id=>167298}, {:code=>396, :easyway_id=>167296}, {:code=>397, :easyway_id=>167329}, {:code=>398, :easyway_id=>9107}, {:code=>399, :easyway_id=>172128}, {:code=>400, :easyway_id=>172129}, {:code=>401, :easyway_id=>167320}, {:code=>402, :easyway_id=>167319}, {:code=>403, :easyway_id=>167316}, {:code=>404, :easyway_id=>167317}, {:code=>406, :easyway_id=>29067}, {:code=>407, :easyway_id=>222142}, {:code=>408, :easyway_id=>167318}, {:code=>409, :easyway_id=>222195}, {:code=>410, :easyway_id=>167331}, {:code=>413, :easyway_id=>167334}, {:code=>414, :easyway_id=>20137}, {:code=>415, :easyway_id=>20136}, {:code=>416, :easyway_id=>222436}, {:code=>417, :easyway_id=>5714}, {:code=>419, :easyway_id=>7241}, {:code=>420, :easyway_id=>7239}, {:code=>421, :easyway_id=>7238}, {:code=>422, :easyway_id=>7236}, {:code=>423, :easyway_id=>7228}, {:code=>424, :easyway_id=>170691}, {:code=>425, :easyway_id=>2618}, {:code=>426, :easyway_id=>170690}, {:code=>428, :easyway_id=>574}, {:code=>429, :easyway_id=>572}, {:code=>430, :easyway_id=>364}, {:code=>431, :easyway_id=>167315}, {:code=>432, :easyway_id=>363}, {:code=>433, :easyway_id=>199381}, {:code=>434, :easyway_id=>222165}, {:code=>435, :easyway_id=>136637}, {:code=>436, :easyway_id=>367}, {:code=>437, :easyway_id=>7237}, {:code=>438, :easyway_id=>7234}, {:code=>439, :easyway_id=>7233}, {:code=>440, :easyway_id=>4916}, {:code=>441, :easyway_id=>167309}, {:code=>442, :easyway_id=>4917}, {:code=>443, :easyway_id=>167310}, {:code=>444, :easyway_id=>222168}, {:code=>445, :easyway_id=>4915}, {:code=>446, :easyway_id=>4918}, {:code=>448, :easyway_id=>167311}, {:code=>450, :easyway_id=>4304}, {:code=>451, :easyway_id=>4305}, {:code=>452, :easyway_id=>4306}, {:code=>453, :easyway_id=>222482}, {:code=>454, :easyway_id=>4310}, {:code=>455, :easyway_id=>4307}, {:code=>456, :easyway_id=>4309}, {:code=>457, :easyway_id=>4311}, {:code=>458, :easyway_id=>29065}, {:code=>459, :easyway_id=>222486}, {:code=>465, :easyway_id=>2445}, {:code=>466, :easyway_id=>2631}, {:code=>467, :easyway_id=>222153}, {:code=>469, :easyway_id=>2629}, {:code=>470, :easyway_id=>9938}, {:code=>471, :easyway_id=>222466}, {:code=>473, :easyway_id=>222265}, {:code=>474, :easyway_id=>12}, {:code=>475, :easyway_id=>167285}, {:code=>476, :easyway_id=>11}, {:code=>477, :easyway_id=>10}, {:code=>478, :easyway_id=>167308}, {:code=>479, :easyway_id=>167306}, {:code=>480, :easyway_id=>167307}, {:code=>481, :easyway_id=>372}, {:code=>482, :easyway_id=>374}, {:code=>483, :easyway_id=>571}, {:code=>484, :easyway_id=>376}, {:code=>485, :easyway_id=>375}, {:code=>486, :easyway_id=>373}, {:code=>487, :easyway_id=>2448}, {:code=>488, :easyway_id=>222196}, {:code=>489, :easyway_id=>2447}, {:code=>490, :easyway_id=>2446}, {:code=>491, :easyway_id=>17}, {:code=>492, :easyway_id=>18}, {:code=>493, :easyway_id=>19}, {:code=>494, :easyway_id=>222205}, {:code=>496, :easyway_id=>207453}, {:code=>497, :easyway_id=>829}, {:code=>498, :easyway_id=>222438}, {:code=>499, :easyway_id=>2444}, {:code=>500, :easyway_id=>2443}, {:code=>501, :easyway_id=>2442}, {:code=>502, :easyway_id=>2441}, {:code=>503, :easyway_id=>2440}, {:code=>504, :easyway_id=>2438}, {:code=>505, :easyway_id=>2077}, {:code=>506, :easyway_id=>222267}, {:code=>507, :easyway_id=>75779}, {:code=>508, :easyway_id=>369}, {:code=>509, :easyway_id=>368}, {:code=>510, :easyway_id=>167283}, {:code=>511, :easyway_id=>2080}, {:code=>512, :easyway_id=>169651}, {:code=>513, :easyway_id=>9935}, {:code=>515, :easyway_id=>9934}, {:code=>516, :easyway_id=>2623}, {:code=>517, :easyway_id=>2622}, {:code=>518, :easyway_id=>9931}, {:code=>519, :easyway_id=>2621}, {:code=>520, :easyway_id=>9928}, {:code=>521, :easyway_id=>9930}, {:code=>522, :easyway_id=>9929}, {:code=>524, :easyway_id=>222302}, {:code=>525, :easyway_id=>222303}, {:code=>526, :easyway_id=>9937}, {:code=>527, :easyway_id=>2079}, {:code=>528, :easyway_id=>2055}, {:code=>529, :easyway_id=>167281}, {:code=>531, :easyway_id=>169632}, {:code=>532, :easyway_id=>9}, {:code=>533, :easyway_id=>4}, {:code=>535, :easyway_id=>222169}, {:code=>536, :easyway_id=>222439}, {:code=>537, :easyway_id=>53359}, {:code=>538, :easyway_id=>167293}, {:code=>539, :easyway_id=>4912}, {:code=>540, :easyway_id=>167292}, {:code=>541, :easyway_id=>4911}, {:code=>543, :easyway_id=>167289}, {:code=>544, :easyway_id=>222289}, {:code=>545, :easyway_id=>4910}, {:code=>546, :easyway_id=>222290}, {:code=>547, :easyway_id=>222462}, {:code=>548, :easyway_id=>4909}, {:code=>549, :easyway_id=>167291}, {:code=>550, :easyway_id=>35222}, {:code=>551, :easyway_id=>222413}, {:code=>552, :easyway_id=>53360}, {:code=>553, :easyway_id=>4914}, {:code=>554, :easyway_id=>75003}, {:code=>555, :easyway_id=>2081}, {:code=>556, :easyway_id=>167284}, {:code=>557, :easyway_id=>2056}, {:code=>558, :easyway_id=>577}, {:code=>559, :easyway_id=>573}, {:code=>560, :easyway_id=>365}, {:code=>561, :easyway_id=>167314}, {:code=>562, :easyway_id=>362}, {:code=>563, :easyway_id=>360}, {:code=>564, :easyway_id=>222170}, {:code=>565, :easyway_id=>366}, {:code=>566, :easyway_id=>575}, {:code=>567, :easyway_id=>578}, {:code=>568, :easyway_id=>370}, {:code=>569, :easyway_id=>371}, {:code=>570, :easyway_id=>222131}, {:code=>571, :easyway_id=>13015}, {:code=>572, :easyway_id=>222132}, {:code=>573, :easyway_id=>13014}, {:code=>574, :easyway_id=>9099}, {:code=>575, :easyway_id=>9097}, {:code=>576, :easyway_id=>9098}, {:code=>577, :easyway_id=>9084}, {:code=>579, :easyway_id=>3120}, {:code=>580, :easyway_id=>167258}, {:code=>581, :easyway_id=>3121}, {:code=>582, :easyway_id=>169430}, {:code=>583, :easyway_id=>88648}, {:code=>584, :easyway_id=>222277}, {:code=>585, :easyway_id=>5710}, {:code=>586, :easyway_id=>174027}, {:code=>587, :easyway_id=>5708}, {:code=>588, :easyway_id=>5711}, {:code=>589, :easyway_id=>3549}, {:code=>590, :easyway_id=>5709}, {:code=>591, :easyway_id=>199370}, {:code=>592, :easyway_id=>222315}, {:code=>593, :easyway_id=>3546}, {:code=>594, :easyway_id=>199371}, {:code=>595, :easyway_id=>222269}, {:code=>596, :easyway_id=>4908}, {:code=>597, :easyway_id=>75004}, {:code=>598, :easyway_id=>3559}, {:code=>599, :easyway_id=>3557}, {:code=>600, :easyway_id=>3555}, {:code=>601, :easyway_id=>3550}, {:code=>602, :easyway_id=>167252}, {:code=>603, :easyway_id=>3556}, {:code=>604, :easyway_id=>3554}, {:code=>605, :easyway_id=>3551}, {:code=>607, :easyway_id=>167253}, {:code=>608, :easyway_id=>1872}, {:code=>609, :easyway_id=>1873}, {:code=>610, :easyway_id=>1875}, {:code=>611, :easyway_id=>1876}, {:code=>612, :easyway_id=>1879}, {:code=>613, :easyway_id=>1874}, {:code=>614, :easyway_id=>222496}, {:code=>615, :easyway_id=>78617}, {:code=>616, :easyway_id=>222200}, {:code=>617, :easyway_id=>1878}, {:code=>618, :easyway_id=>1877}, {:code=>619, :easyway_id=>9103}, {:code=>621, :easyway_id=>78618}, {:code=>622, :easyway_id=>167269}, {:code=>624, :easyway_id=>3545}, {:code=>627, :easyway_id=>54562}, {:code=>628, :easyway_id=>6848}, {:code=>629, :easyway_id=>6847}, {:code=>630, :easyway_id=>167259}, {:code=>631, :easyway_id=>1883}, {:code=>633, :easyway_id=>1885}, {:code=>634, :easyway_id=>1887}, {:code=>635, :easyway_id=>176955}, {:code=>636, :easyway_id=>1880}, {:code=>637, :easyway_id=>1881}, {:code=>638, :easyway_id=>1882}, {:code=>639, :easyway_id=>185557}, {:code=>640, :easyway_id=>2748}, {:code=>642, :easyway_id=>167248}, {:code=>646, :easyway_id=>167262}, {:code=>647, :easyway_id=>21942}, {:code=>648, :easyway_id=>167250}, {:code=>649, :easyway_id=>5453}, {:code=>650, :easyway_id=>168771}, {:code=>651, :easyway_id=>222236}, {:code=>652, :easyway_id=>222237}, {:code=>653, :easyway_id=>5454}, {:code=>654, :easyway_id=>168772}, {:code=>655, :easyway_id=>4720}, {:code=>656, :easyway_id=>4721}, {:code=>657, :easyway_id=>4722}, {:code=>658, :easyway_id=>9102}, {:code=>659, :easyway_id=>9100}, {:code=>660, :easyway_id=>185531}, {:code=>661, :easyway_id=>3124}, {:code=>662, :easyway_id=>23699}, {:code=>663, :easyway_id=>167266}, {:code=>664, :easyway_id=>194460}, {:code=>665, :easyway_id=>21346}, {:code=>666, :easyway_id=>167264}, {:code=>667, :easyway_id=>167263}, {:code=>668, :easyway_id=>3542}, {:code=>669, :easyway_id=>155570}, {:code=>670, :easyway_id=>167267}, {:code=>671, :easyway_id=>167257}, {:code=>672, :easyway_id=>167256}, {:code=>673, :easyway_id=>167255}, {:code=>674, :easyway_id=>3126}, {:code=>675, :easyway_id=>167254}, {:code=>676, :easyway_id=>3123}, {:code=>677, :easyway_id=>2439}, {:code=>678, :easyway_id=>222271}, {:code=>679, :easyway_id=>222400}, {:code=>680, :easyway_id=>222183}, {:code=>681, :easyway_id=>4737}, {:code=>682, :easyway_id=>4736}, {:code=>683, :easyway_id=>4734}, {:code=>685, :easyway_id=>4746}, {:code=>686, :easyway_id=>167271}, {:code=>687, :easyway_id=>9940}, {:code=>688, :easyway_id=>74289}, {:code=>689, :easyway_id=>167270}, {:code=>690, :easyway_id=>74287}, {:code=>691, :easyway_id=>74290}, {:code=>692, :easyway_id=>74288}, {:code=>693, :easyway_id=>4724}, {:code=>694, :easyway_id=>4728}, {:code=>695, :easyway_id=>4726}, {:code=>696, :easyway_id=>4744}, {:code=>697, :easyway_id=>4739}, {:code=>698, :easyway_id=>4723}, {:code=>699, :easyway_id=>4727}, {:code=>700, :easyway_id=>4725}, {:code=>701, :easyway_id=>4729}, {:code=>702, :easyway_id=>4730}, {:code=>703, :easyway_id=>28349}, {:code=>705, :easyway_id=>222192}, {:code=>706, :easyway_id=>222408}, {:code=>708, :easyway_id=>222397}, {:code=>711, :easyway_id=>222412}, {:code=>713, :easyway_id=>222392}, {:code=>728, :easyway_id=>222488}, {:code=>734, :easyway_id=>222423}, {:code=>735, :easyway_id=>222467}, {:code=>737, :easyway_id=>222398}, {:code=>738, :easyway_id=>167251}, {:code=>739, :easyway_id=>167249}, {:code=>743, :easyway_id=>167352}, {:code=>746, :easyway_id=>222414}, {:code=>749, :easyway_id=>222210}, {:code=>751, :easyway_id=>204331}, {:code=>752, :easyway_id=>204332}, {:code=>754, :easyway_id=>222484}, {:code=>757, :easyway_id=>167335}, {:code=>758, :easyway_id=>167336}, {:code=>761, :easyway_id=>6850}, {:code=>762, :easyway_id=>6849}, {:code=>767, :easyway_id=>222167}, {:code=>768, :easyway_id=>222166}, {:code=>771, :easyway_id=>222487}, {:code=>772, :easyway_id=>15569}, {:code=>779, :easyway_id=>222491}, {:code=>780, :easyway_id=>222492}, {:code=>781, :easyway_id=>222463}, {:code=>783, :easyway_id=>222471}, {:code=>785, :easyway_id=>222498}, {:code=>786, :easyway_id=>222485}, {:code=>789, :easyway_id=>222500}, {:code=>790, :easyway_id=>222468}, {:code=>791, :easyway_id=>222469}, {:code=>793, :easyway_id=>222479}, {:code=>794, :easyway_id=>222473}, {:code=>795, :easyway_id=>222472}, {:code=>797, :easyway_id=>222477}, {:code=>991, :easyway_id=>222508}, {:code=>1001, :easyway_id=>222174}, {:code=>1003, :easyway_id=>4522}, {:code=>1004, :easyway_id=>167238}, {:code=>1005, :easyway_id=>4524}, {:code=>1007, :easyway_id=>4526}, {:code=>1008, :easyway_id=>4523}, {:code=>1009, :easyway_id=>167239}, {:code=>1010, :easyway_id=>222176}, {:code=>1011, :easyway_id=>222175}, {:code=>1012, :easyway_id=>222530}, {:code=>1014, :easyway_id=>16648}, {:code=>1015, :easyway_id=>16647}, {:code=>1016, :easyway_id=>75006}, {:code=>1017, :easyway_id=>222528}, {:code=>1018, :easyway_id=>16645}, {:code=>1019, :easyway_id=>16646}, {:code=>1020, :easyway_id=>222283}, {:code=>1021, :easyway_id=>222284}, {:code=>1022, :easyway_id=>222281}, {:code=>1023, :easyway_id=>222282}, {:code=>1024, :easyway_id=>222393}, {:code=>1025, :easyway_id=>222390}, {:code=>1051, :easyway_id=>184241}, {:code=>1053, :easyway_id=>35224}, {:code=>1054, :easyway_id=>167341}, {:code=>1055, :easyway_id=>167342}, {:code=>1056, :easyway_id=>5439}, {:code=>1057, :easyway_id=>5441}, {:code=>1058, :easyway_id=>167340}, {:code=>1060, :easyway_id=>5450}, {:code=>1061, :easyway_id=>5449}, {:code=>1062, :easyway_id=>167339}, {:code=>1063, :easyway_id=>167345}, {:code=>1064, :easyway_id=>5448}, {:code=>1065, :easyway_id=>167338}, {:code=>1066, :easyway_id=>5451}, {:code=>1067, :easyway_id=>5452}, {:code=>1069, :easyway_id=>37044}, {:code=>1071, :easyway_id=>222163}, {:code=>1072, :easyway_id=>167344}, {:code=>1073, :easyway_id=>5444}, {:code=>1074, :easyway_id=>184236}, {:code=>1075, :easyway_id=>35226}, {:code=>1076, :easyway_id=>35225}, {:code=>1077, :easyway_id=>222140}, {:code=>1107, :easyway_id=>222218}, {:code=>1108, :easyway_id=>222217}, {:code=>1109, :easyway_id=>222224}, {:code=>1111, :easyway_id=>49360}, {:code=>1112, :easyway_id=>222219}, {:code=>1117, :easyway_id=>222234}, {:code=>1118, :easyway_id=>222222}, {:code=>1119, :easyway_id=>222225}, {:code=>1120, :easyway_id=>222226}, {:code=>1142, :easyway_id=>169213}, {:code=>1171, :easyway_id=>222422}, {:code=>1177, :easyway_id=>51564}, {:code=>1180, :easyway_id=>88655}, {:code=>1181, :easyway_id=>222359}, {:code=>1182, :easyway_id=>222360}, {:code=>1183, :easyway_id=>14205}, {:code=>1184, :easyway_id=>14204}, {:code=>1185, :easyway_id=>14207}, {:code=>1186, :easyway_id=>14206}, {:code=>1191, :easyway_id=>41646}, {:code=>1193, :easyway_id=>51561}, {:code=>1194, :easyway_id=>51562}]

    easyway_map.each do |pair|
      s = Stop.find_by(code: pair[:code])

      if s.nil?
        puts pair
        next
      end

      s.easyway_id = pair[:easyway_id]
      s.save
    end
  end

  desc "TODO"
  task realtime: :environment do
  end

  def import_stop(row)
    # {:stop_id=>"5129", :stop_code=>"153", :stop_name=>"\xD0\x90\xD0\xB5\xD1\x80\xD0\xBE\xD0\xBF\xD0\xBE\xD1\x80\xD1\x82", :stop_desc=>nil, :stop_lat=>"49.812833637475", :stop_lon=>"23.96170735359192", :zone_id=>"lviv_city", :stop_url=>nil, :location_type=>"0", :parent_station=>nil, :stop_timezone=>nil, :wheelchair_boarding=>"0"}
    [:stop_name, :stop_desc].each {|k| row[k] = row[k].to_s.force_encoding("UTF-8") }

    code = /(\(\d+\))/.match row[:stop_name]
    code = row[:stop_code] if code.nil? # Fallback to stop_code field
    raise "No code for #{row[:stop_desc]}" if code.nil?

    code = code[1] if code.kind_of? MatchData
    code = code.tr('()', '').trimzero

    begin
      Integer(code)
    rescue
      raise "Code #{row[:stop_code]} for #{row[:stop_desc]} is bad value"
    end

    stop_name = row[:stop_name]
    ["00#{code}", "0#{code}", code, '()', '" "', '(Т6)', '(0)', 'уточнити' , /^"{1}/ , /\s+$/, "\\"].each { |s| stop_name.sub! s, '' }
    stop_name.sub! '""', '"'
    stop_name.sub! /"{1}$/, '' if stop_name.count('"') > 0 && 0 != stop_name.count('"') % 2

    stop = Stop.find_or_initialize_by(code: code)

    stop.external_id = row[:stop_id]
    stop.code = code
    stop.name = stop_name
    stop.longitude = row[:stop_lon]
    stop.latitude = row[:stop_lat]
    stop.save

    #p [stop.code, stop.name]

    stop.code
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
