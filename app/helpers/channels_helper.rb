module ChannelsHelper
  def status_string(status)
    case status
    when 1
      'default'
    when 2
      'warning'
    when 3
      'danger'
    when 4
      'success'
    else
      'primary'
    end
  end

  def taoz_tariffs(level)
    case level
    when 1
      'primary'
    when 2
      'warning'
    when 3
      'danger'
    else
      'default'
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
    return "#{(@channel[:Power]/1000).round(2)} kW" if @period == 'realtime' && @channel[:Power].to_i > 1000
    return "#{@channel[:Power] || "--"} W" if @period == 'realtime'
    return "#{(@channel[:Power]).round(2)} kWh" if (@period == 'month' || @period == 'week') && @channel[:Power].to_i >= 100
    "#{@channel[:Power] || "--"} kWh"
  end

  def fixed_cost_string
    return "עלות בתעריף קבוע: #{(@channel[:fixed]*100).round(2)} אג' לשעה" if (@period == 'realtime' || @period == '60min') && @channel[:fixed].to_f < 0.05
    return "עלות בתעריף קבוע: #{(@channel[:fixed]*100).round(0)} אג' לשעה" if (@period == 'realtime' || @period == '60min') && @channel[:fixed].to_i < 1
    return "עלות בתעריף קבוע: #{@channel[:fixed].round(2) || "0"} ש\"ח לשעה" if @period == 'realtime'

    "עלות כוללת: #{@channel[:fixed] || "0"} ש\"ח"
  end

  def taoz_string
      #return if @channel[:Active] == 0
      return "תעריף נוכחי " 
  end

  def taoz_string2
      #return if @channel[:Active] == 0
      return "תעריף " if (@taoz == 2 || @taoz ==3)
  end

  def taoz_level
    case @taoz 
    when 1
      return "שפל" if @period == 'realtime' ||  @period == '60min'
    when 2
      return "גבע" if @period == 'realtime' ||  @period == '60min'
    when 3
      return "שיא" if @period == 'realtime' ||  @period == '60min'
    end
  end

  def taoz_next_level
    case @taoz 
    when 2
      return "שפל"
    when 3
      return "גבע"
    end
  end

  def taoz_next_time
      return if @taoz == 1
      return " יחל בשעה: #{@taoz_next_level_time.strftime("%H:%M")}" if (@period == 'realtime' ||  @period == '60min') 
  end

 def taoz_expired_time
      return if @taoz == 1
      return " עד השעה: #{@taoz_expired.strftime("%H:%M")}" if (@period == 'realtime' ||  @period == '60min') 
  end
  

  def uptime_string
    return if @channel[:Component] == '' || @channel[:Active] == 0
    case @period
      when 'day'
        return "זמן פעולה: #{@channel[:daily_uptime].round(0)} דקות"  if @channel[:daily_uptime] < 60
        return "זמן פעולה: #{Time.at((@channel[:daily_uptime]-120)*60).strftime("שעה ו- %M דקות")}"  if @channel[:daily_uptime] < 120
        return "זמן פעולה: #{Time.at((@channel[:daily_uptime]-120)*60).strftime("%k שעות ו- %M דקות")}"  
      when 'week'
        return "זמן פעולה: #{@channel[:weekly_uptime].round(0)} דקות"  if @channel[:weekly_uptime] < 60
        return "זמן פעולה: #{Time.at((@channel[:weekly_uptime]-120)*60).strftime("שעה ו- %M דקות")}"  if @channel[:weekly_uptime] < 120
        return "זמן פעולה: #{@channel[:weekly_uptime]/60} שעות ו-#{Time.at(@channel[:weekly_uptime]*60).strftime("%M דקות")}"
      when 'month'
        return "זמן פעולה: #{@channel[:monthly_uptime]} דקות" if @channel[:monthly_uptime] < 60
        return "זמן פעולה: #{Time.at((@channel[:monthly_uptime]-120)*60).strftime("שעה ו- %M דקות")}"  if @channel[:monthly_uptime] < 120
        return "זמן פעולה: #{@channel[:monthly_uptime]/60} שעות ו-#{Time.at(@channel[:monthly_uptime]*60).strftime("%M דקות")}"
    end
  end

  def uptime_cost_string
    return if @channel[:Component] == '' || @channel[:Active] == 0 
    case @period
      when 'day'
        return if @channel[:daily_uptime] == 0
        return "עלות: #{(@channel[:fixed]*100/(@channel[:daily_uptime])*60).round(0)} אג' לשעה" if (@channel[:fixed]/(@channel[:daily_uptime])*60) <1
        return "עלות: #{(@channel[:fixed]/(@channel[:daily_uptime])*60).round(2)} ש\"ח לשעה"
      when 'week'
        return if @channel[:weekly_uptime] == 0
        return "עלות: #{(@channel[:fixed]*100/(@channel[:weekly_uptime])*60).round(0)} אג' לשעה" if (@channel[:fixed]/(@channel[:weekly_uptime])*60) <1
        return "עלות: #{(@channel[:fixed]/(@channel[:weekly_uptime])*60).round(2)} ש\"ח לשעה" 
      when 'month'
        return if @channel[:monthly_uptime] == 0
        return "עלות: #{(@channel[:fixed]*100/(@channel[:monthly_uptime])*60).round(0)} אג' לשעה" if (@channel[:fixed]/(@channel[:monthly_uptime])*60) <1
        return "עלות: #{(@channel[:fixed]/(@channel[:monthly_uptime])*60).round(2)} ש\"ח לשעה" 
    end
  end  

  def load_percent
    #return 50
    return ((@channel[:Power]/220)/@channel[:MaxCurrent])*100
  end

end