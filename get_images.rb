require 'flickraw'

FlickRaw::Flickr.new.people.getPublicPhotos(
  user_id: "158890375@N08",
  extras: 'url_m, url_k'
).each do |photo|
  puts "- m: #{photo['url_m']}\n  l: #{photo['url_k']}"
end
