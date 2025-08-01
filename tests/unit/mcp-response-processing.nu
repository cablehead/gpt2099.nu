use std/assert
use ../../gpt/mcp.nu response-to-tool-result

def test-case [case_name: string module_name: string] {
  use ../output.nu *
  let base_path = $"tests/fixtures/mcp-response-to-tool-result/($case_name)"
  let input = open ($base_path | path join "input.json")
  let expected = open ($base_path | path join "expected.json")

  let actual = $input.mcp_response | response-to-tool-result $input.tool_use

  start $"($module_name).($case_name)"
  assert equal $actual $expected $"Case ($case_name) failed"
  ok
}

export def main [] {
  let module_name = "mcp-response-processing"
  let test_cases = [
    "timeout-error"
    "success"
  ]

  for case in $test_cases {
    test-case $case $module_name
  }
}
