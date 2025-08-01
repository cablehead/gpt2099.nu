def collect-tests [] {
  use std/assert
  use ../output.nu *

  {
    "gpt.call.basics": {||
      gpt init
      sleep 50ms

      cat .env/anthropic | gpt provider enable anthropic
      gpt provider set-ptr milli anthropic claude-3-5-haiku-20241022

      return

      "what's 2+2, tersely?" | .append gpt.turn
      let req = .append gpt.call --meta {
        continues: (.head gpt.turn).id
        options: {provider_ptr: "milli"}
      }

      .cat -f | update hash { .cas $in } | take until {|frame|
        $frame | to json | debug $in
        ($frame.topic in ["gpt.error" "gpt.turn"]) and ($frame.meta?.frame_id == $req.id)
      }

      let res = .head gpt.turn | .cas $in | from json
      $res | to json | debug $in
      assert equal $res.message.content.0.text "4"
      ok
    }

    "gpt.call.tool_use": {||
      gpt init
      sleep 50ms
      cat .env/anthropic | gpt provider enable anthropic
      gpt provider set-ptr milli anthropic claude-3-5-haiku-20241022

      gpt mcp register nu mcp-server-nu
      # todo: init will setup a handler which takes care of this
      sleep 50ms
      gpt mcp initialize nu
      sleep 50ms
      gpt mcp tool list nu | to json | .append mcp.nu.tools

      "reverse the string 'foo'" | .append gpt.turn --meta {options: {servers: ["nu"]}}
      let req = .append gpt.call --meta {
        continues: (.head gpt.turn).id
        options: {provider_ptr: "milli"}
      }

      .cat -f | update hash { .cas $in } | take until {|frame|
        $frame | table -e | debug $in
        ($frame.topic in ["gpt.error" "gpt.turn"]) and ($frame.meta?.frame_id == $req.id)
      }

      let res = .head gpt.turn | .cas $in | from json
      assert ("tool_use" in ($res | get message.content.type))
      ok
    }
  }
}

export def main [name?: string] {
  use ../output.nu *

  let tests = collect-tests

  let to_test = if $name != null { [$name] } else { $tests | columns }
  for test in $to_test {
    start $test
    .tmp-spawn ($tests | get $test)
  }
}

# Spawn xs serve in a temporary directory, run a closure, then cleanup
def .tmp-spawn [closure: closure] {
  use ../output.nu *
  # Create a temporary directory
  let tmp_dir = (mktemp -d)
  debug $"Created temp directory: ($tmp_dir)"

  let store_path = ($tmp_dir | path join "store")

  try {
    # Create store directory
    mkdir $store_path

    # Spawn xs serve in the background
    let job_id = job spawn --tag "xs-test-server" {
      xs serve $store_path
    }
    debug $"Started xs serve with job ID: ($job_id)"

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
    debug $"Killed xs serve job ($job_id)"

    # Give a moment for the job to shut down
    sleep 50ms
  } catch {|err|
    error make {msg: $"Error during setup: ($err.msg)"}
  }

  # Clean up the temporary directory
  try {
    # rm -rf $tmp_dir
    debug $"Cleaned up temp directory: ($tmp_dir)"
  } catch {|err|
    warning $"Could not clean up temp directory: ($err.msg)"
  }
}
