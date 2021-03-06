require 'bundler'
Bundler.require
require 'sinatra/reloader' if settings.development?

set :haml, format: :html5
cache = Dalli::Client.new

feed_url = "http://www.spanishdict.com/wordoftheday/feed"

# Prepares and returns this edition of the publication
# == Returns:
# HTML/CSS edition with etag. This publication changes the greeting depending
# on the time of day. It is using UTC to determine the greeting.
#
get '/edition/?' do

  unless xml = cache.get("feed")
    response = Typhoeus::Request.get feed_url
    if response.success?
      cache.set("feed", response.body, 300)
      xml = response.body
    end
  end

  unless xml
    status 500
    return "Something went wrong."
  end

  feed = Nokogiri::XML.parse(xml)
  
  latest_word = feed.css("item").first
  pieces_of_title = latest_word.at_css("title").text.split(" - ")
  @word = pieces_of_title[1]
  @definition = pieces_of_title[2]
  other = Sanitize.clean(latest_word.at_css("description").text)
  @pronounciation = other.match(/\((.+?)\)/)[1]
  @type = other.match(/\(.+?\) (\w+):/)[1]
  @example = other.match(/:(.+)$/)[1]

  @guid = latest_word.at_css("guid").text

  etag Digest::MD5.hexdigest(settings.development? ? Time.now.to_s : @guid) 
  haml :word_of_the_day
end


# Returns a sample of the publication. Triggered by the user hitting 'print sample' on you publication's page on BERG Cloud.
#
# == Parameters:
#   None.
#
# == Returns:
# HTML/CSS edition with etag. This publication changes the greeting depending on the time of day. It is using UTC to determine the greeting.
#
get '/sample/?' do
  @word = "celeste"
  @definition = "heavenly, sky-blue"
  @pronounciation = "seh-leh'-steh"
  @type = "adjective"
  @example = "Te queda mejor el vestido celeste para la fiesta. - The sky-blue dress looks better on you for the party."
  
  # Set the etag to be this content
  haml :word_of_the_day
end

get '/application.css' do
  sass :style
end
