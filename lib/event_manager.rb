require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

# Generate peak days
def top_registration_days(count = 3)
  days_array = extract_days_from_csv

  # Count the occurrences of each day
  day_counts = days_array.group_by { |day| day }
                        .transform_values(&:count)

  # Find the top three days with the highest counts
  top_days = day_counts.sort_by { |day, count| -count }.first(count)

  puts "Top #{count} registration day(s):"
  top_days.each do |day, count|
    puts "#{day.strftime('%A')} (#{count} registrations)"
  end
end

def extract_days_from_csv
  days_array = []

  CSV.foreach('event_attendees.csv', headers: true) do |row|
    reg_date = row['RegDate']
    parsed_time = DateTime.strptime(reg_date, '%m/%d/%y %H:%M')
    day = parsed_time.to_date
    days_array << day
  end
  days_array
end

# Generate peak hour intervals
def peak_hour_intervals
  hours_array = extract_hours_from_csv

  hour_intervals = create_hour_intervals(0..23, 3)
  interval_counts = count_registrations_in_intervals(hours_array, hour_intervals)
  top_intervals = find_top_intervals(interval_counts, 3)

  print_top_intervals(top_intervals)
end

def extract_hours_from_csv
  hours_array = []

  CSV.foreach('event_attendees.csv', headers: true) do |row|
    reg_date = row['RegDate']
    parsed_time = DateTime.strptime(reg_date, '%m/%d/%y %H:%M')
    hour = parsed_time.hour
    hours_array << hour
  end

  hours_array
end

def create_hour_intervals(range, step)
  range.step(step).to_a
end

def count_registrations_in_intervals(hours_array, hour_intervals)
  interval_counts = {}

  hours_array.each do |hour|
    interval = hour_intervals.find { |interval| hour.between?(interval, interval + 2) }
    interval_counts[interval] ||= 0
    interval_counts[interval] += 1
  end

  interval_counts
end

def find_top_intervals(interval_counts, top_count)
  interval_counts.sort_by { |interval, count| -count }.first(top_count)
end

def print_top_intervals(top_intervals)
  puts "Top registration hour intervals:"
  top_intervals.each do |interval, count|
    puts "Interval #{interval} - #{interval + 2}: #{count} registrations"
  end
end

# Generate clean zipcodes
def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = initialize_civic_info_service

  begin
    officials = fetch_officials(civic_info, zip)
  rescue
    return 'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end

  officials
end

def initialize_civic_info_service
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  civic_info
end

def fetch_officials(civic_info, zip)
  civic_info.representative_info_by_address(
    address: zip,
    levels: 'country',
    roles: ['legislatorUpperBody', 'legislatorLowerBody']
  ).officials
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

# Generate clean phone numbers
def clean_phone_number(homephone)
  cleannum = homephone.gsub(/[^0-9]/, '')

  if cleannum.length == 10
    cleannum
  elsif cleannum.length == 11 && cleannum[0] == '1'
    cleannum[1..-1]
  else
    "Bad Number"
  end
end

# Event manager starts
puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
# Display contents
contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone_number = clean_phone_number(row[:homephone])

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end

peak_hour_intervals
top_registration_days
