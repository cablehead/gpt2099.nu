#!/usr/bin/env nu

clear

cd $env.FILE_PWD

const name = "anthropic"

let raw_stream = open $"($name)/01-response_stream_raw.json"
let runner = open "./one.nu"

cd $"../gpt/providers/($name)"

$raw_stream | to json | ^$nu.current-exe ...[
  --no-config-file
  --stdin
  --commands
  $runner
]

