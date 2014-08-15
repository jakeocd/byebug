module Byebug
  class ConditionCommand < Command
    self.allow_in_post_mortem = false

    def regexp
      /^\s* cond(?:ition)? (?:\s+(\d+)(?:\s+(.*))?)? \s*$/x
    end

    def execute
      return print ConditionCommand.help(nil) unless @match[1]

      breakpoints = Byebug.breakpoints.sort_by { |b| b.id }
      largest = breakpoints.reduce(0) do |tally, b|
        tally = b.id if b.id > tally
      end

      return errmsg "No breakpoints have been set\n" if 0 == largest
      return unless pos = get_int(@match[1], 'Condition', 1, largest)

      breakpoint = breakpoints.select { |b| b.id == pos }.first

      if syntax_valid?(@match[2])
        breakpoint.expr = @match[2]
      else
        return errmsg "Incorrect expression \"#{@match[2]}\", " \
                      "breakpoint not changed\n"
      end
    end

    class << self
      def names
        %w(condition)
      end

      def description
        %{cond[ition] nnn[ expr]

          Specify breakpoint number nnn to break only if expr is true. nnn is an
          integer and expr is an expression to be evaluated whenever breakpoint
          nnn is reached. If no expression is specified, the condition is
          removed.}
      end
    end
  end
end
