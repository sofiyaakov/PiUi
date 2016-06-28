module ChannelsHelper
  def status_string(status)
    case status
    when 1
      'default'
    when 2
      'danger'
    when 3
      'warning'
    when 4
      'success'
    else
      'primary'
    end
  end

  def status_text(status)
    case status
    when 1
      'לא מוגדר'
    when 2
      'משדר ולא פעיל'
    when 3
      'מוגדר אך לא משדר'
    when 4
      'משדר'
    else
      'שגיאה לא ידועה'
    end
  end

  def power_string
    return "#{@channel[:Power]/1000} KW" if @period == 'realtime' && @channel[:Power].to_i > 1000
    return "#{@channel[:Power] || "--"} W" if @period == 'realtime'
    "#{@channel[:Power] || "--"} KWh"
  end
end