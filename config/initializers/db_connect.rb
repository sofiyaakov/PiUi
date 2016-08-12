config = Rails.application.secrets
puts config
$dbclient = Mysql2::Client.new(
  host: config.db_host,
  username: config.db_user,
  password: config.db_pass,
  database: config.db_name,
  reconnect: true
)