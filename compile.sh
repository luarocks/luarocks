#!/bin/bash

cd src/luarocks

find . -type f -name '*.tl' -not -name '*.d.tl' -execdir tl gen '{}' \;
