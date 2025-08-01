#!/usr/bin/env nu

const p = path self

let command = $"use ($p | path dirname | path join '../tests/run.nu; run')"

npx prettier . -write --write --log-level=error
git ls-files ./scripts ./gpt ./tests | grep nu$ | lines | topiary format ...$in
nu -c $command
