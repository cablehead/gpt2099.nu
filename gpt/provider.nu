export def main [] {
  .cat
  | where topic =~ "gpt.provider"
  | each { .cas | from json }
  | group-by name
  | values
  | each { last }
  | transpose -rd
}
