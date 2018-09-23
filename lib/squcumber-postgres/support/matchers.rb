module MatcherHelpers
  def values_match(actual, expected)
    if expected.eql?('today')
      actual.match(/#{Regexp.quote(Date.today.to_s)}/)
    elsif expected.eql?('yesterday')
      actual.match(/#{Regexp.quote((Date.today - 1).to_s)}/)
    elsif expected.eql?('any_date')
      actual.match(/^\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2}$/)
    elsif expected.eql?('any_string')
      true if actual.is_a?(String) or actual.nil?
    elsif expected.eql?('false') or expected.eql?('true')
      true if actual.eql?(expected[0])
    elsif !expected.nil?
      actual ||= ''
      actual.eql?(expected)
    else  # we have not mocked this, so ignore it
      true
    end
  end

  def timetravel(date, i, method); i > 0 ? timetravel(date.send(method.to_sym), i - 1, method) : date; end

  def convert_mock_values(mock_data)
    mock_data.map do |entry|
      entry.each do |key, value|
        # Examples of valid values; all examples assume that today is 30th July 2017
        #
        #    1 month ago
        #    => '2017-06-30'
        #
        #    40 days ago (as month)
        #    => '6'
        #
        #    2 years ago (as year)
        #    => '2015'
        #
        #    beginning of last month
        #    => '2017-06-01'
        #
        #    end of last year
        #    => '2016-12-31'
        #
        #    today (as custom '%Y-%m')
        #    => '2017-07'
        #
        entry[key] = convert_mock_value(value)
      end
    end
  end

  def convert_mock_value(value)
    value_parser_regexp = /\s*((?<modifier>(beginning|end))\s+of\s+(?<modifier_base>day|month|year))?\s*(?<placeholder>[^\(\)]+)\s*(\(as (?<format>day|month|year|(custom '[^']+'))\))?\s*/

    parsed_value = value.match(value_parser_regexp)
    placeholder = parsed_value[:placeholder]
    format = parsed_value[:format]
    modifier = parsed_value[:modifier]
    modifier_base = parsed_value[:modifier_base]

    new_value = case placeholder
      when /today/
        Date.today
      when /yesterday/
        timetravel(Date.today, 1, :prev_day)
      when /tomorrow/
        timetravel(Date.today, 1, :next_day)
      when /last month/
        timetravel(Date.today, 1, :prev_month)
      when /next month/
        timetravel(Date.today, 1, :next_month)
      when /last year/
        timetravel(Date.today, 1, :prev_year)
      when /next year/
        timetravel(Date.today, 1, :next_year)
      when /\s*\d+\s+month(s)?\s+ago\s*?/
        number_of_months = value.match(/\d+/)[0].to_i
        timetravel(Date.today, number_of_months, :prev_month)
      when /\s*\d+\s+day(s)?\s+ago\s*/
        number_of_days = value.match(/\d+/)[0].to_i
        timetravel(Date.today, number_of_days, :prev_day)
      when /\s*\d+\s+year(s)?\s+ago\s*/
        number_of_years = value.match(/\d+/)[0].to_i
        timetravel(Date.today, number_of_years, :prev_year)
      when /\s*\d+\s+month(s)?\s+from now\s*?/
        number_of_months = value.match(/\d+/)[0].to_i
        timetravel(Date.today, number_of_months, :next_month)
      when /\s*\d+\s+day(s)?\s+from now\s*/
        number_of_days = value.match(/\d+/)[0].to_i
        timetravel(Date.today, number_of_days, :next_day)
      when /\s*\d+\s+year(s)?\s+from now\s*/
        number_of_years = value.match(/\d+/)[0].to_i
        timetravel(Date.today, number_of_years, :next_year)
      else
        placeholder
    end

    if new_value.is_a?(Date)
      modified_new_value = case modifier
        when nil
          new_value
        when 'beginning'
          case modifier_base
            when 'day'
              new_value
            when 'month'
              Date.new(new_value.year, new_value.month, 1)
            when 'year'
              Date.new(new_value.year, 1, 1)
            else
              raise "Invalid date modifier provided: #{modifier} #{modifier_base}"
          end
        when 'end'
          case modifier_base
            when 'day'
              new_value
            when 'month'
              Date.new(new_value.next_month.year, new_value.next_month.month, 1).prev_day
            when 'year'
              Date.new(new_value.next_year.year, 1, 1).prev_day
            else
              raise "Invalid date modifier provided: #{modifier} #{modifier_base}"
          end
        else
          raise "Invalid date modifier provided: #{modifier} #{modifier_base}"
      end

      formatted_new_value = case format
        when nil
          puts "NO FORMAT"
          modified_new_value.to_s
        when 'day', 'month', 'year'
          modified_new_value.send(format.to_sym)
        when /custom '[^']+'/
          parsed_format = format.match(/custom '(?<format_string>[^']+)'/)
          modified_new_value.strftime(parsed_format[:format_string])
        else
          raise "Invalid date format provided: #{format}"
      end

      formatted_new_value
    else
      new_value
    end
  end
end

if defined?(World)
  World(MatcherHelpers)
end
