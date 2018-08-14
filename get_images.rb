require 'flickraw'

flickr = FlickRaw::Flickr.new
for photo in flickr.photos.getRecent(owner_name: "158890375@N08")
  info = flickr.photos.getInfo(
    photo_id: photo.id,
    secret: photo.secret
  )
  puts "- #{FlickRaw.url(info)}"
end
