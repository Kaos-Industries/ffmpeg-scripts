#!/bin/bash
set -e
if [ $# -lt 4 ]; then
  echo "Pass a link to a YouTube video, a start timestamp, an end timestamp and an output name."
  echo "Usage: `basename $0` https://www.youtube.com/watch?v=SCOKysMnH50 00:00:00.00 00:00:00.00 output.mkv"
  exit
else
{
  read -r video_url
  read -r audio_url
} < <(
  youtube-dl --get-url --youtube-skip-dash-manifest "$1"
)
start_time="$2"
end_time="$3"
ffmpeg -y -ss "$start_time" -to "$end_time" -i "$video_url" -ss "$start_time" -to "$end_time" -i "$audio_url" \
  -c:v libx264 -crf 17 -movflags +faststart -c:a copy -vsync 0 "$4"
fi

