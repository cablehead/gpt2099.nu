# Providers Module
# This module aggregates and exports all provider implementations
# Each provider must implement the standard interface as defined in provider-api.md

use ./anthropic
use ./gemini
use ./openai

export def main [] {
  {
    anthropic : (anthropic provider)
    gemini : (gemini provider)
    openai : (openai provider)
  }
}
