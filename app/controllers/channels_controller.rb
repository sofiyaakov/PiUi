class ChannelsController < ApplicationController
	layout 'application'
  before_action :get_data, :get_channel
  helper :channels, :application

  def show
    @period = params['period'] || 'realtime'

    @channels_data = $dbclient.query(power_query).first(16)
    @channel[:Power] = @channels_data.find {|ch| ch['Channel'] == @channel[:Channel]}.try(:[],'Power') 
    @cost_data = $dbclient.query(cost_query).first(16)
    @channel[:fixed] = @cost_data.find {|ch| ch['Channel'] == @channel[:Channel]}.try(:[],'Cost') || 0
    @taoz = $dbclient.query(taoz_query).first['nLevel']
    @taoz_expired = $dbclient.query(taoz_query).first['Time']
    @taoz_next_level_time = $dbclient.query(taoz_next_level_query).first['Time']

		
		if ['day', 'week', 'month'].include? @period

      if @channel[:Component] != ''
        @uptime_data_cumu = $dbclient.query(uptime_query_cumu)
        @uptime_data_sts = $dbclient.query(uptime_query_sts)
        # @uptime_data_foo = $dbclient.query(uptime_query_foo)

        @uptime_data_cumu.each do |channel|
          uptime = @uptime_data_sts.find {|c| c["Channel"] == channel["Channel"]}.try(:[],"Uptime")
          # uptime2 = @uptime_data_foo.find {|c| c["Channel"] == channel["Channel"]}.try(:[],"Uptime44")
          # uptime && ["DailyUptime", "WeeklyUptime", "MonthlyUptime"].each { |term| channel[term] += uptime + uptime2 }
          uptime && ["DailyUptime", "WeeklyUptime", "MonthlyUptime"].each { |term| channel[term] += uptime }
          # uptime && channel["DailyUptime"] += uptime // single change
          @channel[:daily_uptime] =    @uptime_data_cumu.find {|ch| ch['Channel'] == @channel[:Channel]}.try(:[],'DailyUptime'   ) || 0
          @channel[:weekly_uptime] =   @uptime_data_cumu.find {|ch| ch['Channel'] == @channel[:Channel]}.try(:[],'WeeklyUptime'  ) || 0
          @channel[:monthly_uptime] =  @uptime_data_cumu.find {|ch| ch['Channel'] == @channel[:Channel]}.try(:[],'MonthlyUptime' ) || 0
        end
      end

      @taoz_cost_data = $dbclient.query(taoz_cost_query).first(16)
      @channel[:taoz] = @taoz_cost_data.find {|ch| ch['Channel'] == @channel[:Channel]}.try(:[],'Cost') || 0
      @split_factor = $dbclient.query(split_factor_query).first['Ratio']
      taoz_split_data = $dbclient.query(taoz_split_query).first(3) 
      @taoz_split_low = taoz_split_data.find {|setting| setting['TAOZ_Level'] == 1}['Cost'] * 100 
      @taoz_split_hill = taoz_split_data.find {|setting| setting['TAOZ_Level'] == 2}['Cost'] * 100 
      @taoz_split_peak = taoz_split_data.find {|setting| setting['TAOZ_Level'] == 3}['Cost'] * 100 

      if @channel[:ChannelMaster] == 0 
  			norm_query_result = $dbclient.query(norm_query)
  			key = if @period == 'day'
  				'DailySocialConsumption'
  			elsif @period == 'week'
  				'WeeklySocialConsumption'
  			else
  				'MonthlySocialConsumption'
  			end
  			@channel[:normRatio] = (@channel[:Power]*100/norm_query_result.first[key]).round(1)
      end
		end
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
    order by Time desc,Transmitter;
    END_SQL
    @transmitters = $dbclient.query(query)
    render :channel
  end

  def update
    $dbclient.query("UPDATE Channels_S SET #{channel_params.map{|k,v| v == 'NULL' ? "#{k} = NULL" : "#{k}='#{v}'"}.join(', ')} where Channel = #{params[:id]}")
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
    @channel_id = (params[:id] || 1).to_i - 1
    @channel = @channels[@channel_id]
  end

  def power_query
    case @period
    when 'realtime'
      'select Channel,Power from (select * from RT where STS_Sync = 0 and unix_timestamp()-unix_timestamp(Time)<13  order by ID desc)a group by Channel'
    when '60min'
      'select tab0.Channel,round(sum(tab0.Power),3) as Power from
        ((Select Channel,sum(Power)/600/1000 as Power from RT where STS_Sync = 0 group by Channel)
        UNION
        (Select Channel,sum(Power)/60/1000 as Power from STS where ID >=(select min(id) from STS where  ID > (Select max(ID)-5000 from STS) and unix_timestamp()-unix_timestamp(Time)<=3600) group by Channel))tab0
      group by tab0.Channel'
    when 'day'
      'select tab0.Channel,round(sum(tab0.Power),3) as Power from
        ((Select Channel,sum(Daily) as Power from CumuConsumption_new group by Channel)
        UNION
        (Select Channel,sum(Power)/600/1000 as Power from RT where STS_Sync = 0 group by Channel)
        UNION
        (Select Channel,sum(Power)/60/1000 as Power from STS where ID > (select Value from GenSettings where Indx= "LastSTSidCumuConsump") group by Channel))tab0
      group by tab0.Channel'
    when 'week'
      'select tab0.Channel,round(sum(tab0.Power),3) as Power from
        ((Select Channel,sum(Weekly) as Power from CumuConsumption_new group by Channel)
        UNION
        (Select Channel,sum(Power)/600/1000 as Power from RT where STS_Sync = 0 group by Channel)
        UNION
        (Select Channel,sum(Power)/60/1000 as Power from STS where ID > (select Value from GenSettings where Indx= "LastSTSidCumuConsump") group by Channel))tab0
      group by tab0.Channel'
    when 'month'
      'select tab0.Channel,round(sum(tab0.Power),3) as Power from
        ((Select Channel,sum(Monthly) as Power from CumuConsumption_new group by Channel)
        UNION
        (Select Channel,sum(Power)/600/1000 as Power from RT where STS_Sync = 0 group by Channel)
        UNION
        (Select Channel,sum(Power)/60/1000 as Power from STS where ID > (select Value from GenSettings where Indx= "LastSTSidCumuConsump") group by Channel))tab0
      group by tab0.Channel'
    end
  end

  def cost_query
    case @period
    when 'realtime'
      'select Channel,round(avg(power)*
      (select fixed from ElecTariffs where Type = "Fixed" and curdate() BETWEEN fromDate and toDate)/1000/100,4) as Cost
      from RT where ID > (select min(ID) from RT where ID >= (select max(ID)-500 from RT) and unix_timestamp()-unix_timestamp(Time)<=20)
      group by Channel'

      when '60min'
        'Select tab0.Channel, round(sum(tab0.Cost),2) as Cost from
          ((Select Channel,sum(Power*(select fixed from ElecTariffs where Type = "Fixed" and curdate() BETWEEN fromDate and toDate))/600/1000/100 as Cost from RT where STS_Sync = 0 group by Channel)
          UNION
          (Select Channel,sum(Power*Fixed)/60/1000/100 as Cost from STS where ID >=(select min(id) from STS where ID > (select max(ID)-5000 from STS) and unix_timestamp()-unix_timestamp(Time)<=3600) group by Channel))tab0
        group by tab0.Channel'

    when 'day'
      'Select tab0.Channel, round(sum(tab0.Cost),2) as Cost from
        ((Select Channel,sum(DailyFixedCost) as Cost from CumuConsumption_new group by Channel)
        UNION
        (Select Channel,sum(Power*(select fixed from ElecTariffs where Type = "Fixed" and curdate() BETWEEN fromDate and toDate))/600/1000/100 as Cost from RT where STS_Sync = 0 group by Channel)
        UNION
        (Select Channel,sum(Power*Fixed)/60/1000/100 as Cost from STS where ID >(select Value from GenSettings where Indx= "LastSTSidCumuConsump") group by Channel))tab0
      group by tab0.Channel'


    when 'week'
      'Select tab0.Channel, round(sum(tab0.Cost),2) as Cost from
        ((Select Channel,sum(WeeklyFixedCost) as Cost from CumuConsumption_new group by Channel)
        UNION
        (Select Channel,sum(Power*(select fixed from ElecTariffs where Type = "Fixed" and curdate() BETWEEN fromDate and toDate))/600/1000/100 as Cost from RT where STS_Sync = 0 group by Channel)
        UNION
        (Select Channel,sum(Power*Fixed)/60/1000/100 as Cost from STS where ID >(select Value from GenSettings where Indx= "LastSTSidCumuConsump") group by Channel))tab0
      group by tab0.Channel'


    when 'month'
      'Select tab0.Channel, round(sum(tab0.Cost),2) as Cost from
        ((Select Channel,sum(MonthlyFixedCost) as Cost from CumuConsumption_new group by Channel)
        UNION
        (Select Channel,sum(Power*(select fixed from ElecTariffs where Type = "Fixed" and curdate() BETWEEN fromDate and toDate))/600/1000/100 as Cost from RT where STS_Sync = 0 group by Channel)
        UNION
        (Select Channel,sum(Power*Fixed)/60/1000/100 as Cost from STS where ID >(select Value from GenSettings where Indx= "LastSTSidCumuConsump") group by Channel))tab0
      group by tab0.Channel'
    end
  end

  def taoz_query
    'select nLevel,maketime(toHour,0,0) as Time from ClustersTAOZ where
    month(now()) between fromMonth and toMonth and
    dayofweek(now()) between fromDay and toDay and
    hour(now()) >= fromHour and hour(now()) < toHour;'
  end

  def taoz_next_level_query
    'select maketime(H,0,0) as Time from
    (select Level, min(fromHour) as H from ClustersTAOZ where
    month(now()) between fromMonth and toMonth and
    dayofweek(now()) between fromDay and toDay and
    fromHour > hour(now()) and nLevel <
    (select nLevel from ClustersTAOZ where
    month(now()) between fromMonth and toMonth and
    dayofweek(now()) between fromDay and toDay and
    hour(now()) >= fromHour and hour(now()) < toHour))a'
  end

