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

# ================================== Create 'admr' layer ==================================

$admr_layer = JSON.parse(File.read("#{File.dirname(__FILE__)}/admr_layer.json"), symbolize_names: true)

# Set JSON-LD context
$admr_layer[:context] = {
  :"@vocab" => "#{config[:endpoint][:url]}layers/admr/fields/"
}

$api = API.new(config[:endpoint][:url])
if not $api.authenticate(config[:owner][:name], config[:owner][:password])
  puts 'Error authenticating with API'
  exit!(-1)
end

$stderr.puts ("Deleting layer 'admr' and objects, if layer already exists...")
begin
  $api.delete('/layers/admr')
rescue CitySDK::HostException => e
end
$stderr.puts ("Creating layer 'admr'")
$api.post("/layers", $admr_layer)

# ==================================== Municipalities ====================================

$stderr.puts ('Importing municipalities')
params = {
  file_path: 'gemeenten.zip',
  title: 'gemeentenaam',
  host: config[:endpoint][:url],
  layer: 'admr',
  # EPSG:28992, Dutch coordinate system Amersfoort / RD New
  srid: '28992',
  name: config[:owner][:name],
  password: config[:owner][:password]
}

imp = Importer.new(params)

# we can change the name of the individual fields
params[:alternate_fields][:gemeentena] = 'gemeentenaam'

# we can also remove fields that we are not interested in importing
params[:alternate_fields][:gid] = nil

# you can adjust each individual data frame
# this hash (object_datum) has a :data hash, an :id and a :title
# below we change the :id (layername + :id will be the cdk_id)
# we also add an extra data field (:admn_level)
imp.do_import do |object_datum|
  object_datum[:id] = 'nl.' + object_datum[:data]['gemeentenaam'].downcase
  object_datum[:data][:admn_level] = 3
end

# ===================================== Provinces =====================================

$stderr.puts ('Importing provinces')

params = {
  file_path: 'provincies.zip',
  title: 'provincienaam',
  host: config[:endpoint][:url],
  layer: 'admr',
  srid: '28992',
  name: config[:owner][:name],
  password: config[:owner][:password]
}

imp = Importer.new(params)
params[:alternate_fields][:provincien] = 'provincienaam'
params[:alternate_fields][:gid] = nil

imp.do_import do |object_datum|
  object_datum[:id] = 'nl.prov.' + object_datum[:data]['provincienaam'].downcase
  object_datum[:data][:admn_level] = 1
end

# ===================================== Country =====================================

$stderr.puts ('Importing national border')
params = {
  file_path: 'landsgrens.zip',
  title: 'landsnaam',
  layer: 'admr',
  srid: '28992',
  host: config[:endpoint][:url],
  name: config[:owner][:name],
  password: config[:owner][:password]
}
imp = Importer.new(params)
params[:alternate_fields][:gid] = nil

imp.do_import do |object_datum|
  object_datum[:id] = 'nederland'
  object_datum[:data][:admn_level] = 0
end
