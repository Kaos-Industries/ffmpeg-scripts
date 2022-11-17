#!/bin/bash
set -o errexit
set -o pipefail

usage() {
  echo "Pass a source and a timestamp to grab a thumbnail from."
  echo "Usage: `basename $0` source.mp4 1:20"
  exit
}
if [ $# -lt 2 ]; then usage
fi
ffmpeg -ss "$2" -i "$1" -vf "scale=-2:'max(1080,ih)':flags=lanczos" -frames:v 1 "thumb.png" # -frames:v 10 -vsync vfr %02d.png
