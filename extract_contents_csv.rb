require 'nokogiri'
require 'json'
require 'fileutils'
require 'byebug'
require 'csv'

ISLAND_INFO_URL = 'http://www.ppk-kp3k.kkp.go.id/direktori-pulau/index.php/public_c/pulau_info/'

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

ppk_htmls = Dir.entries('htmls')[2..-1]
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
    "Coordinate Decimal",
    "Url"
  ]
) do |csv|
  ppk_htmls.each do |html|
    ppk_array = []
    `echo #{html} >> logs`
    nokogiri = ''
    f = File.open "htmls/#{html}"
    nokogiri = Nokogiri::HTML(f.read)
    f.close
    table_contents = nokogiri.css('#text_warp>table>tr')
    if !table_contents.first
      `echo "bad data on htmls/#{html}" >> error_logs`
      next
    end
    ppk_array[8] = ISLAND_INFO_URL + html
    ppk_array[0] = html
    ppk_array[1] = nokogiri.css('h1').first
    table_contents.each do |content|
      properties = content.css('td')
      case properties.first.text # Property Key
      when 'Nama Lain'
        ppk_array[2] = properties.last.text
      when 'Propinsi'
        ppk_array[3] = properties.last.text
      when 'Kabupaten'
        ppk_array[4] = properties.last.text
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
        ppk_array[6] = raw_coordinate
        ppk_array[7] = parse_coordinate(raw_coordinate)[:coordinates_decimal].reverse.join(',') rescue ''
      end
    end
    csv << ppk_array
  end
end

File.write('island_with_administrative_area.csv', csv_string)