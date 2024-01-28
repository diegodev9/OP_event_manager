
require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

puts 'Event Manager Initialized!'

file = 'event_attendees.csv'
# file = 'large_event_attendees.csv'
template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

puts 'File not present' unless File.exist?(file)
return unless File.exist?(file)

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def fix_phone(phone)
  if phone.length < 10 || phone.length > 11
    '0000000000'
  elsif phone.length == 11 && phone.start_with?('1')
    phone_fixed = phone.chars.drop(1).join('')
    p "phone #{phone} fixed => #{phone_fixed}"
  else
    p "phone #{phone} is OK"
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def peak_registration(regdates)
  peak_hours = []
  peak_days = []
  calc_peaks(regdates.map(&:hour)).each { |peak| peak_hours << peak.first }
  calc_peaks(regdates.map { |date| date.strftime('%A') }).each { |peak| peak_days << peak.first }

  puts "Peak hours are: #{peak_hours.sort}"
  puts "Peak days are: #{peak_days.sort}"
end

def calc_peaks(data)
  data.group_by { |i| i }.map { |k, v| [k, v.count] if v.count > 1 }.compact
end

contents = CSV.open(file, headers: true, header_converters: :symbol)
regdates = []
contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone = fix_phone(row[:homephone])
  regdates << Time.strptime(row[:regdate], '%m/%d/%Y %k:%M')
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
end

peak_registration(regdates)
