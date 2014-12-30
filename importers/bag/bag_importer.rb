#encoding: utf-8

require 'json'
require 'sequel'
require 'citysdk'
include CitySDK

# ============================ Get endpoint and owner credentials ============================

config_path = nil
if ARGV.length > 0
  config_path = ARGV[0]
elsif ENV.has_key? 'CITYSDK_CONFIG' and ENV['CITYSDK_CONFIG'].length
  config_path = ENV['CITYSDK_CONFIG']
end

config = nil
begin
  config = JSON.parse(File.read(config_path), {symbolize_names: true})
rescue Exception => e
  $stderr.puts <<-ERROR
  Error loading CitySDK configuration file...
  Please set CITYSDK_CONFIG environment variable, or pass configuration file as a command line parameter
  Error message: #{e.message}
  ERROR
  exit!(-1)
end

# ==================================== Database tables =====================================

tables = [
  :ligplaats,
  :standplaats,
  :pand,
  :vbo,
  :pc4,
  :pc5,
  :pc6
]

# ==================================== Open DB connection ==================================

db_config = JSON.parse(File.read("#{File.dirname(__FILE__)}/config.json"), symbolize_names: true)
database = Sequel.connect "postgres://#{db_config[:user]}:#{db_config[:password]}@#{db_config[:host]}/#{db_config[:database]}", encoding: 'UTF-8'
database.extension :pg_hstore
database.extension :pg_streaming
database.stream_all_queries = true

# ==================================== Connect to API ======================================

api = API.new(config[:endpoint][:url])
if not api.authenticate(config[:owner][:name], config[:owner][:password])
  puts 'Error authenticating with API'
  exit!(-1)
end

# ================================ Read data, create layers ================================

layer_base = JSON.parse(File.read("#{File.dirname(__FILE__)}/layers/bag_base.json"), symbolize_names: true)

tables.each do |table|
  layer_name = "bag.#{table}"
  api.set_layer layer_name

  # Reads table-specific layer specification and merge with BAG base layer specification
  layer = layer_base.merge(JSON.parse(File.read("#{File.dirname(__FILE__)}/layers/bag_#{table}.json"), symbolize_names: true))
  layer[:name] = layer_name

  $stderr.puts ("Deleting layer '#{layer_name}' and objects, if layer already exists...")
  begin
    api.delete("/layers/#{layer_name}")
  rescue CitySDK::HostException => e
  end
  $stderr.puts ("Creating layer '#{layer_name}'")
  api.post("/layers", layer)

  dataset = database["citysdk__#{table}".to_sym]
  columns = dataset.columns - [:geom]
  dataset = dataset.select{columns}.select_append(Sequel.function(:ST_AsGeoJSON, :geom).as(:geojson))

  count = 0
  dataset.stream.all do |row|
    geometry = JSON.parse(row[:geojson])
    row.delete(:geojson)

    # All tables have ID column, except postcode tables: use first column instead
    id = if row.has_key? :id
      row[:id]
    else
      row[columns.first]
    end

    feature = {
      type: "Feature",
      properties: {
        id: id,
        data: row.delete_if {|k, v| v.nil? }
      },
      geometry: geometry
    }

    api.create_object feature
    count += 1

    if count % 500 == 0
      $stderr.puts "  Created #{count} objects on layer '#{layer_name}'"
    end
  end
end
