#!/bin/bash
set -o errexit
set -o pipefail
shopt -s globstar # enable recursive globbing
shopt -s nocaseglob # make glob case-insensitive
shopt -s nullglob # make glob fail on non-matches instead of printing literal pattern
for video in **/*.{webm,mp4,mkv}; do # looping through files is easier than tab-completing right-to-left filenames
  echo
  read -rp "Generate thumbnail from $video? [N/y]" -n 1
  if [[ $REPLY = [Yy] ]]; then
    echo
    read -rp "What timestamp should the thumbnail be generated from?"$'\n' timestamp
    ffmpeg -hide_banner -ss $timestamp -i "$video" -vf "scale=-2:'max(1080,ih)':flags=lanczos" -frames:v 1 "thumb.png" 
  exit
  fi
done
echo 
echo "No remaining videos found in the current directory."