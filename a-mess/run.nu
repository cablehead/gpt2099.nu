#!/usr/bin/env bash
tmp=$(mktemp)
sed '1,/^# WRAPPER_END_MARKER$/d' "$0" > "$tmp"
exec nu --include-path "$(pwd)" "$tmp" "$@"
# WRAPPER_END_MARKER

use ./gpt

let p = (gpt providers) | get gemini
let stream = open ./test/gemini/case-search-response-stream.nuon
# let stream = open ./test/anthropic/01-response_stream.nuon

# return ($stream | do $p.response_stream_aggregate | to json) # | save -f test/anthropic/case-search-response-stream-aggregate.nuon

$stream | gpt preview-stream $p.response_stream_streamer

return
