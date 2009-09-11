####################
# This is bad form!!!!!!!!!!!!!!
# It's here temporarily for Nitro's sake!
#####################

require 'facets/logger'

# Global logger interface. This provides an alternative
# Singleton interface to the Logger.

class Logger
  class << self

    def debug(str)
      global_logger.debug(str)
    end

    def info(str)
      global_logger.info(str)
    end

    def error(str)
      global_logger.error(str)
    end

    def warn(str)
      global_logger.warn(str)
    end

    # Get the global Logger.

     def global_logger
       @@global_logger
     end
     alias_method :get, :global_logger

    # Set the global Logger.

     def global_logger=(logger)
        if logger.is_a?(String) || logger.is_a?(IO)
          @@global_logger = Console::Logger.new(logger)
        elsif logger.is_a?(Logger)
          @@global_logger = logger
        else
          raise ArgumentError
        end

        @@global_logger.setup_format do |severity, timestamp, progname, msg|
          SIMPLE_FORMAT % [severity, msg]
        end
     end

     def set(logger, &format_proc)
       logger.setup_format(&format_proc) if block_given?
       self.global_logger = logger
     end

    # Replace the global Logger. Preserve the formatting option.

    def replace(logger)
      old = global_logger
      set(logger, &old.send(:format_proc))
    end

  end

end

# Convienience methods. These allow for shorter lines of code.
# One nice feature is that you can add a method name to your
# classes to add special logging.
#
# === Examples of customized logging
#
# class Article
#   def debug(str)
#     Logger.debug("Debuging from article: #{str}")
#   end
# end
#
# class Object
#   def debug(str)
#     Logger.debug("#{self.class}: #{str}")
#   end
# end

def debug(str)
  Logger.debug(str)
end

def info(str)
  Logger.info(str)
end

def error(str)
  Logger.error(str)
end

def warn(str)
  Logger.warn(str)
end

# Initialize a default global logger.

Logger.set(STDERR)
