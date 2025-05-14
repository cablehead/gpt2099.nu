# exercise the interface between context and the providers prepare-request

source ~/.config/nushell/config.nu

use ../gpt

let ctx = r#'
{
  "messages": [
    {
      "id": "03dx8d9bpq7pyeeqsra9su2h2",
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "3 + 2"
        }
      ],
      "options": {
        "servers": null,
        "search": false
      },
      "cache": false
    }
  ],
  "options": {
    "servers": null,
    "search": false
  }
}
'# | from json

let providers = gpt providers

# do (gpt providers).anthropic.prepare-request $ctx null

$providers | items {|name p|
  print $name
  print (do $p.prepare-request $ctx null | table -e)
}
