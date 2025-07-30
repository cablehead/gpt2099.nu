def collect-tests [] {

  {
    "gpt.call": {||

      gpt init

      cat .env/anthropic | gpt provider enable anthropic
      gpt provider set-ptr kilo anthropic claude-sonnet-4-20250514

      .append gpt.call

      "hola" | .append gpt.turn
      let req = .append gpt.call --meta {continues: (.head gpt.turn).id}

      # Test gpt call
      # "Hello, how are you?" | .append gpt.call --meta {args: {provider_ptr: "kilo"}}

      .cat -f | update hash { .cas } | take until {|frame|
        print ($frame | table -e)
        ($frame.topic in ["gpt.error" "gpt.response"]) and ($frame.meta?.frame_id == $req.id)
      }

      sleep 50ms
    }
  }
}

export def main [] {

  let tests = collect-tests

  .tmp-spawn $tests."gpt.call"
}

# Spawn xs serve in a temporary directory, run a closure, then cleanup
def .tmp-spawn [closure: closure] {
  # Create a temporary directory
  let tmp_dir = (mktemp -d)
  print $"Created temp directory: ($tmp_dir)"

  let store_path = ($tmp_dir | path join "store")

  try {
    # Create store directory
    mkdir $store_path

    # Spawn xs serve in the background
    let job_id = job spawn --tag "xs-test-server" {
      xs serve $store_path
    }
    print $"Started xs serve with job ID: ($job_id)"

    $env.XS_ADDR = $store_path
    $env.XS_CONTEXT = null

    # Give the server a moment to start up
    sleep 500ms

    try {
      # Run the provided closure
      do $closure | print $in
    } catch {|err|
      error make {msg: $"Error in closure: ($err.msg)"}
    }

    # Kill the background job
    job kill $job_id
    print $"Killed xs serve job ($job_id)"

    # Give a moment for the job to shut down
    sleep 50ms
  } catch {|err|
    print $"Error during setup: ($err.msg)"
  }

  # Clean up the temporary directory
  try {
    # rm -rf $tmp_dir
    print $"Cleaned up temp directory: ($tmp_dir)"
  } catch {|err|
    print $"Warning: Could not clean up temp directory: ($err.msg)"
  }
}
