require 'rollbar'
require 'rspotify'
require 'rspotify/oauth'
require 'sinatra'
require 'omniauth'
require 'redis'

if ENV['ROLLBAR_ACCESS_TOKEN']
  Rollbar.configure do |config|
    config.access_token = ENV['ROLLBAR_ACCESS_TOKEN']
  end
end

use Rollbar::Middleware::Sinatra
use Rack::Session::Cookie
use OmniAuth::Builder do
  provider :spotify, ENV['SPOTIFY_CLIENT_ID'], ENV['SPOTIFY_CLIENT_SECRET'], scope: 'playlist-read-private playlist-modify-public playlist-modify-private'
end

REDIS = Redis.new(url: ENV['REDIS_URL'])
RSpotify::authenticate(ENV['SPOTIFY_CLIENT_ID'], ENV['SPOTIFY_CLIENT_SECRET'])

SPOTIFY_ID_TRACK_REGEX = /(?:open\.spotify\.com\/track\/|spotify:track:)(\w+)/i

get '/' do
  redirect to('/auth/spotify')
end

get '/auth/spotify/callback' do
  REDIS.set('oauth', request.env['omniauth.auth'].to_json)
  request.env['omniauth.auth'].to_json
end

post '/slack-incoming' do
  return if params[:token] != ENV['SLACK_TOKEN']

  track_id = SPOTIFY_ID_TRACK_REGEX.match(params[:text])[1]

  return unless track_id

  credentials = JSON.parse(REDIS.get('oauth'))
  user = RSpotify::User.new(credentials)

  playlist = RSpotify::Playlist.find(user.id, ENV['SPOTIFY_PLAYLIST_ID'])
  track =  RSpotify::Base.find(track_id, 'track')

  puts

  playlist.add_tracks!([track])
  nil
end
