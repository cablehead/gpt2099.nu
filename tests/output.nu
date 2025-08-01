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
