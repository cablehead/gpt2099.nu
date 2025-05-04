# Providers Module
# This module aggregates and exports all provider implementations
# Each provider must implement the standard interface as defined in provider-api.md

use ./anthropic
use ./gemini

# Provider Interface Requirements:
# Each provider must implement these closures:
# - models: Retrieves available models from provider
# - call: Makes an API call to generate a response
# - response_stream_aggregate: Aggregates events into a complete response
# - response_stream_streamer: Transforms provider events to normalized stream format
# - response_to_mcp_toolscall: Converts tool calls to MCP format
# - mcp_toolscall_response_to_provider: Converts MCP responses back to provider format
#
# For response_stream_streamer specifically:
# Output must conform to one of these two record formats:
# 1. Content Block Type Indicator: {type: string, name?: string}
# 2. Content Addition: {content: string}
# See provider-api.md for detailed specifications

export def main [] {
  {
    anthropic : (anthropic provider)
    gemini : (gemini provider)
  }
}
