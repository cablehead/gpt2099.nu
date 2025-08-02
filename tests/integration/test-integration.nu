def collect-tests [] {
  use std/assert

  const output_module = (path self "../output.nu")
  use $output_module *

  const gpt_module = (path self "../../gpt")
  use $gpt_module

  {
    "call.anthropic.basics": {||
      gpt init
      sleep 50ms

      cat .env/anthropic | gpt provider enable anthropic
      gpt provider set-ptr milli anthropic claude-3-5-haiku-20241022
      sleep 50ms

      # Create turn using schema add-turn, then call gpt call
      let turn = "what's 2+2, tersely?" | gpt schema add-turn {provider_ptr: "milli"}
      let response = gpt call $turn.id

      let res = .cas $response.hash | from json
      $res | to json | debug $in
      assert equal $res.0.text "4"
    }

    "call.gemini.basics": {||
      gpt init
      sleep 50ms

      cat .env/gemini | gpt provider enable gemini
      gpt provider set-ptr milli gemini gemini-2.5-flash
      sleep 50ms

      # Create turn using schema add-turn, then call gpt call
      let turn = "what's 2+2, tersely?" | gpt schema add-turn {provider_ptr: "milli"}
      let response = gpt call $turn.id

      let res = .cas $response.hash | from json
      $res | to json | debug $in
      assert equal $res.0.text "4"
    }

    "call.anthropic.tool_use": {||
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

      # Create turn using schema add-turn, then call gpt call
      let turn = "reverse of the string 'foo'; note, no print" | gpt schema add-turn {
        provider_ptr: "milli"
        servers: ["nu"]
      }
      let response = gpt call $turn.id

      # Check if we got an error response
      if $response.topic == "gpt.error" {
        $response | to json | error make {msg: $"API call failed: ($in)"}
      }

      let res = .cas $response.hash | from json
      assert ("tool_use" in ($res | get type))
    }

    "schema.add-turn.basic-text": {||
      let turn = "Hello world" | gpt schema add-turn {}
      let stored_content = .cas $turn.hash | from json
      let expected = [
        {type: "text" text: "Hello world"}
      ]
      assert equal $stored_content $expected
    }

    "schema.add-turn.with-cache": {||
      let turn = "Cached content" | gpt schema add-turn {cache: true}
      assert equal $turn.meta?.cache? true
      let stored_content = .cas $turn.hash | from json
      let expected = [
        {type: "text" text: "Cached content"}
      ]
      assert equal $stored_content $expected
    }
  }
}

export def main [name?: string] {
  use ../output.nu *

  let tests = collect-tests

  let to_test = if $name != null {
    # Filter tests by prefix match
    $tests | columns | where ($it | str starts-with $name)
  } else {
    $tests | columns
  }

  for test in $to_test {
    start $test
    try {
      .tmp-spawn ($tests | get $test)
      ok
    } catch {|err|
      failed $err.msg
    }
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
