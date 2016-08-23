class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :commonData

  def commonData
    @syncSettings = $dbclient.query("SELECT * from GenSettings")
    @sync = {
      OfflineMode: @syncSettings.find {|setting| setting['Indx'] == 'OfflineMode'}['Value'].to_i,
      RT_OfflineMode: @syncSettings.find {|setting| setting['Indx'] == 'RT_OfflineMode'}['Value'].to_i,
      TimeStamp: @syncSettings.find {|setting| setting['Indx'] == 'lastCompleteSyncedID'}['Time']
    }
    @boxDetails = $dbclient.query(box_Query)
  end

  def box_Query
    '(select tab33.Box, tab32.C as Channels, round((sum(tab31.C)/(tab32.c*10))*100/25,0) as RecepQuality from
    (select Channel, count(*) as C from RT where ID > (select max(ID)-200 from RT) 
    and unix_timestamp()-unix_timestamp(Time)<60 and Channel in 
    (select Channel from Channels_S where Active = 1) group by Channel) tab31,
    (select round(Transmitter,-2) as Box, count(*) as C from Channels_S where Active = 1 group by round(Transmitter,-2)) tab32,
    (select Channel, round(Transmitter,-2) as Box from Channels_S where Active = 1 group by Channel) tab33
    where tab31.Channel = tab33.Channel and tab32.Box = tab33.Box group by tab33.Box)
    UNION
    (select tab2.Box,tab2.Channels,0 as RecepQuality
    from
    (select round(Transmitter,-2) as Box, count(*) as Channels from Channels_S where Active = 1 group by round(Transmitter,-2))tab2
    where tab2.Box NOT IN 
    (select tab33.Box
     from
      (select Channel, count(*) as C from RT where ID > (select max(ID)-200 from RT) 
      and unix_timestamp()-unix_timestamp(Time)<60 and Channel in 
      (select Channel from Channels_S where Active = 1) group by Channel) tab31,
      (select round(Transmitter,-2) as Box, count(*) as C from Channels_S where Active = 1 group by round(Transmitter,-2)) tab32,
      (select Channel, round(Transmitter,-2) as Box from Channels_S where Active = 1 group by Channel) tab33
    where tab31.Channel = tab33.Channel and tab32.Box = tab33.Box group by tab33.Box)
    group by Box)
    UNION
    (select round(Transmitter,-2) as Box,count(*) as Channels, 1000 as RecepQuality from TransmittersNotExist 
    where Transmitter > 999 
    and transmitter NOT IN (Select Transmitter from Channels_S where Transmitter is not null)
    and TIMEDIFF(current_timestamp,Time) < 2000000
    group by round(Transmitter,-2)
    order by Time desc);'
  end

end
