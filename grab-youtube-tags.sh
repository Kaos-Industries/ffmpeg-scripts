#!/bin/bash
youtube-dl "$1" --skip-download --write-info-json | jq '.tags' "$1"