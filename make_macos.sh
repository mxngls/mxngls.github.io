#!/bin/bash

# overwrite defaults set for FreeBSD when working locally on macOS
make SYSTEM_LIBS='-lz -liconv -framework CoreFoundation -framework Security'
