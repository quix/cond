$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"

# 
# http://www.gigamonkeys.com/book/beyond-exception-handling-conditions-and-restarts.html
# 

#
# Note:
# This file is ruby-1.8.7+ only.  For 1.8.6, require 'enumerator' and
# change input.each_line to input.to_enum(:each_line).
#

##########################################################
# setup

require 'cond/dsl'
require 'time'

class MalformedLogEntryError < StandardError
end

LOG_FILE = "log.txt"

LOG_FILE_CONTENTS = <<EOS
2007-01-12 05:20:03|event w
2008-02-22 11:11:41|event x
2008-09-04 15:30:43|event y
I like pancakes
2009-02-12 07:29:33|event z
EOS

File.open(LOG_FILE, "w") { |out|
  out.print LOG_FILE_CONTENTS
}

END { File.unlink(LOG_FILE) }

def parse_log_entry(text)
  time, event = text.split("|")
  if event
    return Time.parse(time), event
  else
    raise MalformedLogEntryError
  end
end

def find_all_logs
  [LOG_FILE]
end

def analyze_log(log)
  parse_log_file(log)
end

##########################################################
# book examples
#

#
# (defun parse-log-file (file)
#   (with-open-file (in file :direction :input)
#     (loop for text = (read-line in nil nil) while text
#        for entry = (handler-case (parse-log-entry text)
#                      (malformed-log-entry-error () nil))
#        when entry collect it)))
#
def parse_log_file0(file)
  File.open(file) { |input|
    input.each_line.inject(Array.new) { |acc, text|
      entry = handling do
        handle MalformedLogEntryError do
        end
        parse_log_entry(text)
      end
      entry ? acc << entry : acc
    }
  }
end

parse_log_file0(LOG_FILE)

# 
# (defun parse-log-file (file)
#   (with-open-file (in file :direction :input)
#     (loop for text = (read-line in nil nil) while text
#        for entry = (restart-case (parse-log-entry text)
#                      (skip-log-entry () nil))
#        when entry collect it)))
# 
def parse_log_file(file)
  File.open(file) { |input|
    input.each_line.inject(Array.new) { |acc, text|
      entry = restartable do
        restart :skip_log_entry do
          leave
        end
        parse_log_entry(text)
      end
      entry ? acc << entry : acc
    }
  }
end

Cond.with_default_handlers {
  parse_log_file(LOG_FILE)
}

# 
# (defun log-analyzer ()
#   (handler-bind ((malformed-log-entry-error
#                   #'(lambda (c)
#                       (invoke-restart 'skip-log-entry))))
#     (dolist (log (find-all-logs))
#       (analyze-log log))))
# 
def log_analyzer
  handling do
    handle MalformedLogEntryError do
      invoke_restart :skip_log_entry
    end
    find_all_logs.each { |log|
      analyze_log(log)
    }
  end
end

log_analyzer

