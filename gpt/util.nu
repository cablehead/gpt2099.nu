export def is-scru128 [s: string] {
  $s =~ '(?i)^[0-9a-z]{25}$'
}

use std/assert

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
