#!/bin/bash
set -o errexit
set -o pipefail

if [ $# -lt 4 ]; then
  echo "Pass a link to a file, a start timestamp, an end timestamp and an output name."
  echo "Usage: $(basename "$0") /path/to/file.mp3 00:00:00.00 00:00:00.00 output.mp3"
  exit
else
start_time="$2"
end_time="$3"
ffmpeg  -ss "$start_time" -to "$end_time" -i "$1" -y -vsync 0 -c:a libfdk_aac "$4"
fi