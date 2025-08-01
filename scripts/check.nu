#!/usr/bin/env nu

npx prettier . -write --write --log-level=error
git ls-files ./scripts ./gpt ./tests | grep nu$ | lines | topiary format ...$in
./tests/run.nu
