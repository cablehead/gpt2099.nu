#!/usr/bin/env bash

set -e

# Colors for output
RED="\\033[0;31m"
GREEN="\\033[0;32m"
YELLOW="\\033[1;33m"
BLUE="\\033[0;34m"
NC="\\033[0m" # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

# Check if --fix flag is provided
FIX_MODE=false
if [[ "$1" == "--fix" ]]; then
    FIX_MODE=true
    print_warning "🔧 Running in fix mode - will auto-format files"
fi

print_step "🔍 Type checking TypeScript files..."
if ! npm run typecheck; then
    print_error "❌ TypeScript type checking failed!"
    exit 1
fi
print_success "✅ TypeScript types are valid"

if [[ "$FIX_MODE" == "true" ]]; then
    print_step "🎨 Auto-formatting code..."
    npm run format
    print_success "✅ Code formatted successfully"
else
    print_step "🎨 Checking code formatting..."
    if ! npm run format:check; then
        print_error "❌ Code formatting issues found!"
        print_warning "💡 Run check.sh --fix to auto-format"
        exit 1
    fi
    print_success "✅ Code formatting is consistent"
fi

print_success "🎉 All checks passed!"
