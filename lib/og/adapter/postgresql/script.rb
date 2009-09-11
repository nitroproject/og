# Helper for psql scripts.
#
# === Example
#
# psql '-u root -p', %{
#   drop database if exists weblog_development;
#   create database weblog_development;
#   grant all on weblog_development.* to #{`id -un`.strip}@localhost;
# }

def psql(opts, stream)
  IO.popen("psql #{opts}", 'w') do |io| 
    io.puts stream
  end
end
