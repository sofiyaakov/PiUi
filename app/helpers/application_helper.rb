module ApplicationHelper
  def lastSyncTimeString
    "סנכרון אחרון: #{@sync[:TimeStamp].strftime("%d/%m/%Y - %H:%M")}"
  end
end
