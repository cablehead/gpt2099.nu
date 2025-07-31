def collect-tests [] {
  {
    "gpt.call.basics": {||
      use std/assert
      use std/log

      gpt init

      cat .env/anthropic | gpt provider enable anthropic
      gpt provider set-ptr kilo anthropic claude-sonnet-4-20250514

      .append gpt.call

      "what's 2+2, tersely?" | .append gpt.turn
      let req = .append gpt.call --meta {continues: (.head gpt.turn).id}

      .cat -f | update hash { .cas } | take until {|frame|
        $frame | table -e | log debug $in
        ($frame.topic in ["gpt.error" "gpt.response"]) and ($frame.meta?.frame_id == $req.id)
      }

      let res = .head gpt.response | .cas $in.hash | from json
      $res | table -e | log debug $in

      assert equal $res.message.content.0.text "4"

      sleep 50ms
    }

    "gpt.call.tool_use": {||
      use std/assert
      use std/log

      return
      gpt init

      cat .env/anthropic | gpt provider enable anthropic
      gpt provider set-ptr kilo anthropic claude-sonnet-4-20250514

      .append gpt.call

      "what's 2+2, tersely?" | .append gpt.turn
      let req = .append gpt.call --meta {continues: (.head gpt.turn).id}

      .cat -f | update hash { .cas } | take until {|frame|
        $frame | table -e | log debug $in
        ($frame.topic in ["gpt.error" "gpt.response"]) and ($frame.meta?.frame_id == $req.id)
      }

      let res = .head gpt.response | .cas $in.hash | from json
      $res | table -e | log debug $in

      assert equal $res.message.content.0.text "4"

      sleep 50ms
    }
  }
}

export def main [name?: string] {
  use std/log

  $env.NU_LOG_FORMAT = '- %MSG%'

  let tests = collect-tests

  let to_test = if $name != null { [$name] } else { $tests | columns }
  for test in $to_test {
    log info $test
    .tmp-spawn ($tests | get $test)
  }
}

# Spawn xs serve in a temporary directory, run a closure, then cleanup
def .tmp-spawn [closure: closure] {
  use std/log
  # Create a temporary directory
  let tmp_dir = (mktemp -d)
  log debug $"Created temp directory: ($tmp_dir)"

  let store_path = ($tmp_dir | path join "store")

  try {
    # Create store directory
    mkdir $store_path

    # Spawn xs serve in the background
    let job_id = job spawn --tag "xs-test-server" {
      xs serve $store_path
    }
    log debug $"Started xs serve with job ID: ($job_id)"

    $env.XS_ADDR = $store_path
    $env.XS_CONTEXT = null

    # Give the server a moment to start up
    sleep 500ms

    try {
      # Run the provided closure
      do $closure
    } catch {|err|
      error make {msg: $"Error in closure: ($err.msg)"}
    }

    # Kill the background job
    job kill $job_id
    log debug $"Killed xs serve job ($job_id)"

    # Give a moment for the job to shut down
    sleep 50ms
  } catch {|err|
    log error $"Error during setup: ($err.msg)"
  }

  # Clean up the temporary directory
  try {
    # rm -rf $tmp_dir
    log debug $"Cleaned up temp directory: ($tmp_dir)"
  } catch {|err|
    log warning $"Warning: Could not clean up temp directory: ($err.msg)"
  }
}
