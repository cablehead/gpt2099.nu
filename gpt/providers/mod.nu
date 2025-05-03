use ./anthropic.nu
use ./gemini.nu

export def main [] {
  {
    anthropic : (anthropic provider)
    gemini : (gemini provider)
  }
}
