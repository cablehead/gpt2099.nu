#!/usr/bin/env nu

git ls-files ./scripts ./gpt ./tests | grep nu$ | lines | topiary format ...$in
