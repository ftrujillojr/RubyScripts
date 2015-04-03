#!/usr/bin/env ruby

# First of all.  I am a NEWbie at Ruby.   BUT, rvm and rbenv have a lot of 
# "stuff" that I do not need and they only work on BASH.   Thousands of
# developers use rvm and rbenv.   This is NOT to replace those tools.  Maybe
# one day, I too will be smart enough to memorize all of the incantations of
# rvm and rbenv to use them.  This solution is aimed at CSH env.  SIMPLE.
#
#    This script has two classes.   I know...I know.  Pull them out into separate files.
#
#    The intent is to use an alias to source the enviroment after user selection.
#     
#    alias crb '$HOME/bin/crb.rb;source /tmp/rubyenv.cmd'
#
# Now, I am using rescue in my code.  I have seen posts where real Ruby developers
# will "stab me".   Well,  I use rescue in two situtions below.
#     1)  rescue,  re-raise           (Inside a class.  That way this code could be command line and library)
#     2)  rescue,  display,  exit     (TOP)

BEGIN {
  $-w = true
  
  $program_directory = String.new(File.dirname($0))
  
  # This will add the program directory to the $LOAD_PATH
  if($LOAD_PATH.grep(/^#{$program_directory}$/).size() == 0) then
    $LOAD_PATH.unshift($program_directory)
  end
  
  # To add other ruby paths to $LOAD_PATH, then push values to this Array
  ruby_globs = Array.new
  ##ruby_globs.push("#{ENV['HOME']}/rubylib/**/lib/*.rb")
  ##ruby_globs.push("#{ENV['HOME']}/GITHUB/**/lib/*.rb")

  ruby_globs.each do |ruby_glob|
    Dir.glob(ruby_glob).each do |file|
      lib_path = File.dirname(file)
      if($LOAD_PATH.grep(/^#{lib_path}$/).size() == 0) then
        $LOAD_PATH.unshift(lib_path)
      end
    end
  end
 
  $script_status = 0
}

END {
  if $script_status >= 4
    $stderr.printf("STATUS: %d\n", $script_status.to_i);
  end
}

require "pp"

module FJT
  # You may have to install this one gem.
  # http://ruby-doc.org/stdlib-1.9.3/libdoc/optparse/rdoc/OptionParser.html
  require "optparse"
  
  REQ_SWITCH = 100
  OPT_SWITCH = 200
  
  class Option_parser_wrapper_exception < Exception
  end
  class Option_parser_wrapper_help_thrown_exception < Exception
  end

  class Option_parser_wrapper
    public 
    
    def initialize(opts_map)
      @options        = Hash.new
      @options_map    = Hash.new
      @remaining_args = Array.new
      @switch_type    = Hash.new
      
      classname = self.class.to_s
      
      if(opts_map.class != Hash)
        raise Option_parser_wrapper_exception, 
          "ERROR: You must pass 1 Hash to #{classname}.new(opts_map)"
      else
        opts_map.each do |key, val|
          @options[key] = val.shift      # DEFAULT VALUE
          @switch_type[key] = val.shift  # FJT::REQ_SWITCH or FJT::OPT_SWITCH
          if @switch_type[key] == FJT::REQ_SWITCH
            tmp = val.pop()
            tmp += " (REQUIRED)"
            val.push(tmp)
            @options_map[key] = val
          else
            @options_map[key] = val
          end
        end
      end
      
    end
    
    def parse()
      program_name = String.new(File.basename($0))
  
      @optparse = OptionParser.new do |opts|
        opts.banner = "Usage: #{program_name} "
         
        @options_map.each do |key, val|
          opts.on(*val) do |arg|
            @options[key] = arg
          end
        end
      end
      
      begin
        @optparse.parse!
      rescue Exception => ex
        puts @optparse
        raise ex
      end
      if(@options[:help])
        puts @optparse
        raise Option_parser_wrapper_help_thrown_exception
      end
      
      @options.each do |key, val|
        if @switch_type[key] == FJT::REQ_SWITCH
          if @options[key] == nil || 
            (@options[key].class == Array && @options[key].size()==0)
            puts @optparse
            raise Option_parser_wrapper_exception, "REQUIRED switch on command line not given => --#{key}\n"
          end
        end
      end
      
      ARGV.each do| remaining_arg |
        @remaining_args.push(remaining_arg)
      end
  
      if(@options[:debug] >= 3)
        if(@options[:debug] >= 4)
          display_load_path()
        end
        display_options()
      end
      
      return @options
    end
    
    def get_options
      return @options
    end
    
    def get_remaining_args
      return @remaining_args
    end

    private
    
    def display_options
      banner = "=" * 45
      puts "OPTIONS:\n#{banner}\n"
      @options.each do |key, val|
        type = val.class.to_s
        $stderr.printf "%-15s %-12s => %s\n", key, type, val
      end
      puts ""
    end
    
    def display_load_path
      banner = "=" * 45
      $stderr.printf "LOAD_PATH:\n#{banner}\n"
      $LOAD_PATH.each do |lpath|
        $stderr.printf "%s\n", lpath
      end
      $stderr.puts ""
    end
  end # end class Option_parser_wrapper


################################################################################

  class RubyEnvironment_exception < Exception
  end

  class RubyEnvironment
    public 

    def initialize(options_map)

      if(options_map.class != Hash)
        raise RubyEnvironment_exception, 
          "ERROR: You must pass 1 Hash to #{classname}.new(opts_map)"
      end
      
      fjt_opts = FJT::Option_parser_wrapper.new(options_map)

      @options = fjt_opts.parse()
      @remaining_args = fjt_opts.get_remaining_args()
      @installed_dirs = get_installed_dirs()

      end # initialize

      def execute()
        begin

          if(@options[:list])  
            @installed_dirs.sort.reverse.each do |key, val|
              printf "%-18s => %s\n", key, val
            end  
          else
            keys = @installed_dirs.keys.sort
            idx = 0
            printf "%d => System default ruby\n", idx
            idx += 1

            keys.each do |key|
              printf "%d => %s\n", idx, key
              idx += 1
            end 

            choice = prompt("\nMake selection: ")

            printf "\nWriting to %s\n\n",  @options[:output]

            if(choice.to_i > 0)
              if(@installed_dirs.has_key?(keys[choice.to_i-1]))
                dir = @installed_dirs[keys[choice.to_i-1]]
                create_env_script(dir, @options[:output])
              else
                if(File.exist?(@options[:output]))
                  File.delete(@options[:output])
                end
                raise RubyEnvironment_exception, 
                  "ERROR: Invalid selection made.  No change to ENV"        
              end  
            else
                create_env_script(nil, @options[:output])
            end 

            system("chmod 755 " + @options[:output])
          end # @options[:list]

        rescue Exception => ex2
          raise
        end # begin
      end # execute()


    private


    def get_installed_dirs()
      dirs = Hash.new

      ruby_globs = Array.new
      ## This is where you compile and release new Ruby versions
      ## /opt/ruby/ruby-2.2.1
      ## /opt/ruby/ruby-1.9.3-p484
      ruby_globs.push("/opt/ruby/ruby*")  
      ## You can add more by pushing more.  Notice the * for the glob.

      ruby_globs.each do |ruby_glob|
        Dir.glob(ruby_glob).each do |file|
          if (File.directory?(file))
            key = File.basename(file)
            dirs[key] = file
          end
        end
      end

      return dirs
    end


    def create_env_script(dir, outputFilename)
      fh = File.open(outputFilename, 'w')
      fh.write("\#!/bin/csh -f\n\n")

      if(dir == nil) 
        fh.write(sprintf "source %sHOME/.cshrc\n\n", '$')
        fh.write(sprintf "set prompt =  '%sM:%s/ [%sh]%s# '\n", '%','%','%','%')
      else
        envPath = String.new(ENV['PATH'])
        paths = envPath.split(":")
        rubyPath = dir
        basename = File.basename(dir)
        rubyPathBin = rubyPath + "/bin"
        gemHome = rubyPath + "/lib/ruby/gems"
        gemHomeBin = rubyPath + "/lib/ruby/gems/bin"

        fh.write(sprintf "setenv RUBYPATH %s\n", rubyPath)
        fh.write(sprintf "setenv GEM_HOME %s\n\n", gemHome)
        fh.write(sprintf "set path = (%s %s ", rubyPathBin, gemHomeBin)

        paths.each do |path|
          if(path =~ /\/ruby/) 
            # nothing.  Ruby 1.8.7 does not have !~ like Ruby 1.9+
          else
            fh.write(sprintf "%s ", path)
          end
        end
        fh.write(sprintf ")\n\n")
        fh.write(sprintf "set prompt =  '%s %sM:%s/ [%sh]%s# '\n", basename,'%','%','%','%')
      end

      fh.write(sprintf "rehash\n")
      fh.close();
    end


    def prompt(*args)
        $stderr.print(*args)
        val = gets.strip
        return val
    end

  end # class RubyEnvironment


end  # module FJT


  
    

# ############################################################################

def display_exception(ex, status, verbose=false)
  $script_status = status
  $stderr.puts "\n#{ex.class.to_s}"
  if(ex.class.to_s != ex.message)
    $stderr.printf("\n%s\n", ex.message)
  end
  if(verbose)
    $stderr.printf("\nBACKTRACE:\n")
    $stderr.puts ex.backtrace
    $stderr.puts "\n\nKERNEL caller:\n"
    $stderr.puts PP.pp Kernel.caller
    $stderr.puts ""
  end
end

# http://stackoverflow.com/questions/582686/should-i-define-a-main-method-in-my-ruby-scripts
# This is good advice - this way, your file is usable both as a standalone executable and as a library

if __FILE__ == $0

  begin
    # http://ruby-doc.org/stdlib-1.9.3/libdoc/optparse/rdoc/OptionParser.html
    # See OptionParser.on() for arguments to that method.  Put in option_map as
    # array.
    options_map = Hash.new
    #                       default               RequiredOrOptional  OptionParser.on() method params
    #                       ========              ==================  =================================================
    options_map[:output]  = ["/tmp/rubyenv.cmd",  FJT::OPT_SWITCH,    '-o', '--output FILENAME',        'The output command filename to create']

    options_map[:list]    = [false,               FJT::OPT_SWITCH,    '-l', '--list',                   'List installed Ruby versions and exit']
    options_map[:debug]   = [0,                   FJT::OPT_SWITCH,    '-d', '--debug [LEVEL]', Integer, 'Set debug LEVEL']
    options_map[:help]    = [false,               FJT::OPT_SWITCH,    '-h', '--help',                   'Display this screen']
    
    rubyEnv = FJT::RubyEnvironment.new(options_map)
    rubyEnv.execute();

    rescue FJT::RubyEnvironment_exception => ex
      display_exception(ex, 7, false)
    rescue FJT::Option_parser_wrapper_help_thrown_exception => ex
      puts "\nRun this command with no parameters or with just --output\n\n"
      display_exception(ex, 6, false)
    rescue FJT::Option_parser_wrapper_exception => ex
      display_exception(ex, 5, false)
    rescue OptionParser::InvalidOption => ex
      display_exception(ex, 4, false)
    rescue OptionParser::MissingArgument => ex
      display_exception(ex, 3, false)
    rescue SystemExit => ex
      display_exception(ex, 2, false)
    rescue Exception => ex
      display_exception(ex, 1, true)
  end
  exit $script_status

end



