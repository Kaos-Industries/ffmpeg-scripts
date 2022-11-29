#!/bin/bash
set -o errexit
set -o pipefail

usage() {
  echo "Pass a source to grab a thumbnail from."
  echo "Usage: `basename $0` source.mp4"
  exit
}
if [ $# -lt 1 ]; then usage; fi
shopt -s globstar
shopt -s nocaseglob
for video in **/*.{webm,mp4,mkv}; do
  if [ -z "$video" ]; then
  echo "No matching videos found in the current directory." && 
  exit
  fi
  read -rp "Generate thumbnail from $video? [N/y] " -n 1
  if [[ $REPLY = [Yy] ]]; then
    echo
    read -rp "What timestamp should the thumbnail be generated from?"$'\n'
    ffmpeg -hide_banner -ss "$1" -i "$video" -vf "scale=-2:'max(1080,ih)':flags=lanczos" -frames:v 1 "thumb.png" 
  exit
  fi
done