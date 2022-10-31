#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

if [ $# -lt 2 ]; then
	echo "USAGE: Pass a video input and the desired output file."
	echo "Example: script.sh source.mp4"
exit
else
	for i in "$@"; do
	height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$i" | tr -d $'\r')
	if [ $height -ge 1080 ]; then
		echo ""\"$i\"" is at least 1080p: skipping upscaling stage" 
		echo -e "\nConforming to encoding parameters\n"
		ffmpeg -y -i "$i" -c:v libx264 -c:a libopus "intermediate.mp4"
	else
		echo ""\"$i\"" is too small: upscaling and conforming" 
		echo -e "\nUpscaling and conforming "\"$i\""\n"
		ffmpeg -y -i "$i" -vf "scale=-2:1080" -c:v libx264 -c:a libopus "intermediate.mp4"
	fi
	echo "file 'intermediate.mp4'" > concat.txt &&
	echo "file outro.mkv" >> concat.txt
	ffmpeg -y -f concat -safe 0 -i concat.txt -c copy "${i%.*}_named.mp4"   #  "$2" # "${i%.*}.${i##*.}"
	done
fi