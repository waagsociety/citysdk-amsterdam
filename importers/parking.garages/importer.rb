#encoding: utf-8

require 'json'
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
  config = JSON.parse(File.read(config_path), {symbolize_names: true})
rescue Exception => e
  $stderr.puts <<-ERROR
  Error loading CitySDK configuration file...
  Please set CITYSDK_CONFIG environment variable, or pass configuration file as a command line parameter
  Error message: #{e.message}
  ERROR
  exit!(-1)
end

# ================================== Create 'parking.garages' layer ==================================

$park_layer = JSON.parse(File.read("#{File.dirname(__FILE__)}/layer.json"), symbolize_names: true)

# Set JSON-LD context
$park_layer[:context] = {
  :"@vocab" => "#{config[:endpoint][:base_uri]}#{config[:endpoint][:endpoint_code]}/layers/parking.garage/fields/"
}

$api = API.new(config[:endpoint][:url])
if not $api.authenticate(config[:owner][:name], config[:owner][:password])
  puts 'Error authenticating with API'
  exit!(-1)
end

$stderr.puts ("Deleting layer 'parking.garage' and objects, if layer already exists...")
begin
  $api.delete('/layers/parking.garage')
rescue CitySDK::HostException => e
end

$stderr.puts ("Creating layer 'parking.garage'")
$api.post("/layers", $park_layer)

$api.batch_size = 25

# ==================================== Municipalities ====================================

$stderr.puts ('Importing parking locations')
params = {
  file_path: './data/ParkingLocation.json',
  title: :Name,
  host: config[:endpoint][:url],
  layer: $park_layer[:name],
  login: config[:owner][:name],
  password: config[:owner][:password]
}

imp = Importer.new(params)

imp.do_import do |object_datum|
  puts JSON.pretty_generate(object_datum)
end

