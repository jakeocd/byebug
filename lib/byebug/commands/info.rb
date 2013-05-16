module Byebug

  module InfoFunctions
    def info_catch(*args)
      unless @state.context
        print "No frame selected.\n"
        return
      end
      if Byebug.catchpoints and not Byebug.catchpoints.empty?
        Byebug.catchpoints.each do |exception, hits|
          print "#{exception}: #{exception.is_a?(Class)}\n"
        end
      else
        print "No exceptions set to be caught.\n"
      end
    end
  end

  # Implements byebug "info" command.
  class InfoCommand < Command
    include Columnize
    self.allow_in_control = true

    Subcommands =
      [
       ['args', 1, 'Argument variables of current stack frame'],
       ['breakpoints', 1, 'Status of user-settable breakpoints',
        'Without argument, list info about all breakpoints. With an integer ' \
        'argument, list info on that breakpoint.'],
       ['catch', 3,
        'Exceptions that can be caught in the current stack frame'],
       ['display', 2, 'Expressions to display when program stops'],
       ['file', 4, 'Info about a particular file read in',
        'After the file name is supplied, you can list file attributes that ' \
        'you wish to see. Attributes include: "all", "basic", "breakpoint", ' \
        '"lines", "mtime", "path" and "sha1".'],
       ['files', 5, 'File names and timestamps of files read in'],
       ['global_variables', 2, 'Global variables'],
       ['instance_variables', 2,
        'Instance variables of the current stack frame'],
       ['line', 2,
        'Line number and file name of current position in source file'],
       ['locals', 2, 'Local variables of the current stack frame'],
       ['program', 2, 'Execution status of the program'],
       ['stack', 2, 'Backtrace of the stack'],
       ['variables', 1,
        'Local and instance variables of the current stack frame']
      ].map do |name, min, short_help, long_help|
      SubcmdStruct.new(name, min, short_help, long_help)
    end unless defined?(Subcommands)

    InfoFileSubcommands =
      [
       ['all', 1, 'All file information available - breakpoints, lines, ' \
        'mtime, path and sha1'],
       ['basic', 2, 'basic information - path, number of lines'],
       ['breakpoints', 2, 'Show trace line numbers',
        'These are the line number where a breakpoint can be set.'],
       ['lines', 1, 'Show number of lines in the file'],
       ['mtime', 1, 'Show modification time of file'],
       ['path', 4, 'Show full file path name for file'],
       ['sha1', 1, 'Show SHA1 hash of contents of the file']
      ].map do |name, min, short_help, long_help|
      SubcmdStruct.new(name, min, short_help, long_help)
    end unless defined?(InfoFileSubcommands)

    def regexp
      /^\s* i(?:nfo)? (?:\s+(.*))?$/ix
    end

    def execute
      return help(@match) unless @match[1]

      args = @match[1].split(/[ \t]+/)
      param = args.shift
      subcmd = find(Subcommands, param)
      if subcmd
        send("info_#{subcmd.name}", *args)
      else
        errmsg "Unknown info command #{param}\n"
      end
    end

    def info_args(*args)
      unless @state.context
        print "No frame selected.\n"
        return
      end
      locals = @state.context.frame_locals(@state.frame_pos)
      args = @state.context.frame_args(@state.frame_pos)
      args.each do |name|
        s = "#{name} = #{locals[name].inspect}"
        pad_with_dots(s)
        print "#{s}\n"
      end
    end

    def info_breakpoints(*args)
      return print "\"info breakpoints\" not available here.\n" unless
        @state.context

      return print "No breakpoints.\n" if Byebug.breakpoints.empty?

      brkpts = Byebug.breakpoints.sort_by{|b| b.id}
      unless args.empty?
        indices = args.map{|a| a.to_i}
        brkpts = brkpts.select{|b| indices.member?(b.id)}
        return errmsg "No breakpoints found among list given.\n" if
          brkpts.empty?
      end
      print "Num Enb What\n"
      brkpts.each do |b|
        print "%-3d %-3s at %s:%s%s\n", b.id,
                                        b.enabled? ? 'y' : 'n',
                                        b.source,
                                        b.pos,
                                        b.expr.nil? ? '' : " if #{b.expr}"
        hits = b.hit_count
        if hits > 0
          s = (hits > 1) ? 's' : ''
          print "\tbreakpoint already hit #{hits} time#{s}\n"
        end
      end
    end

    def info_display(*args)
      unless @state.context
        print "info display not available here.\n"
        return
      end
      if @state.display.find{|d| d[0]}
        print "Auto-display expressions now in effect:\n"
        print "Num Enb Expression\n"
        n = 1
        for d in @state.display
          print "%3d: %s  %s\n", n, (d[0] ? 'y' : 'n'), d[1] if
            d[0] != nil
          n += 1
        end
      else
        print "There are no auto-display expressions now.\n"
      end
    end

    def info_file_path(file)
      path = LineCache.path(file)
      if path != file
        print " - #{path}"
      end
    end
    private :info_file_path

    def info_file_lines(file)
      lines = LineCache.size(file)
      print "\t %d lines\n", lines if lines
    end
    private :info_file_lines

    def info_file_breakpoints(file)
      breakpoints = LineCache.trace_line_numbers(file)
      if breakpoints
        print "\tbreakpoint line numbers:\n"
        print columnize(breakpoints.to_a.sort, Command.settings[:width])
      end
    end
    private :info_file_breakpoints

    def info_file_mtime(file)
      stat = LineCache.stat(file)
      print "\t%s\n", stat.mtime if stat
    end
    private :info_file_mtime

    def info_file_sha1(file)
      print "\t%s\n", LineCache.sha1(file)
    end
    private :info_file_sha1

    def info_file(*args)
      return info_files unless args[0]
      file = args[0]

      param =  args[1] ? args[1] : 'basic'

      subcmd = find(InfoFileSubcommands, param)
      return errmsg "Invalid parameter #{param}\n" unless subcmd

      unless LineCache::cached?(file)
        unless LineCache::cached_script?(file)
          return print "File #{file} is not cached\n"
        end
        LineCache::cache(file, Command.settings[:autoreload])
      end

      print "File #{file}"
      info_file_path(file) if %w(all basic path).member?(subcmd.name)
      print "\n"

      info_file_lines(file) if %w(all basic lines).member?(subcmd.name)
      info_file_breakpoints(file) if %w(all breakpoints).member?(subcmd.name)
      info_file_mtime(file) if %w(all mtime).member?(subcmd.name)
      info_file_sha1(file) if %w(all sha1).member?(subcmd.name)
    end

    def info_files(*args)
      files = LineCache::cached_files
      files += SCRIPT_LINES__.keys unless 'stat' == args[0]
      files.uniq.sort.each do |file|
        stat = LineCache::stat(file)
        path = LineCache::path(file)
        print "File %s", file
        if path and path != file
          print " - %s\n", path
        else
          print "\n"
        end
        print "\t%s\n", stat.mtime if stat
      end
    end

    def info_instance_variables(*args)
      unless @state.context
        print "info instance_variables not available here.\n"
        return
      end
      obj = debug_eval('self')
      var_list(obj.instance_variables)
    end

    def info_line(*args)
      unless @state.context
        errmsg "info line not available here.\n"
        return
      end
      print "Line %d of \"%s\"\n",  @state.line, @state.file
    end

    def info_locals(*args)
      unless @state.context
        errmsg "info line not available here.\n"
        return
      end
      locals = @state.context.frame_locals(@state.frame_pos)
      locals.keys.sort.each do |name|
        ### FIXME: make a common routine
        begin
          s = "#{name} = #{locals[name].inspect}"
        rescue
          begin
          s = "#{name} = #{locals[name].to_s}"
          rescue
            s = "*Error in evaluation*"
          end
        end
        pad_with_dots(s)
        print "#{s}\n"
      end
    end

    def info_stop_reason(stop_reason)
      case stop_reason
        when :step
          print "It stopped after stepping, next'ing or initial start.\n"
        when :breakpoint
          print("It stopped at a breakpoint.\n")
        when :catchpoint
          print("It stopped at a catchpoint.\n")
        else
          print "unknown reason: %s\n" % @state.context.stop_reason.to_s
      end
    end
    private :info_stop_reason

    def info_program(*args)
      return print "The program being debugged is not being run.\n" if
        not @state.context

      return print "The program crashed.\n" + Byebug.last_exception ?
                   "Exception: #{Byebug.last_exception.inspect}" : "" + "\n" if
        @state.context.dead?

      print "Program stopped. "
      info_stop_reason @state.context.stop_reason
    end

    def info_stack(*args)
      if not @state.context
        errmsg "info stack not available here.\n"
        return
      end
      print_backtrace
    end

    def info_global_variables(*args)
      unless @state.context
        errmsg "info global_variables not available here.\n"
        return
      end
      var_global
    end

    def info_variables(*args)
      if not @state.context
        errmsg "info variables not available here.\n"
        return
      end
      obj = debug_eval('self')
      locals = @state.context.frame_locals(@state.frame_pos)
      locals[:self] = @state.context.frame_self(@state.frame_pos)
      locals.keys.sort.each do |name|
        next if name =~ /^__dbg_/ # skip byebug pollution
        ### FIXME: make a common routine
        begin
          s = "#{name} = #{locals[name].inspect}"
        rescue
          begin
            s = "#{name} = #{locals[name].to_s}"
          rescue
            s = "#{name} = *Error in evaluation*"
          end
        end
        pad_with_dots(s)
        s.gsub!('%', '%%')  # protect against printf format strings
        print "#{s}\n"
      end
      var_list(obj.instance_variables, obj.instance_eval{binding()})
      var_class_self
    end

    def help(args)
      if args[1]
        subcmd = find(Subcommands, args[1])
        if subcmd
          str = subcmd.short_help + '.'
          if 'file' == subcmd.name and args[2]
            subsubcmd = find(InfoFileSubcommands, args[2])
            if subsubcmd
              str += "\nInvalid \"file\" attribute \"#{args[2]}\"."
            else
              str += "\n" + subsubcmd.short_help + '.'
            end
          else
            str += "\n" + subcmd.long_help if subcmd.long_help
          end
        else
          str = "Invalid \"info\" subcommand \"#{args[1]}\"."
        end
      else
        str = InfoCommand.description + format_subcmds(Subcommands)
      end
      print str
    end

    class << self
      def names
        %w(info)
      end

      def description
        %{
          info[ subcommand]

          Generic command for showing things about the program being
        }
      end
    end
  end

end
