require 'json'
require 'ox'
require 'georuby'


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

# ================================== Create 'parking.areas' layer ==================================

$layer = JSON.parse(File.read("#{File.dirname(__FILE__)}/layer.json"), symbolize_names: true)

# Set JSON-LD context
$layer[:context] = {
  :"@vocab" => "#{config[:endpoint][:base_uri]}#{config[:endpoint][:endpoint_code]}/layers/#{$layer[:name]}/fields/"
}

$api = API.new(config[:endpoint][:url])
if not $api.authenticate(config[:owner][:name], config[:owner][:password])
  puts 'Error authenticating with API'
  exit!(-1)
end

$stderr.puts ("Deleting layer '#{$layer[:name]}' and objects, if layer already exists...")
begin
  $api.delete("/layers/#{$layer[:name]}")
rescue CitySDK::HostException => e

end
$stderr.puts ("Creating layer '#{$layer[:name]}'")
$api.post("/layers", $layer)

$api.batch_size = 1

# ==================================== Municipalities ====================================

$stderr.puts ("Importing #{$layer[:name]}")
$api.set_layer($layer[:name])


class LibHandler < ::Ox::Sax

  def initialize
    @entry = nil
  end

  def start_element(name)
    # puts "SE: #{name}"
    if name == :entry
      @entry = {properties: {}}
    end
  end

  def parseWKT(s)
    begin
      f = GeoRuby::SimpleFeatures::GeometryFactory::new
      p = GeoRuby::SimpleFeatures::EWKTParser.new(f)
      p.parse(s)
      return f.geometry
      # return g.srid,g.as_json[:type],g
    rescue => e
    end
    nil
  end

  def end_element(name)
    return if name == :'d:AreaGeometryGml'

    if name == :'d:AreaGeometryTxt'
      @entry[:geometry] =  parseWKT(@v)
      return
    end
    # puts "EE: #{name}"
    if name == :entry
      o = {geometry: @entry[:geometry]}
      o[:properties] = {}
      o[:properties][:id] = @entry[:properties]['AREAGEOMETRY_ID']
      @entry[:properties].delete('AREAGEOMETRY_ID')
      o[:properties][:data] = @entry[:properties]
      o[:properties][:title] = @entry[:properties]['AreaId']

      puts JSON.pretty_generate o

      $api.create_object(o)
      @entry = {properties: {}}
    elsif name.to_s =~ /d:(.+)/
      @entry[:properties][$1] = @v
    end
  end

  def attr(name, value)
    # puts "ATTR: #{name} => #{value}"
  end

  def text(value)
    @v = value
  end

end

handler = LibHandler.new
Ox.sax_parse(handler, File.open('./data/AREAGEOMETRY'))
$api.release

# $out.close
