#encoding: utf-8

require 'citysdk'
include CitySDK

require_relative './fieldnames.rb'

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

$cbs_layer = JSON.parse(File.read("#{File.dirname(__FILE__)}/cbs_layer.json").force_encoding('UTF-8'), symbolize_names: true)

# Set JSON-LD context
$cbs_layer[:context] = {
  :"@vocab" => "#{config[:endpoint][:url]}layers/cbs/fields/"
}

$api = API.new(config[:endpoint][:url])
if not $api.authenticate(config[:owner][:name], config[:owner][:password])
  puts 'Error authenticating with API'
  exit!(-1)
end

$stderr.puts ("Deleting layer 'cbs' and objects, if layer already exists...")
begin
  $api.delete('/layers/cbs')
rescue CitySDK::HostException => e

end
$stderr.puts ("Creating layer 'cbs'")
$api.post("/layers", $cbs_layer)

$api.batch_size = 25
$api.set_layer('cbs')

# ==================================== Municipalities ====================================

$stderr.puts ('Importing CBS Municipality Statistics')
params = {
  file_path: '../admr/data/gemeente.zip',
}

file_r = FileReader.new(params)

file_r.content.each do |c|
  ndata = {}
  c.delete(:geometry)
  c[:properties].delete(:title)
  c[:properties].delete(:id)
  c[:properties][:data].each do |k,v|
    ndata[$fieldnames[k]] = v
  end
  c[:properties][:data] = ndata


  if c[:properties][:data]['gemeentenaam'].blank?
    c[:properties][:cdk_id] = CitySDK.make_cdk_id('admr', 'nl.' + c[:properties][:data]['gemeente_code'])
  else
    c[:properties][:cdk_id] = CitySDK.make_cdk_id('admr', 'nl.' + c[:properties][:data]['gemeentenaam'])
  end

  $api.create_object(c)
end


# ==================================== Districts ====================================

$stderr.puts ('Importing CBS District Statistics')
params = {
  file_path: '../admr/data/wijk.zip',
}

file_r = FileReader.new(params)

file_r.content.each do |c|
  ndata = {}
  c.delete(:geometry)
  c[:properties].delete(:title)
  c[:properties].delete(:id)
  c[:properties][:data].each do |k,v|
    ndata[$fieldnames[k]] = v
  end
  c[:properties][:data] = ndata

  id = c[:properties][:data]['gemeentenaam'] + '.' + c[:properties][:data]['wijknaam']
  id = c[:properties][:data]['gemeente_code'] + '.' + c[:properties][:data]['wijk_code'] if id == '.'

  c[:properties][:cdk_id] = CitySDK.make_cdk_id('admr', 'nl.' + id)


  $api.create_object(c)
end


# ==================================== Neighbourhoods ====================================

$stderr.puts ('Importing CBS Neighbourhood Statistics')
params = {
  file_path: '../admr/data/buurt.zip',
}

file_r = FileReader.new(params)

file_r.content.each do |c|
  ndata = {}
  c.delete(:geometry)
  c[:properties].delete(:title)
  c[:properties].delete(:id)
  c[:properties][:data].each do |k,v|
    ndata[$fieldnames[k]] = v
  end
  c[:properties][:data] = ndata

  id = c[:properties][:data]['buurt_code'] + '.' + c[:properties][:data]['buurtnaam']
  if id != '.'
    c[:properties][:cdk_id] = CitySDK.make_cdk_id('admr', 'nl.' + id)
    $api.create_object(c)
  end
end

$api.release


