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

  def internet
  end

  def sync
		@sync[:Site] = @syncSettings.find {|setting| setting['Indx'] == 'Site'}
		@sync[:Completion] = @syncSettings.find {|setting| setting['Indx'] == 'POSTInProgress'}["Value"] == '1' && $dbclient.query(sync_completion_query).first["Completion"]
  end

  def info
  end

	def syncUpdate
		['OfflineMode', 'Site'].each {|setting| $dbclient.query("UPDATE GenSettings SET Value='#{sync_params[setting]}' where Indx = '#{setting}'") if sync_params[setting] }
    redirect_to action: :sync, id: params[:id]
  end

	private

  def sync_params
    params.permit(:OfflineMode, :Site)
  end

	def sync_completion_query
		"select round(((select Value from GenSettings where Indx = 'lastBatchSyncedID') -
		(select Value from GenSettings where Indx = 'lastCompleteSyncedID' )) /
		((select max(id) from STS) -(select Value from GenSettings where Indx = 'lastCompleteSyncedID'))*100,2)'Completion'"
	end
end
