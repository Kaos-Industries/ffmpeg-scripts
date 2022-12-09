#!/bin/bash
set -o errexit
set -o pipefail
shopt -s globstar # enable recursive globbing
shopt -s nocaseglob # make glob case-insensitive
shopt -s nullglob # make glob fail on non-matches instead of printing literal pattern
# looping through all videos in the dir removes the pain of tab-completing right-to-left filenames
for video in **/*.{webm,mp4,mkv}; do
  echo
  read -rp "Generate thumbnail from $video? [N/y]" -n 1
  if [[ $REPLY = [Yy] ]]; then
    echo
    read -rp "What timestamp should the thumbnail be generated from?"$'\n' timestamp
    ffmpeg -hide_banner -y -ss $timestamp -i "$video" -vf "scale=-2:'max(1080,ih)':flags=lanczos" -frames:v 1 -pred mixed "thumb.png" 
  exit
  fi
done
echo 
echo "No remaining videos found in the current directory."