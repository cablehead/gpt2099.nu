use mod.nu



let raw_stream = $in | from json

print $raw_stream
 
let p = mod provider

print $p

# $raw_stream | each {|event| do $p.response_stream_streamer $event }