def taoz_cost_query
    case @period

    when 'day'
    'Select tab0.Channel, round(sum(tab0.Cost),2) as Cost from
      ((Select Channel,sum(DailyTAOZCost) as Cost from CumuConsumption_new group by Channel)
      UNION
      (Select Channel,sum(Power*TAOZ)/60/1000/100 as Cost from STS where ID >(select Value from GenSettings where Indx= "LastSTSidCumuConsump") group by Channel))tab0
      group by tab0.Channel'

    when 'week'
    'Select tab0.Channel, round(sum(tab0.Cost),2) as Cost from
      ((Select Channel,sum(WeeklyTAOZCost) as Cost from CumuConsumption_new group by Channel)
      UNION
      (Select Channel,sum(Power*TAOZ)/60/1000/100 as Cost from STS where ID >(select Value from GenSettings where Indx= "LastSTSidCumuConsump") group by Channel))tab0
      group by tab0.Channel'

    when 'month'
      'Select tab0.Channel, round(sum(tab0.Cost),2) as Cost from
        ((Select Channel,sum(MonthlyTAOZCost) as Cost from CumuConsumption_new group by Channel)
        UNION
        (Select Channel,sum(Power*TAOZ)/60/1000/100 as Cost from STS where ID >(select Value from GenSettings where Indx= "LastSTSidCumuConsump") group by Channel))tab0
        group by tab0.Channel'
    end
  end

