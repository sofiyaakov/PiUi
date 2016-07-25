class ChannelsController < ActionController::Base
	layout 'application'
  before_action :get_data, :get_channel
  helper :channels

  def show
    @period = params['period'] || 'realtime'
    @channels_data = $dbclient.query(power_query).first(16)
    @channel[:Power] = @channels_data.find {|ch| ch['Channel'] == @channel[:Channel]}.try(:[],'Power')
    @cost_data = $dbclient.query(cost_query).first(16)
    @channel[:fixed] = @cost_data.find {|ch| ch['Channel'] == @channel[:Channel]}.try(:[],'Cost')
    @taoz_data = $dbclient.query(taoz_query)
    #@taoz = @taoz_data.find
    render :channel
  end

  def edit
    @components = $dbclient.query('select Component from Components').map {|c| c["Component"]}
    @categories = $dbclient.query('select Category from Categories').map {|c| c["Category"]}
    query = <<-END_SQL
    select Transmitter,
    if (FLOOR(HOUR(TIMEDIFF(current_timestamp,Time))/24) >0,
    CONCAT('נראה לפני ',FLOOR(HOUR(TIMEDIFF(current_timestamp,Time))/24),' ימים'),
    if (MOD(HOUR(TIMEDIFF(current_timestamp,Time)),24)>0,
    CONCAT('נראה לפני ',MOD(HOUR(TIMEDIFF(current_timestamp,Time)),24),' שעות'),
    if (MINUTE(TIMEDIFF(current_timestamp,Time))>0,
    CONCAT('נראה לפני ',MINUTE(TIMEDIFF(current_timestamp,Time)),' דקות'),
    CONCAT('נראה לפני ',SECOND(TIMEDIFF(current_timestamp,Time)),' שניות')))) as 'last seen'
    from TransmittersNotExist
    where Transmitter > 999
    and transmitter NOT IN (Select Transmitter from Channels_S where Transmitter is not null)
    and FLOOR(HOUR(TIMEDIFF(current_timestamp,Time))/24) <32
    order by Time desc;
    END_SQL
    @transmitters = $dbclient.query(query)
    render :channel
  end

  def update
    $dbclient.query("UPDATE Channels_S SET #{channel_params.map{|k,v| "#{k}='#{v}'"}.join(', ')} where Channel = #{params[:id]}")
    $dbclient.query("REPLACE into Categories (Category) (select Category from Channels_S where Category is not null and not category=\"\" and Category not in (Select Category from Categories) group by Category)")
    $dbclient.query("REPLACE into Components (Component) (select Component from Channels_S where Component is not null and not component=\"\" and Component not in (Select Component from Components) group by Component)")
    redirect_to action: :edit, id: params[:id]
  end

  private

  def channel_params
    params.permit(:Transmitter, :ManualVoltage, :ChannelMaster, :Category, :Component, :Name, :MaxCurrent, :Active, :CloudRT)
  end

  def get_data
    @settings = $dbclient.query('select * from Channels_S order by Channel').first(16) # I'm assuming there are at least 16 channels
    @channels_not_active = $dbclient.query('Select Channel from ChannelsNotActive where unix_timestamp()-unix_timestamp(Time)<10 order by Channel').first(16)
    @channels_active = $dbclient.query('select Channel from (select * from RT where STS_Sync = 0 and unix_timestamp()-unix_timestamp(Time)<12  order by ID desc)a group by Channel').first(16)

    @channels = @settings.map(&:symbolize_keys)
    @channels_not_active.each {|na| @channels[na["Channel"] - 1][:Status] = 2 }
    @channels_active.each {|ac| @channels[ac["Channel"] - 1][:Status] = 4 }
    @channels = @channels.each do |ch|
      ch[:Status] ||= ch[:Transmitter] && ch[:Active] == 1 ? 3 : 1
    end
  end

  def get_channel
    channel_id = (params[:id] || 1).to_i - 1
    @channel = @channels[channel_id]
  end

  def power_query
    case @period
    when 'realtime'
      'select Channel,Power from (select * from RT where STS_Sync = 0 and unix_timestamp()-unix_timestamp(Time)<13  order by ID desc)a group by Channel'
    when '60min'
      'Select tab1.Channel, round(tab1.Power+tab2.Power,3) as Power from (Select Channel,sum(Power)/600/1000 as Power from RT where STS_Sync = 0 group by Channel) tab1, (Select Channel,sum(Power)/60/1000 as Power from STS where ID >=(select min(id) from STS where  ID > (Select max(ID)-5000 from STS) and Time>= current_timestamp()-6000) group by Channel) tab2 where tab1.Channel=tab2.Channel;'
    when 'day'
      #'select Channel,round(sum(power)/1000/60,3) `Power` from STS where ID>=(select min(id) from STS where time >= current_date) group by Channel'
      'Select tab1.Channel, round(tab1.Power+tab2.Power,3) as Power from (Select Channel,sum(Power)/600/1000 as Power from RT where STS_Sync = 0 group by Channel) tab1, (Select Channel,sum(Power)/60/1000 as Power from STS where ID >=(select min(id) from STS where time >= current_date) group by Channel) tab2 where tab1.Channel=tab2.Channel'
    when 'week'
      #'select Channel,round(sum(power)/1000/60,2) `Power` from STS where ID>=(select min(id) from STS where yearweek(time) = yearweek(curdate(),0)) group by Channel'
      'Select tab1.Channel, round(tab0.Weekly+tab1.Power+tab2.Power,3) as Power from (Select Channel,Weekly from CumuConsumption) tab0, (Select Channel,sum(Power)/600/1000 as Power from RT where STS_Sync = 0 group by Channel) tab1, (Select Channel,sum(Power)/60/1000 as Power from STS where ID >=(select min(id) from STS where time >= current_date) group by Channel) tab2 where tab0.Channel=tab1.Channel and tab1.Channel=tab2.Channel'
    when 'month'
      #'select Channel,round(sum(power)/1000/60,2) `Power` from STS where ID>=(select min(id) from STS where month(time) = month(now())) group by Channel'
      'Select tab1.Channel, round(tab0.Monthly+tab1.Power+tab2.Power,3) as Power from (Select Channel,Monthly from CumuConsumption) tab0, (Select Channel,sum(Power)/600/1000 as Power from RT where STS_Sync = 0 group by Channel) tab1, (Select Channel,sum(Power)/60/1000 as Power from STS where ID >=(select min(id) from STS where time >= current_date) group by Channel) tab2 where tab0.Channel=tab1.Channel and tab1.Channel=tab2.Channel'
    end
  end

  def cost_query
    case @period
    when 'realtime'
      'select Channel,round(avg(power)*(select fixed from ElecTariffs where Type = "Fixed" and curdate() BETWEEN fromDate and toDate)/1000/100,2) as Cost from RT where ID > (select min(ID) from RT where ID >= (select max(ID)-500 from RT) and current_timestamp()-Time <=20) group by Channel'
      when '60min'
      'Select tab1.Channel, round(tab1.Power+tab2.Power,2) as Cost from (Select Channel,sum(Power*(select fixed from ElecTariffs where Type = "Fixed" and curdate() BETWEEN fromDate and toDate))/600/1000/100 as Power from RT where STS_Sync = 0 group by Channel) tab1, (Select Channel,sum(Power*Fixed)/60/1000/100 as Power from STS where ID >=(select min(id) from STS where ID > (select max(ID)-5000 from STS) and time >= current_timestamp()-6000) group by Channel) tab2 where tab1.Channel=tab2.Channel'
    when 'day'
      'Select tab1.Channel, round(tab1.Power+tab2.Power,2) as Cost from (Select Channel,sum(Power*(select fixed from ElecTariffs where Type = "Fixed" and curdate() BETWEEN fromDate and toDate))/600/1000/100 as Power from RT where STS_Sync = 0 group by Channel) tab1, (Select Channel,sum(Power*Fixed)/60/1000/100 as Power from STS where ID >=(select min(id) from STS where time >= current_date) group by Channel) tab2 where tab1.Channel=tab2.Channel'
    when 'week'
      'Select tab1.Channel, round(tab0.WeeklyFixedCost+tab1.Cost+tab2.Cost,2) as Cost from (Select Channel,WeeklyFixedCost from CumuConsumption) tab0, (Select Channel,sum(Power*(select fixed from ElecTariffs where Type = "Fixed" and curdate() BETWEEN fromDate and toDate))/600/1000/100 as Cost from RT where STS_Sync = 0 group by Channel) tab1, (Select Channel,sum(Power*Fixed)/60/1000/100 as Cost from STS where ID >=(select min(id) from STS where time >= current_date) group by Channel) tab2 where tab0.Channel=tab1.Channel and tab1.Channel=tab2.Channel;'
    when 'month'
      'Select tab1.Channel, round(tab0.MonthlyFixedCost+tab1.Cost+tab2.Cost,2) as Cost from (Select Channel,MonthlyFixedCost from CumuConsumption) tab0, (Select Channel,sum(Power*(select fixed from ElecTariffs where Type = "Fixed" and curdate() BETWEEN fromDate and toDate))/600/1000/100 as Cost from RT where STS_Sync = 0 group by Channel) tab1, (Select Channel,sum(Power*Fixed)/60/1000/100 as Cost from STS where ID >=(select min(id) from STS where time >= current_date) group by Channel) tab2 where tab0.Channel=tab1.Channel and tab1.Channel=tab2.Channel;'
    end
  end

def taoz_query
  <<-END_SQL
  select Level from ClustersTAOZ where 
  month(now()) between fromMonth and toMonth and 
  dayofweek(now()) between fromDay and toDay and 
  hour(now()) >= fromHour and hour(now()) < toHour;
  END_SQL

 # select Level from ClustersTAOZ where 
 # month(now()) between fromMonth and toMonth and 
 # dayofweek(now()) between fromDay and toDay and 
  #hour(now()) >= fromHour and hour(now()) < toHour;
 # END_SQL
end
end
