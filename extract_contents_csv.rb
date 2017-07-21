require 'nokogiri'
require 'json'
require 'fileutils'
require 'csv'
require 'optparse'
require 'net/http'
require 'logger'

# Parsing Commandline Arguments
puts 'Parsing Arguments'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on("-r", "--rebuild-cache", "Run verbosely") do |v|
    options[:rebuild_cache] = v
  end

  opts.on("-t", "--travis", "Run as travis") do |v|
    options[:logger] = STDOUT
  end
end.parse!

ISLAND_INFO_URL     = 'http://www.ppk-kp3k.kkp.go.id/direktori-pulau/index.php/public_c/pulau_info/'

ISLAND_INDEX_URL    = 'http://www.ppk-kp3k.kkp.go.id/direktori-pulau/index.php/public_c/pulau_data'

PROVINCE_NAME_INDEX = 3

LOGGER = Logger.new(options[:logger] || 'logs')

def parse_coordinate(coordinate_text)
  results = { coordinates_degree: coordinate_text, coordinates_decimal: [] }
  if coordinate_text.split('LS').length > 1
    coordinates_dirty = coordinate_text.split('LS')
    results[:coordinates_decimal] = [
      degree_to_decimal(coordinates_dirty[1]),
      -degree_to_decimal(coordinates_dirty[0])
    ]
  elsif coordinate_text.split('LU').length > 1
    coordinates_dirty = coordinate_text.split('LU')
    results[:coordinates_decimal] = [
      degree_to_decimal(coordinates_dirty[1]),
      degree_to_decimal(coordinates_dirty[0])
    ]
  elsif coordinate_text.split('BT').length > 1
    coordinates_dirty = coordinate_text.split('BT')
    results[:coordinates_decimal] = [
      degree_to_decimal(coordinates_dirty[0]),
      degree_to_decimal(coordinates_dirty[1])
    ]
  elsif coordinate_text.split('U').length > 1
    coordinates_dirty = coordinate_text.split('U')
    results[:coordinates_decimal] = [
      degree_to_decimal(coordinates_dirty[1]),
      degree_to_decimal(coordinates_dirty[0])
    ]
  else
    coordinates_dirty = coordinate_text.split('S')
    results[:coordinates_decimal] = [
      degree_to_decimal(coordinates_dirty[1]),
      -degree_to_decimal(coordinates_dirty[0])
    ]
  end
  results
end

def degree_to_decimal(coordinate)
  split_hour   = clean_coordinate(coordinate).split('°')
  hour         = split_hour[0]
  split_minute = split_hour[1].split("\'")
  minute       = split_minute[0]
  split_second = split_minute[1].split('"')
  second       = split_second[0]
  hour.to_f + minute.to_f/60 + second.to_f/3600
end

def clean_coordinate(coordinate="dan 980 30' 48\" BT\r\n")
  coordinate.gsub(/\s/, '').gsub(' dan ', '').gsub('’', "'").gsub('o', '°')
end

def rebuild_cache
  LOGGER.info('Rebuilding cache')
  index_page = Nokogiri::HTML(Net::HTTP.get(URI(ISLAND_INDEX_URL)))
  LOGGER.info('Fetching started')
  i = 0
  t_number = 0
  threads = []
  mut = Mutex.new
  index_page.css('td a').each_slice(1000) do |links|
    threads << Thread.new do
      links.each do |link|
        tries = 3
        LOGGER.info("fetching #{i}..#{i + 100}") if (i+=1) % 100 == 0
        begin
          url = URI(link.attr('href'))
          File.write("htmls/#{url.to_s.split('/').last}", Net::HTTP.get(url))
        rescue Exception => e
          retry unless (tries -= 1 ).zero?
          LOGGER.error(e.message + " #{url.to_s}")
        end
      end
    end
    LOGGER.info "Thread #{t_number += 1} started"
  end
  threads.each &:join
end

if options[:rebuild_cache]
  rebuild_cache
end

ppk_htmls       = Dir.entries('htmls')[2..-1].each_slice(1000)
unresolved_html = []
results = {}

mutex = Mutex.new
threads = []
ppk_htmls.each_with_index do |chunk, index|
  threads << Thread.new do
    LOGGER.info "Thread #{index} started"
    chunk.each do |html|
      ppk_array = []
      nokogiri = ''
      f = File.open "htmls/#{html}"
      nokogiri = Nokogiri::HTML(f.read)
      f.close
      table_contents = nokogiri.css('#text_warp>table>tr')
      if !table_contents.first
        unresolved_html << html
        LOGGER.error("bad data on htmls/#{html}")
        next
      end
      ppk_array[0] = html
      ppk_array[1] = nokogiri.css('h1').first.text
      table_contents.each do |content|
        properties = content.css('td')
        case properties.first.text # Property Key
        when 'Nama Lain'
          ppk_array[2] = properties.last.text
        when 'Propinsi'
          ppk_array[3] = properties.last.text
        when 'Kabupaten'
          ppk_array[4] = properties.last.text.gsub('KABUPATEN', 'Kab.')
        when 'Kecamatan'
          ppk_array[5] = properties.last.text
        when 'Koordinat'
          if properties.css('table').length > 0
            raw_coordinate = properties.css('table').text.gsub("\r\n", '').gsub("\t", '')
            `echo #{ppk_array[8]} >> posible_bugs`
          elsif properties.last.css('sup').length > 0
            clean_coordinate = Nokogiri::HTML(properties.last.children[0].children.to_s.gsub('<sup>0</sup>', '°'))
            raw_coordinate = clean_coordinate.text
          elsif properties.last.text.match(/\?/)
            raw_coordinate = properties.last.text.gsub('?', '°')
            `echo #{ppk_array[8]} >> posible_bugs`
          else
            raw_coordinate = properties.last.text
          end
          ppk_array[6] = ''
          ppk_array[7] = ''
          begin
            ppk_array[7] = parse_coordinate(raw_coordinate)[:coordinates_decimal].reverse.join(',')
          rescue
            ppk_array[6] = raw_coordinate
          end
        end
      end

      # Split into province
      mutex.synchronize do
        results[ppk_array[PROVINCE_NAME_INDEX]] ||= []
        results[ppk_array[PROVINCE_NAME_INDEX]] << ppk_array
      end
    end
    LOGGER.info("Thread #{index} ended")
  end
end
LOGGER.info("started writing into files")

threads.each(&:join)
results.each do |province_name, province|
  csv_string = CSV.generate(
      write_headers: true,
      headers: [
        "Island number",
        "Island name",
        "Other Names",
        "Province",
        "Kabupaten",
        "Kecamatan",
        "Coordinate Degree",
        "Coordinate Decimal"
      ]) do |csv|
    province.each do |island|
      csv << island
    end
  end
  File.open("results/#{province_name}.csv", 'w') do |f|
    f.write csv_string
  end
end
