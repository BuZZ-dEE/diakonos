module Diakonos

  class Finding
    include RangeDelegator

    def initialize(range)
      @range = range
    end

    def match( regexps, lines, search_area )
      matches = true

      i = @range.start_row + 1
      regexps[1..-1].each do |re|
        if lines[i] !~ re
          matches = false
          break
        end
        @range.end_row = i
        @range.end_col = Regexp.last_match[0].length
        i += 1
      end

      matches &&
      search_area.contains?( @range.start_row, @range.start_col ) &&
      search_area.contains?( @range.end_row, @range.end_col - 1 )
    end
  end

end
