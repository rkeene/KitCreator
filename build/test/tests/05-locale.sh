#! /bin/bash

unset $(locale | cut -f 1 -d =)
LANG="UTF-8"
export LANG
