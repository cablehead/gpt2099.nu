export def provider [] {
  {
    models: {|key|
      (
        http get $"https://generativelanguage.googleapis.com/v1beta/models?key=($key)"
        | get models | select name version supportedGenerationMethods
        | where {|it| 'generateContent' in $it.supportedGenerationMethods }
        | update name {|it| $it.name | str replace 'models/' '' } | get name | wrap id
      )
    }

    call: {|key: string model: string tools?: list|
      let messages = $in
      let data = {
        contents: (
          $messages | each {|msg|
            {
              role: (if $msg.role == "assistant" { 'model' } else { $msg.role })
              parts: (
                $msg.content | each {|content|
                  {text: $content.text}
                }
              )
            }
          }
        )
        systemInstruction: {
          parts: [{text: "You are a helpful assistant."}]
        }
        generationConfig: {
          temperature: 1
          topP: 0.95
          maxOutputTokens: 8192
        }
      }

      let url = $"https://generativelanguage.googleapis.com/v1beta/models/($model):streamGenerateContent?alt=sse&key=($key)"

      # let res = $data | http post -f -e --content-type application/json $url
      # error make {msg: $"TBD:\n\n($messages | to json | table -e)\n\n($res | to json)" }

      $data | http post --content-type application/json $url
      | lines | each {|line| $line | split row -n 2 "data: " | get 1? }
      | each {|x| $x | from json }
    }

    response_stream_aggregate: {||
      "aggregate"
    }

    response_stream_streamer: {|event|
      $event
    }
  }
}
