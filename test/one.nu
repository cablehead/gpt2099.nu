use mod.nu

let raw_stream = $in | from json
let p = mod provider

$raw_stream | each {|event| do $p.response_stream_streamer $event }
$raw_stream | do $p.response_stream_aggregate
