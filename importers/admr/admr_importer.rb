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
  :"@vocab" => "#{config[:endpoint][:base_uri]}#{config[:endpoint][:endpoint_code]}/layers/admr/fields/"
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

$api.batch_size = 25

# ==================================== Municipalities ====================================

$stderr.puts ('Importing municipalities')
params = {
  file_path: './data/gemeente.zip',
  title: 'gemeentenaam',
  host: config[:endpoint][:url],
  layer: 'admr',
  # EPSG:28992, Dutch coordinate system Amersfoort / RD New
  srid: '28992',
  name: config[:owner][:name],
  password: config[:owner][:password]
}

imp = Importer.new(params)

# for this layer (admr) we are not interested in most of the demographic fields.
# so we empty the 'fields' array except for the fields we're interested in.
params[:fields] = [:GM_NAAM, :GM_CODE]

# we can change the name of the individual fields
params[:alternate_fields][:GM_NAAM] = 'gemeentenaam'
params[:alternate_fields][:GM_CODE] = 'gemeente_code'


# you can adjust each individual data frame
# this hash (object_datum) has a :data hash, an :id and a :title
# below we change the :id (layername + :id will be the cdk_id)
# we also add an extra data field (:admn_level)
imp.do_import do |object_datum|
  if object_datum[:data]['gemeentenaam'].blank?
    object_datum[:id] = 'nl.' + object_datum[:data]['gemeente_code']
  else
    object_datum[:id] = 'nl.' + object_datum[:data]['gemeentenaam']
  end
  object_datum[:data][:admn_level] = 3
  
  # set object_datum[:data] to nil if you do not want to import this record
  object_datum[:data] = nil if object_datum[:id] == 'nl.'
end



# ==================================== Districts ====================================

$stderr.puts ('Importing districts')
params = {
  file_path: './data/wijk.zip',
  title: 'wijknaam',
  host: config[:endpoint][:url],
  layer: 'admr',
  srid: '28992',
  name: config[:owner][:name],
  password: config[:owner][:password]
}

imp = Importer.new(params)


params[:fields] = [:GM_NAAM, :GM_CODE, :WK_CODE, :WK_NAAM]


params[:alternate_fields][:GM_NAAM] = 'gemeentenaam'
params[:alternate_fields][:GM_CODE] = 'gemeente_code'
params[:alternate_fields][:WK_CODE] = 'wijk_code'
params[:alternate_fields][:WK_NAAM] = 'wijknaam'


imp.do_import do |object_datum|
  id = object_datum[:data]['gemeentenaam'] + '.' + object_datum[:data]['wijknaam']
  id = object_datum[:data]['gemeente_code'] + '.' + object_datum[:data]['wijk_code'] if id == '.'
  object_datum[:id] = 'nl.' + id
  object_datum[:data][:admn_level] = 4
end

# ==================================== Neighbourhoods ====================================

$stderr.puts ('Importing neighbourhoods')
params = {
  file_path: './data/buurt.zip',
  title: 'buurtnaam',
  host: config[:endpoint][:url],
  layer: 'admr',
  srid: '28992',
  name: config[:owner][:name],
  password: config[:owner][:password]
}

imp = Importer.new(params)


params[:fields] = [:BU_CODE, :BU_NAAM, :GM_NAAM, :GM_CODE, :WK_CODE]


params[:alternate_fields][:GM_NAAM] = 'gemeentenaam'
params[:alternate_fields][:GM_CODE] = 'gemeente_code'
params[:alternate_fields][:WK_CODE] = 'wijk_code'
params[:alternate_fields][:BU_CODE] = 'buurt_code'
params[:alternate_fields][:BU_NAAM] = 'buurtnaam'



imp.do_import do |object_datum|
  id = object_datum[:data]['buurt_code'] + '.' + object_datum[:data]['buurtnaam']
  if id != '.'
    object_datum[:id] = 'nl.' + id
    object_datum[:data][:admn_level] = 5
  else
    object_datum[:data] = nil
  end
end


# ===================================== Provinces =====================================

$stderr.puts ('Importing provinces')

params = {
  file_path: './data/provincies.zip',
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
  file_path: './data/landsgrens.zip',
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