def taoz_split_query
    case @period
    when 'day'
      "Select tab0.TAOZ_Level, ifnull(round(sum(tab0.Cost)/
        (Select round(sum(tab0.Cost),3) as Cost from
        ((Select Channel,sum(DailyTAOZCost) as Cost from CumuConsumption_new group by Channel)
        UNION
        (Select Channel,sum(Power*TAOZ)/60/1000/100 as Cost from STS where ID >(select Value from GenSettings where Indx= 'LastSTSidCumuConsump') group by Channel))tab0
      where tab0.Channel = #{@channel_id+1}),3),0) as Cost from
        ((Select Channel,TAOZ_Level,sum(DailyTAOZCost) as Cost from CumuConsumption_new group by Channel, TAOZ_Level)
        UNION
        (Select Channel,TAOZ_Level,sum(Power*TAOZ)/60/1000/100 as Cost from STS where ID >(select Value from GenSettings where Indx= 'LastSTSidCumuConsump') group by Channel,TAOZ_Level))tab0
        where tab0.Channel = #{@channel_id+1} group by tab0.TAOZ_Level"


    when 'week'
      "Select tab0.TAOZ_Level, ifnull(round(sum(tab0.Cost)/
        (Select round(sum(tab0.Cost),3) as Cost from
        ((Select Channel,sum(WeeklyTAOZCost) as Cost from CumuConsumption_new group by Channel)
        UNION
        (Select Channel,sum(Power*TAOZ)/60/1000/100 as Cost from STS where ID >(select Value from GenSettings where Indx= 'LastSTSidCumuConsump') group by Channel))tab0
      where tab0.Channel = #{@channel_id+1}),3),0) as Cost from
        ((Select Channel,TAOZ_Level,sum(WeeklyTAOZCost) as Cost from CumuConsumption_new group by Channel, TAOZ_Level)
        UNION
        (Select Channel,TAOZ_Level,sum(Power*TAOZ)/60/1000/100 as Cost from STS where ID >(select Value from GenSettings where Indx= 'LastSTSidCumuConsump') group by Channel,TAOZ_Level))tab0
        where tab0.Channel = #{@channel_id+1} group by tab0.TAOZ_Level"

    when 'month'
      "Select tab0.TAOZ_Level, ifnull(round(sum(tab0.Cost)/
        (Select round(sum(tab0.Cost),3) as Cost from
        ((Select Channel,sum(MonthlyTAOZCost) as Cost from CumuConsumption_new group by Channel)
        UNION
        (Select Channel,sum(Power*TAOZ)/60/1000/100 as Cost from STS where ID >(select Value from GenSettings where Indx= 'LastSTSidCumuConsump') group by Channel))tab0
      where tab0.Channel = #{@channel_id+1}),3),0) as Cost from
        ((Select Channel,TAOZ_Level,sum(MonthlyTAOZCost) as Cost from CumuConsumption_new group by Channel, TAOZ_Level)
        UNION
        (Select Channel,TAOZ_Level,sum(Power*TAOZ)/60/1000/100 as Cost from STS where ID >(select Value from GenSettings where Indx= 'LastSTSidCumuConsump') group by Channel,TAOZ_Level))tab0
        where tab0.Channel = #{@channel_id+1} group by tab0.TAOZ_Level"

    end
  end

def split_factor_query
    case @period
    when 'day'
      "select round(time_to_sec(current_time())/86400,3) as Ratio"
    when 'week'
      "select round((dayofweek(curdate())-1)/7 + time_to_sec(current_time())/86400/7,2) as Ratio"
    when 'month'
      "select round((dayofmonth(curdate())-1) / day(last_day(curdate())) + time_to_sec(current_time())/86400/(day(last_day(curdate()))),3) as Ratio"
    end
  end

def uptime_query_cumu
  'Select Channel,sum(DailyUptime) as DailyUptime ,sum(WeeklyUptime) as WeeklyUptime ,sum(MonthlyUptime) as MonthlyUptime from CumuConsumption_new group by Channel'
end

def uptime_query_sts
  'Select Channel, Count(*) as Uptime from STS where ID >
  (select Value from GenSettings where Indx= "LastSTSidCumuConsump")
  and Channel in (select Channel from Channels_S where Component is not null and not Component = "")
  and Power > 10 group by Channel'
end


def norm_query
	"select round(tab1.Value * tab2.Month * tab3.Persons * tab4.Decile * tab5.Province * tab6.DailyRatio,3) as DailySocialConsumption,
	round(tab1.Value * tab2.Month * tab3.Persons * tab4.Decile * tab5.Province * (tab7.WeeklyRatio + tab6.DailyRatio),3) as WeeklySocialConsumption,
	round(tab1.Value * tab2.Month * tab3.Persons * tab4.Decile * tab5.Province * (tab8.MonthlyRatio + tab6.DailyRatio),3) as MonthlySocialConsumption
	from
	(select Value from GenSettings where Indx = 'AvgSocialConsumption') tab1,
	(select Month from SocialComparison where ID = (select month(current_date()))) tab2,
	(select Persons from SocialComparison where ID = (select Value from GenSettings where Indx = 'SocialCompPersons')) tab3,
	(select Decile from SocialComparison where ID = (select Value from GenSettings where Indx = 'SocialCompDecile')) tab4,
	(select Province from SocialComparison where ID = (select Value from GenSettings where Indx = 'SocialCompProvince')) tab5,
	(select (ifnull(tab10.D,0) + tab11.m)/day(last_day(curdate())) as DailyRatio
	from
		(select IF (month(curdate()) BETWEEN 1 AND 2 or month(curdate()) = 12, sum(HourWinter)/24,
		IF (month(curdate()) BETWEEN 3 AND 5 or month(curdate()) BETWEEN 9 AND 11, sum(HourTransition)/24,
		IF (month(curdate()) BETWEEN 6 AND 8, sum(HourSummer)/24,null))) as D
		from SocialComparison where ID < hour(current_time())) tab10,
		(select IF (month(curdate()) BETWEEN 1 AND 2 or month(curdate()) = 12,
			(HourWinter/24)*(time_to_sec(maketime(0,minute(current_time()),second((current_time()))))/3600),
		IF (month(curdate()) BETWEEN 3 AND 5 or month(curdate()) BETWEEN 9 AND 11,
			(HourTransition/24)*(time_to_sec(maketime(0,minute(current_time()),second((current_time()))))/3600),
		IF (month(curdate()) BETWEEN 6 AND 8,
			(HourSummer/24)*(time_to_sec(maketime(0,minute(current_time()),second((current_time()))))/3600),null))) as m
		from SocialComparison where ID = hour(current_time())) tab11) tab6,
	(select (dayofweek(curdate())-1)/day(last_day(curdate()))as WeeklyRatio) tab7,
	(select (dayofmonth(curdate())-1) / day(last_day(curdate())) as MonthlyRatio) tab8;"
end

end
