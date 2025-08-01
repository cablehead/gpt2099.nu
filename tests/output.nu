# Custom test output module for streaming test results

export def start [test_name: string] {
  print -n $"- ($test_name) - "
}

export def ok [] {
  print "ok"
}

export def error [message: string] {
  print $"error: ($message)"
}

export def warning [message: string] {
  print $"warning: ($message)"
}

export def skip [reason: string] {
  print $"skipped: ($reason)"
}

export def debug [data: any] {
  let debug_enabled = ($env.GPT2099_TEST_DEBUG? | default "false") in ["1" "true"]
  if $debug_enabled {
    $data | table -e | print
  }
}
