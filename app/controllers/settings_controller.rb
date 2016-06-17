class SettingsController < ActionController::Base
	layout 'application'

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
  end

  def info
  end
end
