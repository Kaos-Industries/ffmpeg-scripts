#!/bin/bash
set -e
if [ $# -lt 2 ]; then
	echo "Pass a source and an output name."
	echo "Usage: $(basename "$0") source.mp4 Final.mp4"
	exit
else
	# read -p "Enter target resolution [default: 1920x1080]: " res
	# if ! [[ "$res" =~ ^[0-9]+x[0-9]+$ ]]; then res=1920x1080 &&
	# 	echo "WARNING: defaulting to $res."
	# fi
	read -p "Enter fade duration in seconds: " -i 2 -e fadeduration
	if ! [[ "$fadeduration" =~ ^[0-9]+$ ]] || [[ "$fadeduration" -eq 2 ]]; then 
		fadeduration=2 
		echo "WARNING: defaulting to $fadeduration seconds."
	else echo "Using fade duration of $fadeduration"
	fi
	read -p "Start fade at custom time in first input? [y/N] " -n1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		while [[ -z "$fadetime" ]]; do
		echo
		read -p "Enter custom start time in seconds: " fadetime
	done
  fi
  output="$2"
  length1="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1")"
  length2="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 outro.mp4)"
	if [[ -z "$fadetime" ]]; then fadetime="$(echo "$length1" - "$fadeduration" | tr -d $'\r' | bc)" && 
		echo "Defaulting to adding fade -$fadeduration seconds from the first input, at $fadetime seconds." 
	fi
	ffmpeg -y -i "$1" -i "outro.mp4" -i "../Watermark/watermark4.png" \
	-movflags +faststart \
	-preset ultrafast \
	-filter_complex \
 "[0:v]scale=-2:'max(1080,ih)',settb=AVTB,fps=30/1[v0]; \
 	[2:v]lut=a=val*0.7[v2]; \
	[v2][v0]scale2ref=w=oh*mdar:h=ih/11[wm_scaled][main]; \
  [1:v]settb=AVTB,fps=30/1[outro]; \
	[main][outro]xfade=duration=$fadeduration:offset=$fadetime[video]; \
	[video][wm_scaled]overlay=W-w-50:50:format=auto:enable='between(t,0,(($length1-3)))'[overlayed]; \
	[0:a][1:a]acrossfade=d=$fadeduration[outa]" \
	-map "[overlayed]" -map "[outa]" -c:v libx264 -c:a libopus -crf 17 "$output"
	unset fadetime
fi

# format=rgba,fade=in:st=5:d=2:alpha=1,fade=out:st=150:d=2:alpha=1
# 50:50 			To position watermark top left, with x and y padding of 50
# W-w-50:50   To position watermark top right, with x and y padding of 50
# 50:H-h-50   To position watermark bottom left, with x and y padding of 50


