#!/bin/bash

# Requires YouTube-DLP, more active and much more fully featured fork of YouTube-DL. YouTube-DL is effectively dead at this point.

set -o errexit
set -o pipefail

if [ $# -lt 4 ]; then
  echo "Pass a link to a YouTube video, a start timestamp, an end timestamp and an output name."
  echo "Usage: `basename $0` https://www.youtube.com/watch?v=SCOKysMnH50 00:00:00.00 00:00:00.00 output.mkv"
  exit
elif command -v yt-dlp; then
{
  read -r video_url
  read -r audio_url
} < <(
  yt-dlp --get-url --youtube-skip-dash-manifest "$1"
)
start_time="$2"
end_time="$3"
ffmpeg -y -ss "$start_time" -to "$end_time" -i "$video_url" -ss "$start_time" -to "$end_time" -i "$audio_url" \
  -c:v libx264 -crf 15 -movflags +faststart -c:a copy -vsync 0 "$4"
else 
echo "This script requires YouTube-DLP: https://github.com/yt-dlp/yt-dlp"
exit
fi