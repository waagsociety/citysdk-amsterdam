require 'sequel'
require 'citysdk'
include CitySDK

# ============================ Get endpoint and owner credentials ==============================

config_path = nil
if ARGV.length > 0
  config_path = ARGV[0]
elsif ENV.has_key? 'CITYSDK_CONFIG' and ENV['CITYSDK_CONFIG'].length
  config_path = ENV['CITYSDK_CONFIG']
end

config = nil
begin
  $config = JSON.parse(File.read(config_path), {symbolize_names: true})
rescue Exception => e
  $stderr.puts <<-ERROR
  Error loading CitySDK configuration file...
  Please set CITYSDK_CONFIG environment variable, or pass configuration file as a command line parameter
  Error message: #{e.message}
  ERROR
  exit!(-1)
end

# ================================== Create 'admr' layer ==================================

$nwb_layer = JSON.parse(File.read("#{File.dirname(__FILE__)}/nwb_layer.json"), symbolize_names: true)

# Set JSON-LD context
$nwb_layer[:context] = {
  :"@vocab" => "#{$config[:endpoint][:url]}layers/nwb/fields/"
}

$api = API.new($config[:endpoint][:url])
if not $api.authenticate($config[:owner][:name], $config[:owner][:password])
  puts 'Error authenticating with API'
  exit!(-1)
end

$stderr.puts ("Deleting layer 'nwb' and objects, if layer already exists...")
begin
  $api.delete('/layers/nwb')
rescue CitySDK::HostException => e
end
$stderr.puts ("Creating layer 'nwb'")
$api.post("/layers", $nwb_layer)
$api.set_layer('nwb')


DB = Sequel.connect("postgres://#{$config[:db][:user]}:#{$config[:db][:password]}@#{$config[:db][:host]}/#{$config[:db][:database]}")

# TODO: add more columns - house letters, etc.
columns = {
  :wvk_id => 'wegvak_id',
  :stt_naam => 'straatnaam',
  :gme_id => 'gemeente_id',
  :beginkm => 'begin_km',
  :eindkm => 'eind_km',
  :rijrichtng => 'rijrichting',
  :wegnummer => 'wegnummer',
  :wegdeelltr => 'wegdeel_letter',
  :hecto_lttr => 'hecto_letter',
  :baansubsrt => 'baan_subsoort'
}

index = 0

query = <<SQL
  SELECT
    #{columns.keys.map{ |c| c.to_s }.join(",")},
    -- Convert MultiLineStrings to LineStrings
    ST_AsGeoJSON(ST_CollectionHomogenize(geom)) AS geom
  FROM 
    wegvakken;
SQL


begin
  DB[query].use_cursor.each do |row|
 
    object = {
      type: 'Feature',
      geometry: JSON.parse(row[:geom]),
      properties: {
        title: row[:stt_naam],
        id: row[:wvk_id],
        data: {}
      }
    }
    
    columns.each do |k,v| 
      object[:properties][:data][v] = row[k]
    end

    $api.create_object(object)
    
    index += 1
    puts "Imported #{index} rows" if index % 1000 == 0     
  end
ensure
	$api.release
end

puts "done..."