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
  end
end
