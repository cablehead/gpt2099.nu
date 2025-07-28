use std/assert
use ../../gpt/ctx.nu is-scru128

def "test is-scru128" [] {
  for row in [
    [input expected];
    ["03DXL6W8Q53VJHS6I91Q9R7M3" true]
    ["03dxl06wtwyj21a220p4xq1to" true]
    ["0372hg16csmsm50l8dikcvukc" true]
    ["short" false]
    ["03dxl06wtwyj21a220p4xq1to1" false]
    ["03DXL6W8Q53VJHS6I91Q9R7!" false]
  ] {
    assert equal (is-scru128 $row.input) $row.expected
  }
}

export def main [] {
  print "Testing util functions..."
  test is-scru128
  print "✅ All util tests passed!"
}
