#!/usr/bin/bash

cd $(dirname $0)

nu -c 'source spawn.nu ; .tmp-spawn { source bootstrap.nu }'
