#!/usr/bin/env nu

def run-provider [raw_stream] {

  $raw_stream | to json -r | ^$nu.current-exe ...[
    --no-config-file
    --stdin
    --commands
    '
    use mod.nu

    let raw_stream = $in | from json

    let p = mod provider

    $raw_stream | each {|event| do $p.response_stream_streamer $event}

    '
  ]
}

clear

cd $env.FILE_PWD
let target = ls | where type == "dir" | first

let raw_stream = open $"($target.name)/01-response_stream_raw.json"

let tmp = mktemp -d
cp $"../gpt/providers/($target.name).nu" ($tmp | path join "mod.nu")
cd $tmp

run-provider $raw_stream
