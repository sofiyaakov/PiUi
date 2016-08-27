class SettingsController < ApplicationController
	layout 'application'
	helper :application

  def network
    @network = { ssid: 'YaakovWifi' }
    # @networks = [
    #   { id: 1234, ssid: 'YaakovWifi' },
    #   { id: 1111, ssid: 'Bezeq_as123' },
    #   { id: 2222, ssid: 'Bezeq_gag51' }
    # ]
  end

  def general
		@sync[:Site] = @syncSettings.find {|setting| setting['Indx'] == 'Site'}
		@sync[:SocialCompProvince] = @syncSettings.find {|setting| setting['Indx'] == 'SocialCompProvince'}['Value']
		@sync[:SocialCompPersons] = @syncSettings.find {|setting| setting['Indx'] == 'SocialCompPersons'}['Value']
		@sync[:SocialCompDecile] = @syncSettings.find {|setting| setting['Indx'] == 'SocialCompDecile'}['Value']
  end

	def generalUpdate
		['Site', 'SocialCompProvince', 'SocialCompPersons', 'SocialCompDecile'].each {|setting| $dbclient.query("UPDATE GenSettings SET Value='#{general_params[setting]}' where Indx = '#{setting}'") if general_params[setting] }
    redirect_to action: :general
  end

  def sync
		@sync[:Completion] = @syncSettings.find {|setting| setting['Indx'] == 'POSTInProgress'}["Value"] == '1' && $dbclient.query(sync_completion_query).first["Completion"]
  end

  def info
  end

	def syncUpdate
		['OfflineMode', 'RT_OfflineMode'].each {|setting| $dbclient.query("UPDATE GenSettings SET Value='#{sync_params[setting]}' where Indx = '#{setting}'") if sync_params[setting] }
    redirect_to action: :sync
  end

	private

  def sync_params
    params.permit(:OfflineMode, :RT_OfflineMode)
  end

	def general_params
    params.permit(:Site, :SocialCompProvince, :SocialCompPersons, :SocialCompDecile)
  end

	def sync_completion_query
		"select round(((select Value from GenSettings where Indx = 'lastBatchSyncedID') -
		(select Value from GenSettings where Indx = 'lastCompleteSyncedID' )) /
		((select max(id) from STS) -(select Value from GenSettings where Indx = 'lastCompleteSyncedID'))*100,2)'Completion'"
	end
end
