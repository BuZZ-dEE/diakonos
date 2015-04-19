module Diakonos

  class Buffer

    # @mark_start[ "col" ] is inclusive,
    # @mark_end[ "col" ] is exclusive.
    def record_mark_start_and_end
      if @mark_anchor.nil?
        @text_marks[ :selection ] = nil
        return
      end

      crow = @last_row
      ccol = @last_col
      arow = @mark_anchor[ 'row' ]
      acol = @mark_anchor[ 'col' ]

      case @selection_mode
      when :normal
        anchor_first = true

        if crow < arow
          anchor_first = false
        elsif crow > arow
          anchor_first = true
        else
          if ccol < acol
            anchor_first = false
          end
        end

        if anchor_first
          @text_marks[ :selection ] = TextMark.new( ::Diakonos::Range.new(arow, acol, crow, ccol), @selection_formatting )
        else
          @text_marks[ :selection ] = TextMark.new( ::Diakonos::Range.new(crow, ccol, arow, acol), @selection_formatting )
        end
      when :block
        if crow < arow
          if ccol < acol # Northwest
            @text_marks[ :selection ] = TextMark.new( ::Diakonos::Range.new(crow, ccol, arow, acol), @selection_formatting )
          else           # Northeast
            @text_marks[ :selection ] = TextMark.new( ::Diakonos::Range.new(crow, acol, arow, ccol), @selection_formatting )
          end
        else
          if ccol < acol  # Southwest
            @text_marks[ :selection ] = TextMark.new( ::Diakonos::Range.new(arow, ccol, crow, acol), @selection_formatting )
          else            # Southeast
            @text_marks[ :selection ] = TextMark.new( ::Diakonos::Range.new(arow, acol, crow, ccol), @selection_formatting )
          end
        end
      end
    end

    def selection_mark
      @text_marks[:selection]
    end

    def selecting?
      !! selection_mark
    end

    def select_current_line
      selection_mode_normal
      anchor_selection( @last_row, 0, DONT_DISPLAY )
      if @last_row == @lines.size - 1
        row = @last_row
        col = @lines[ @last_row ].size
      else
        row = @last_row + 1
        col = 0
      end
      cursor_to( row, col, DO_DISPLAY )
    end

    def set_selection_current_line
      @text_marks[ :selection ] = TextMark.new(
        ::Diakonos::Range.new(@last_row, 0, @last_row, @lines[ @last_row ].size),
        @selection_formatting
      )
      @lines[ @last_row ]
    end

    def select_all
      selection_mode_normal
      anchor_selection( 0, 0, DONT_DISPLAY )
      cursor_to( @lines.length - 1, @lines[ -1 ].length, DO_DISPLAY )
    end

    def select_wrapping_block
      block_level = indentation_level( @last_row )
      if selecting?
        block_level -= 1
      end
      if block_level <= 0
        return select_all
      end

      end_row = start_row = @last_row

      # Find block end
      ( @last_row...@lines.size ).each do |row|
        next  if @lines[ row ].strip.empty?
        if indentation_level( row ) < block_level
          end_row = row
          break
        end
      end

      # Go to block beginning
      ( 0...@last_row ).reverse_each do |row|
        next  if @lines[ row ].strip.empty?
        if indentation_level( row ) < block_level
          start_row = row + 1
          break
        end
      end

      anchor_selection( end_row, 0 )
      cursor_to( start_row, 0, DO_DISPLAY )
    end

    def select_word
      coords = word_under_cursor_pos( or_after: true )
      if coords.nil?
        remove_selection
      else
        cursor_to *coords[0]
        anchor_selection
        cursor_to *coords[1]
        display
      end
    end

    def select_word_another
      m = selection_mark
      if m.nil?
        select_word
      else
        row, col, _ = pos_of_next( /\w\b/, @last_row, @last_col )
        if row && col
          cursor_to row, col+1, DO_DISPLAY
        end
      end
    end

    def select( from_regexp, to_regexp, include_ending = true )
      start_row = nil

      @lines[ 0..@last_row ].reverse.each_with_index do |line,index|
        if line =~ from_regexp
          start_row = @last_row - index
          break
        end
      end
      if start_row
        end_row = nil
        @lines[ start_row..-1 ].each_with_index do |line,index|
          if line =~ to_regexp
            end_row = start_row + index
            break
          end
        end
        if end_row
          if include_ending
            end_row += 1
          end
          anchor_selection( start_row, 0, DONT_DISPLAY )
          cursor_to( end_row, 0 )
          display
        end
      end
    end

    def set_selection( start_row, start_col, end_row, end_col )
      @text_marks[ :selection ] = TextMark.new( ::Diakonos::Range.new(start_row, start_col, end_row, end_col), @selection_formatting )
      @changing_selection = false
    end

    def anchor_selection( row = @last_row, col = @last_col, do_display = DO_DISPLAY )
      @mark_anchor = ( @mark_anchor || Hash.new )
      @mark_anchor[ "row" ] = row
      @mark_anchor[ "col" ] = col
      record_mark_start_and_end
      @changing_selection = true
      @auto_anchored = false
      display  if do_display
    end

    def anchor_unanchored_selection(*args)
      if @mark_anchor.nil?
        anchor_selection *args
        @changing_selection = false
      end
      @auto_anchored = true
    end

    def remove_selection( do_display = DO_DISPLAY )
      return  if selection_mark.nil?
      @mark_anchor = nil
      record_mark_start_and_end
      @changing_selection = false
      @last_finding = nil
      display  if do_display
    end

    def toggle_selection
      if @changing_selection
        remove_selection
      else
        anchor_selection
      end
    end

    def copy_selection
      selected_text
    end

    # @return [Array<String>, nil]
    def selected_text
      selection = selection_mark
      if selection.nil?
        nil
      elsif selection.start_row == selection.end_row
        [ @lines[ selection.start_row ][ selection.start_col...selection.end_col ] ]
      else
        if @selection_mode == :block
          @lines[ selection.start_row .. selection.end_row ].collect { |line|
            line[ selection.start_col ... selection.end_col ]
          }
        else
          [ @lines[ selection.start_row ][ selection.start_col..-1 ] ] +
            ( @lines[ (selection.start_row + 1) .. (selection.end_row - 1) ] || [] ) +
            [ @lines[ selection.end_row ][ 0...selection.end_col ] ]
        end
      end
    end

    def selected_string
      lines = selected_text
      if lines
        lines.join( "\n" )
      else
        nil
      end
    end

    def selected_lines
      selection = selection_mark
      if selection
        if selection.end_col == 0
          end_row = selection.end_row - 1
        else
          end_row = selection.end_row
        end
        @lines[ selection.start_row..end_row ]
      else
        [ @lines[ @last_row ] ]
      end
    end

    def selection_mode_block
      @selection_mode = :block
    end
    def selection_mode_normal
      @selection_mode = :normal
    end

    def delete_selection( do_display = DO_DISPLAY )
      return  if @text_marks[ :selection ].nil?

      take_snapshot

      selection  = @text_marks[ :selection ]
      start_row  = selection.start_row
      start_col  = selection.start_col
      end_row    = selection.end_row
      end_col    = selection.end_col
      start_line = @lines[ start_row ]

      if end_row == selection.start_row
        @lines[ start_row ] = start_line[ 0...start_col ] + start_line[ end_col..-1 ]
      else
        case @selection_mode
        when :normal
          end_line = @lines[ end_row ]
          @lines[ start_row ] = start_line[ 0...start_col ] + end_line[ end_col..-1 ]
          @lines = @lines[ 0..start_row ] + @lines[ (end_row + 1)..-1 ]
        when :block
          @lines[ start_row..end_row ] = @lines[ start_row..end_row ].collect { |line|
            line[ 0...start_col ] + ( line[ end_col..-1 ] || '' )
          }
        end
      end

      cursor_to start_row, start_col
      remove_selection DONT_DISPLAY
      set_modified do_display
    end

    # text is an array of Strings, or a String with zero or more newlines ("\n")
    def paste( text, typing = ! TYPING, do_parsed_indent = false )
      return  if text.nil?

      if ! text.kind_of?(Array)
        s = text.to_s
        if s.include?( "\n" )
          text = s.split( "\n", -1 )
        else
          text = [ s ]
        end
      end

      take_snapshot typing

      delete_selection DONT_DISPLAY

      row = @last_row
      col = @last_col
      new_col = nil
      line = @lines[ row ]
      if text.length == 1
        @lines[ row ] = line[ 0...col ] + text[ 0 ] + line[ col..-1 ]
        if do_parsed_indent
          parsed_indent  row: row, do_display: false
        end
        cursor_to( @last_row, @last_col + text[ 0 ].length, DONT_DISPLAY, ! typing )
      elsif text.length > 1

        case @selection_mode
        when :normal
          @lines[ row ] = line[ 0...col ] + text[ 0 ]
          @lines[ row + 1, 0 ] = text[ -1 ] + line[ col..-1 ]
          @lines[ row + 1, 0 ] = text[ 1..-2 ]
          new_col = column_of( text[ -1 ].length )
        when :block
          @lines += [ '' ] * [ 0, ( row + text.length - @lines.length ) ].max
          @lines[ row...( row + text.length ) ] = @lines[ row...( row + text.length ) ].collect.with_index { |line,index|
            pre = line[ 0...col ].ljust( col )
            post = line[ col..-1 ]
            "#{pre}#{text[ index ]}#{post}"
          }
          new_col = col + text[ -1 ].length
        end

        new_row = @last_row + text.length - 1
        if do_parsed_indent
          ( row..new_row ).each do |r|
            parsed_indent  row: r, do_display: false
          end
        end
        cursor_to( new_row, new_col )

      end

      set_modified
    end

  end

end
