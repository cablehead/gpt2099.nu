use ./anthropic.nu
use ./inception.nu

export def main [] {
  {
    anthropic : (anthropic provider)
    inception : (inception provider)
  }
}
