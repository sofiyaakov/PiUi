class ChannelsController < ActionController::Base
	layout 'application'
  def show
    @channels = [
      {number: 1, title: "מטבח", power: 1.23, status: true},
      {number: 2, title: "מחסן", power: 0, status: false},
      {number: 3, title: "חדר שינה", power: 1.5, status: true},
      {number: 4, title: "סלון", power: 0.4, status: true},
      {number: 5, title: "מקרר", power: 0, status: false},
      {number: 6, title: "מזגן הורים", power: 2, status: true},
      {number: 7, title: "תנור", power: 1.1, status: true},
      {number: 8, title: "דוד חשמל", power: 0.9, status: true},
      {number: 9, title: "מטבח", power: 1.23, status: true},
      {number: 10, title: "מחסן", power: 0, status: false},
      {number: 11, title: "חדר שינה", power: 1.5, status: true},
      {number: 12, title: "סלון", power: 0.4, status: true},
      {number: 13, title: "מקרר", power: 0, status: false},
      {number: 14, title: "מזגן הורים", power: 2, status: true},
      {number: 15, title: "תנור", power: 1.1, status: true},
      {number: 16, title: "דוד חשמל", power: 0.9, status: true}
    ]
    channel_id = (params['channel'] || 1).to_i - 1
    @channel = @channels[channel_id]
    @period = params['period'] || 'realtime'
  end
end
