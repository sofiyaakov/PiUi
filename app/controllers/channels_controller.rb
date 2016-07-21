class ChannelsController < ActionController::Base
	layout 'application'
  before_action :get_data, :get_channel
  helper :channels

  def show
    @period = params['period'] || 'realtime'
    @channels_data = $dbclient.query(power_query).first(16)
    @channel[:Power] = @channels_data.find {|ch| ch['Channel'] == @channel[:Channel]}.try(:[],'Power')
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
    redirect_to action: :edit, id: params[:id]
  end

  private

  def channel_params
    params.permit(:Transmitter, :ManualVoltage, :ChannelMaster, :Category, :Component, :Name, :MaxCurrent, :Active, :CloudRT)
  end

  def get_data
    @settings = $dbclient.query('select * from Channels_S order by Channel').first(16) # I'm assuming there are at least 16 channels
    @channels_not_active = $dbclient.query('Select Channel from ChannelsNotActive where unix_timestamp()-unix_timestamp(Time)<10 order by Channel').first(16)
    @channels_active = $dbclient.query('select Channel from RT where STS_Sync = 0 and unix_timestamp()-unix_timestamp(Time)<12 group by Channel order by Channel').first(16)

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
      'select Channel,Power from RT where STS_Sync = 0 and unix_timestamp()-unix_timestamp(Time)<12  group by Channel order by ID desc'
      #'select Channel,Power from RT where STS_Sync = 0 and unix_timestamp()-unix_timestamp(Time)<10 group by Channel order by Channel'

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
end
