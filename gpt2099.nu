def iff [
  action: closure
  --else: closure
]: any -> any {
  if ($in | is-not-empty) {do $action} else {
    if ($else | is-not-empty) {do $else}
  }
}

def or-else [or_else: closure] {
  if ($in | is-not-empty) {$in} else {do $or_else}
}

export def id-to-messages [id: string] {
  let frame = .get $id
  let role = $frame | get meta? | if ($in | is-not-empty) {$in} else {{}} | default "user" role | get role
  let content = (.cas $frame.hash)
  let message = {
    id: $id
    role: $role
    content: $content
  }

  let next_id = $frame | get meta?.continues?

  match ($next_id | describe -d | get type) {
    "string" => (id-to-messages $next_id | append $message)
    "list" => ($next_id | each {|id| id-to-messages $id} | flatten | append $message)
    "nothing" => [$message]
    _ => ( error make { msg: "TBD" })
  }
}

export def thread [id?: string --sk] {
  id-to-messages (
    $id | or-else {||
      .cat | where topic == "message" | last | get id
    }
  ) | conditional-pipe $sk {|| dash-sk}
}

export def read-input [] {
  iff {||
    match ($in | describe -d | get type) {
      "string" => $in
      "list" => ($in | str join "\n\n----\n\n")
      _ => ( error make { msg: "TBD" })
    }
  } --else {|| input "prompt: "}
}

export def is-interactive [] {
  (is-terminal --stdin) and ($env.GPT_INTERACTIVE? | default true)
}

export def --env run-thread [id: string] {
  let messages = id-to-messages $id

  mut streamer = {|| return }
  # Only enable interactivity if we're attached to a terminal.
  if (is-interactive) {
    gpt ensure-provider
    $streamer = {|| print -n $in}
    print "Context:"
    print $messages
  }

  let res = $messages | reject id | gpt call --streamer $streamer
  $res | .append message --meta {
    provider: $env.GPT_PROVIDER
    role: "assistant"
    continues: $id
  }
  return
}

export def --env new [] {
  let content = read-input
  let frame = $content | .append message --meta { role: "user" }
  run-thread $frame.id
  return
}

export def --env resume [
  id?: string
  --sk
] {
  let input = $in

  let id = if $sk {
    thread | dash-sk | if ($in | is-not-empty) {$in.id} else { return }
  } else {
    $id | or-else {|| .cat | where topic == "message" | last | get id}
  }

  let content = $input | read-input

  let frame = $content | .append message --meta { role: "user" continues: $id }
  run-thread $frame.id
  return
}

export def --env system [] {
  let content = read-input
  let frame = .cat | where {|frame| ($frame.topic == "messages") and (($frame | get meta.role?) == "system")} | input list --fuzzy -d meta.description
  $content | resume $frame.id
}

export def prep [...names: string] {
  $names | each {|name| $"($name):\n\n``````\n(open $name | str trim)\n``````\n"} | str join "\n"
}

def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition {do $action} else {$in}
}

def role-color [role: string] {
  match $role {
    "assistant" => "green"
    "user" => "blue"
    _ => "purple"
  }
}

def dash-sk [] {
  let size = term size

  $in | reverse | sk --format {
    $"..($in.id | str substring 20..) (ansi (role-color $in.role))($in.role | fill -w 9 -a r)(ansi reset) ($in.content | lines | str join)"
  } --preview {
    $in.content | bat -l md --force-colorization -p
  } --preview-window (if $size.columns >= 120 {"right"} else {"up"})
}
