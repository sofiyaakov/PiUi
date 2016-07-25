module ChannelsHelper
  def status_string(status)
    case status
    when 1
      'default'
    when 2
      #'danger'
      'warning'
    when 3
      #'warning'
      'danger'
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
    return "#{(@channel[:Power]/1000).round(3)} kW" if @period == 'realtime' && @channel[:Power].to_i > 1000
    return "#{@channel[:Power] || "--"} W" if @period == 'realtime'
    "#{@channel[:Power] || "--"} kWh"
  end

  def fixed_cost_string
    return "עלות: #{(@channel[:fixed]*100).round(0)} אג' לשעה" if (@period == 'realtime' || @period == '60min') && @channel[:fixed].to_i < 1
    return "עלות: #{@channel[:fixed] || "0"} ש\"ח לשעה" if @period == 'realtime'
    "עלות: #{@channel[:fixed] || "0"} ש\"ח"
  end

def taoz_string
    return "TAOZ data" if @period == 'realtime' ||  @period == '60min'
  end
end