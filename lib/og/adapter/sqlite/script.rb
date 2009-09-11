# Helper for sqlite scripts.
#
# === Example
#
# sqlite 'filename', %{
#   drop database if exists weblog_development;
#   create database weblog_development;
#   grant all on weblog_development.* to #{`id -un`.strip}@localhost;
# }

def sqlite(opts, stream)
  IO.popen("mysql #{opts}", 'w') do |io| 
    io.puts stream
  end
end
