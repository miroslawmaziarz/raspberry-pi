require 'sqlite3'
require 'net/http'
require 'date'
require 'rest_client'
require 'json'


class SerialOutputParser
  VERSION = "1.2.2"
  PROGRAM_LOG = "pomiar.log"
  SERIAL_OUTPUT_PATH = "serial_output.data"

  # TEMPERATURE_SERVER_URL = "localhost:3000/temperatures/"
  TEMPERATURE_SERVER_URL = "crowdcare.vipserv.org/temperatures/"

  def initialize(mode)
    @mode = mode
  end

  def print_version
    %x{echo '#{VERSION}' >> #{SERIAL_OUTPUT_PATH}}
  end

  def read_sensors
    # %x{killall -9 minicom}
    (0..3).each do |n|
      program_log "/dev/ttyUSB#{n} " + File.exist?("/dev/ttyUSB#{n}").inspect
      program_log "minicom -C /home/mirek/projects/pomiar_temperatury/#{SERIAL_OUTPUT_PATH } -S /home/mirek/projects/pomiar_temperatury/get_temp --device=/dev/ttyUSB#{n}"

      if File.exist?("/dev/ttyUSB#{n}")
        # exec "minicom -C /home//mirek/projects/pomiar_temperatury/#{SERIAL_OUTPUT_PATH } -S /home/mirek/projects/pomiar_temperatury/get_temp --device=/dev/ttyUSB#{n}"
        program_log %x{minicom -C /home//mirek/projects/pomiar_temperatury/#{SERIAL_OUTPUT_PATH } -S /home/mirek/projects/pomiar_temperatury/get_temp --device=/dev/ttyUSB#{n}}
        break
      end
    end
  end

  def clear_log
    %x{echo '' > #{SERIAL_OUTPUT_PATH}}
  end

  def program_log(msg)
    %x{echo '#{msg}' >> #{PROGRAM_LOG}}
  end

  def parse
    sensors = []
    @temperatures = []

    sleep 4

    # sudo rm /var/lock/LCK..ttyUSB1

    file = File.new("#{SERIAL_OUTPUT_PATH}", 'r+')

    temp_rows_trigger = false

    while (line = file.gets)
      if temp_rows_trigger
        splitted = line.split(' ')
        @temperatures << {
          'serial_number' => splitted[0].strip,
          'value' => splitted[1].strip,
          'created_at' => DateTime.now.to_s
        }
      end
      temp_rows_trigger = true if line.strip.eql?('Pomiar')
      # temp_rows_trigger = false if line.strip.eql?('Koniec')
    end
    file.close

    @temperatures
  end

  def send_to_server(data = nil)
    uri = URI("http://#{TEMPERATURE_SERVER_URL}")

    p 'sending data'
    if (data || @temperatures).empty?
      p 'No data to send'
      return ''
    end
    res = RestClient.post "http://#{TEMPERATURE_SERVER_URL}",
      JSON.generate({temperatures: data || @temperatures}),
      :content_type => :json,
      :accept => :json

    program_log res.to_str
    res.to_str
  end

  def database
    return @db if @db

    @db = SQLite3::Database.new 'DS18S20_sensors.db'
    result = @db.execute <<-SQL
       CREATE TABLE IF NOT EXISTS measurement (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         sensor_nr VARCHAR(30),
         val INT,
         created_at DATETIME
       );
    SQL
    @db
  end

  def store_in_db
    # Insert some data into it
    @temperatures.each do |t|
      database.execute 'insert into measurement values (?, ?, ?, ?)', [nil, t['serial_number'], t['value'], t['created_at']]
    end
  end

  def print
    puts @temperatures.inspect
  end

  def print_from_db(limit=100)
    p 'database content: '
    # Find some records
    database.execute "SELECT * FROM measurement ORDER BY measurement.created_at DESC LIMIT #{limit};" do |row|
      p row
    end
  end

  def run_process
    if @mode=='send'
      # @db = SQLite3::Database.new 'DS18S20_sensors2.db'
      run_send_process
    else
      run_read_process

      if (Time.now.min % 10) == 0
        p 'Sending data'
        run_send_process
      end

    end
  end
  
  def run_read_process
    print_version
    clear_log
    read_sensors
    parse
    p @temperatures.inspect
    store_in_db
    print_from_db(6)
  end

  def run_send_process
    # print_from_db(999999)
    
    @temperatures ||= []

    r = database.execute "SELECT * FROM measurement;"

    p r.inspect

    r_hash = r.collect.each do |res|
      {
        'id' => res[0],
        'serial_number' => res[1],
        'value' => res[2],
        'created_at' => res[3]
      }
    end

    p r_hash

    res = eval(send_to_server(r_hash))

    p res

    if res.any?
      database.execute "DELETE FROM measurement WHERE id IN (#{res.join(',')});"
    end


  end
end

sop = SerialOutputParser.new(ARGV[0])
sop.run_process

