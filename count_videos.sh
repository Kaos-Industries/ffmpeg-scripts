#!/bin/bash

# Needed because YouTube seems to be making it harder to count your own channel's videos with each redesign.

set -o errexit
set -o pipefail

usage() {
  echo
  echo "Pass a link to a YouTube channel to count the amount of videos it's uploaded."
  echo "usage: `basename $0` https://www.youtube.com/channel/UCBLYoY9ZMa4M7z6urJ5fHMg"
  echo " -h --help     Print this help."
  echo " -f --final    Disable the ultrafast preset to produce a final file."
  exit
}

if [ $# -lt 1 ]; then usage
elif command -v yt-dlp; then 
yt-dlp --flat-playlist "$1"
else
echo "This script requires YouTube-DLP: https://github.com/yt-dlp/yt-dlp"
exit
fi