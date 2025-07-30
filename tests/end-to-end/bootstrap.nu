# Bootstrap configuration for cross.stream
# This file sets up the initial environment

# Load the gpt module
use /root/session/gpt2099.nu/gpt

gpt init

cat ../../.env/anthropic | gpt provider enable anthropic
gpt provider set-ptr kilo anthropic claude-sonnet-4-20250514

.append gpt.call

"hola" | .append gpt.turn
let req = .append gpt.call --meta {continues: (.head gpt.turn).id}

# Test gpt call
# "Hello, how are you?" | .append gpt.call --meta {args: {provider_ptr: "kilo"}}

.cat -f | update hash { .cas } | take until {|frame| 
	print ($frame | table -e) 
	($frame.topic == "gpt.response") and ($frame.meta?.frame_id == $req.id)
}

sleep 50ms

