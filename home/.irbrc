require 'pp'
require 'json'

if defined?(IRB) && IRB.respond_to?(:conf)
  IRB.conf[:USE_AUTOCOMPLETE] = false
end

# Enable mapping an array of hashes by key: hashes.map[:key]
Enumerator.send(:define_method, :[]) { |key| map { |obj| obj[key] } }

def redis
  return @redis if defined?(@redis)
  begin
    require 'redis' unless defined?(Redis)
    @redis = begin
      Redis.new.tap(&:info) # needed to know if connection failed
    rescue
      Redis.new(:path => "/tmp/redis.sock")
    end
  rescue LoadError
    puts "redis gem not found"
  end
end

# table print (tp)
#
# prints 2D arrays of arrays in a nice table
#
# Example:
#
# > tp [1..10, "a".."l", "F".."O"].map(&:to_a)
# | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |   |   |
# |---|---|---|---|---|---|---|---|---|----|---|---|
# | a | b | c | d | e | f | g | h | i | j  | k | l |
# | F | G | H | I | J | K | L | M | N | O  |   |   |
# => nil
#
def tp(table, headers: nil, enclosed: true)
  headers = table.shift unless headers
  widths = headers.map(&:to_s).map(&:length)

  # find max length for each column
  table.each do |row|
    row.each_with_index do |cell, i|
      widths[i] = [cell.to_s.length, widths[i]].compact.max
    end
  end

  row_str = proc do |row, space|
    String.new.tap do |s|
      s << "|#{space}" if enclosed
      cols = widths.map.with_index do |width, col|
        row[col].to_s.ljust(width, space)
      end
      s << cols.join("#{space}|#{space}")
      s << "#{space}|" if enclosed
    end
  end

  puts row_str.(headers, " ")
  puts row_str.([], "-") # spacer
  table.each { |row| puts row_str.(row, " ") }
  nil
end

def read_utf16
  JSON.parse(%|"#{STDIN.gets(chomp: true)}"|)
end

if defined?(ActiveSupport::TimeZone)
  def tz
    ActiveSupport::TimeZone["US/Mountain"]
  end
end

if defined?(ActiveRecord::Base)
  class AR
    class << self
      def e(sql)
        ActiveRecord::Base.connection.execute(sql).to_a
      end

      def silent(&blk)
        with_log nil, &blk
      end

      def with_log(path = nil)
        old_logger = ActiveRecord::Base.logger
        begin
          logger = path ? Logger.new(path) : nil
          ActiveRecord::Base.logger = logger
          yield
        ensure
          ActiveRecord::Base.logger = old_logger
        end
        File.size(path) if path
      end
    end
  end

  class ActiveRecord::Base
    def self.sample
      s = scoped
      c = s.count
      s.offset(rand(c)).first
    end

    def self.e(sql)
      execute(sql).to_a
    end
  end
end

def show_ops(name = "Rate")
  sample_length = 1.0
  loop do
    start_at = Time.now
    stop_at = start_at + sample_length
    count = 0
    loop do
      yield
      count += 1
      break if Time.now > stop_at
    end
    elapsed = Time.now - start_at
    print "\r#{name}: #{(count / elapsed).round(4)} ops/sec"
  end
end

def truncate_tables
  whitelist = %w(spatial_ref_sys schema_migrations)
  (ActiveRecord::Base.connection.tables - whitelist).each do |table|
    ActiveRecord::Base.connection.truncate(table)
  end
end

# pretty print to string
def pps(obj)
  StringIO.new.tap do |buffer|
    PP.pp(obj, buffer)
    buffer.rewind
  end.read
end
