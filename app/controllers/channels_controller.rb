class ChannelsController < ActionController::Base
	layout 'application'
  before_action :get_data, :get_channel

  def show
    @period = params['period'] || 'realtime'
  end

  def edit
  end

  private
  def get_data
    @channels = [
      {number: 1, title: "מטבח", power: 1.23, status: true, category: 'שקעים', transmitter: 210, parent: 4, max_current: 10, supply_voltage: 220},
      {number: 2, title: "מחסן", power: 0, status: false, category: 'שקעים', transmitter: 211, parent: 4, max_current: 10, supply_voltage: 220 },
      {number: 3, title: "חדר שינה", power: 1.5, status: true, category: 'שקעים', transmitter: 212, parent: 4, max_current: 10, supply_voltage: 220},
      {number: 4, title: "סלון", power: 0.4, status: true, category: 'שקעים', transmitter: 213, max_current: 20, supply_voltage: 220},
      {number: 5, title: "מקרר", power: 0, status: false, category: 'שקעים', transmitter: 214, max_current: 10, supply_voltage: 220},
      {number: 6, title: "מזגן הורים", power: 2, status: true, category: 'שקעים', transmitter: 215, max_current: 10, supply_voltage: 220},
      {number: 7, title: "תנור", power: 1.1, status: true, category: 'שקעים', transmitter: 216, max_current: 10, supply_voltage: 220},
      {number: 8, title: "דוד חשמל", power: 0.9, status: true, category: 'שקעים', transmitter: 217, max_current: 10, supply_voltage: 220},
      {number: 9, title: "מטבח", power: 1.23, status: true, category: 'מונורות', transmitter: 218, max_current: 10, supply_voltage: 220},
      {number: 10, title: "מחסן", power: 0, status: false, category: 'מונורות', transmitter: 219, max_current: 10, supply_voltage: 220},
      {number: 11, title: "חדר שינה", power: 1.5, status: true, category: 'מונורות', transmitter: 220, parent: 6, max_current: 10, supply_voltage: 220},
      {number: 12, title: "סלון", power: 0.4, status: true, category: 'מונורות', transmitter: 221, parent: 6, max_current: 10, supply_voltage: 220},
      {number: 13, title: "מקרר", power: 0, status: false, category: 'מונורות', transmitter: 222, parent: 6, max_current: 10, supply_voltage: 220},
      {number: 14, title: "מזגן הורים", power: 2, status: true, category: 'שקעים', transmitter: 223, max_current: 10, supply_voltage: 220},
      {number: 15, title: "חדר ילדים", power: 1.1, status: true, category: 'ראשי', transmitter: 224, max_current: 10, supply_voltage: 220},
      {number: 16, title: "חדר שינה", power: 0.9, status: true, category: 'ראשי', transmitter: 225, max_current: 10, supply_voltage: 220}
    ]
  end

  def get_channel
    channel_id = (params[:id] || 1).to_i - 1
    @channel = @channels[channel_id]
  end
end
