#!/usr/bin/env bash
set -x

ln -sf $(readlink -f profiles.yml) profiles.yml
pip3 install --user -r requirements.txt