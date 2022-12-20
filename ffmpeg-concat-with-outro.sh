#!/bin/bash
set -o errexit
set -o pipefail

if [ $# -lt 2 ]; then
	echo "Pass a source file and an output name."
	echo "Usage: script.sh source.mp4"
exit
else
	for i in "$@"; do
	height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$i" | tr -d $'\r')
	ffmpeg -y -i "$i" -vf "scale=-2:'max(1080,ih)':flags=lanczos" -c:v libx264 -c:a libopus "intermediate.${i##*.}"
	echo "file intermediate.${i##*.}" > concat.txt &&
	echo "file outro.${i##*.}" >> concat.txt
	ffmpeg -y -f concat -safe 0 -i concat.txt -c copy "${i%.*}.${i##*.}"
	done
fi