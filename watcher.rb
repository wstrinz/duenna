require 'civility'
require 'json'
require 'net/http'

class Watcher
  def initialize(license_key, slack_post_url)
    @license_key = license_key
    @civ_client = Civility::GMR.new(license_key)
    @slack_post_url = slack_post_url
  end

  def watch(game)
    @game_name = game["name"]
    @players = game["players"]
    t = current_turn
    notify_start(game, t)
    watch_loop(15 * 60, game, t) # loop every 15 min. Woooo
  end

  def watch_loop(sleeptime, game, curr_turn)
    loop do
      puts "watching #{game}\n#{curr_turn}"
      t = current_turn
      if t["TurnId"] != curr_turn["TurnId"]
        curr_turn = t
        next_player = @players[t["PlayerNumber"].to_s]
        puts "notifying #{next_player}"
        notify_turn_change(next_player)
      else
        puts "same turn"
      end
      puts "sleeping #{sleeptime}"
      sleep sleeptime
    end
  end

  def notify_start(game, curr_turn)
    curr_player = @players[curr_turn["PlayerNumber"].to_s]
    payload = "Civility bot started! Currently #{curr_player}'s turn"
    puts "posting \n\n#{payload}\n\n to slack"
    slack_post(payload)
  end

  def notify_turn_change(player_name)
    slack_post "@#{player_name} 's turn!"
  end

  def slack_post(string)
    url = URI(@slack_post_url)

    payload = {
      text: string,
      channel: "#civility",
      username: "CivilityBot",
      icon_emoji: ":robot:",
      parse: "full"
    }

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url.request_uri)
    request.body = payload.to_json

    puts "posting #{payload} to #{url}"

    res = http.request(request)

    puts "got #{res.inspect}\n#{res.body}"
    # puts `curl -X POST --data-urlencode 'payload=#{payload}' "#{url}"`
  end

  def current_turn
    @civ_client.games.find{|g| g["Name"] == @game_name}["CurrentTurn"]
  end
end

license_key = ARGV[0]
slack_post_url = ARGV[2]

unless license_key && slack_post_url
  puts "usage: watcher.rb <GMR Key> <Slack URL>"
  exit 1
end

game_info = JSON.parse open("game.json").read

Watcher.new(license_key, slack_post_url).watch(game_info)
