#!/bin/bash

# Needed because YouTube seems to be making it harder to count your own channel's videos with each redesign.

set -o errexit
set -o pipefail

# Set a default channel to track
mychannel="https://www.youtube.com/channel/UCBLYoY9ZMa4M7z6urJ5fHMg"

usage() {
  echo
  echo "Pass a link to a YouTube channel to count the amount of videos it's uploaded, or add a default channel in the script to run without any arguments."
  echo "usage: `basename $0` [https://www.youtube.com/channel/UCBLYoY9ZMa4M7z6urJ5fHMg]"
  echo " -h --help     Print this help."
  echo " -f --final    Disable the ultrafast preset to produce a final file."
  exit
}

if command -v yt-dlp 1> /dev/null; then
if [ $# -ge 1 ]; then 
yt-dlp --flat-playlist $1
else yt-dlp --flat-playlist $mychannel
fi
echo "This script requires YouTube-DLP: https://github.com/yt-dlp/yt-dlp"
exit
fi