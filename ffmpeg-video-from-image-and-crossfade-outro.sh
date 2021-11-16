#!/bin/bash
set -e
if [ $# -lt 2 ]; then
	echo "Pass an image input and an audio input."
	echo "Usage: `basename $0` image.jpg audio.flac"
	exit
else
	read -p "Enter target resolution [default: 1920x1080]: " res
	if ! [[ "$res" =~ ^[0-9]+x[0-9]+$ ]]; then res=1920x1080 &&
		echo "Defaulting to 1920x1080."
	fi
	read -p "Enter fade duration in seconds: " -i 2 -e fadeduration
	if [[ -z "$fadeduration" || "$fadeduration" -eq 2 ]]; then 
		fadeduration=2 
		echo "Defaulting to 2 seconds."
	fi
	read -p "Start fade at custom time in first input(s)? [y/N] " -n1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		while [[ -z "$fadetime" ]]; do
		echo
		read -p "Enter custom start time in seconds: " fadetime
	done
  fi
  img="$1"			# process the first argument and then remove it from the  
	shift					# arguments array before looping through the rest of it  
	for i in "$@"; do
	  length1="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$i")"
	  length2="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 outro.mp4)"
		if [[ -z "$fadetime" ]]; then fadetime="$(echo "$length1" - "$fadeduration" | tr -d $'\r' | bc)" && 
			echo "Defaulting to adding fade near the end of the first input." 
		fi
	 	total=$(echo "$length1 + $length2 - $fadeduration" | tr -d $'\r' | bc)
		ffmpeg -y -loop 1 -t 2 -i "$img" -i "$i" -i "outro.mp4" \
		-movflags faststart \
		-filter_complex \
		"color=black:$res:d=$total[base]; \
		[0:v]setpts=PTS-STARTPTS[v0]; \
		[2:v]format=yuva420p,fade=in:st=0:d=$fadeduration:alpha=1,setpts=PTS-STARTPTS+(($fadetime)/TB)[v1]; \
		[base][v0]overlay[tmp]; \
		[tmp][v1]overlay,format=yuv420p[fv]; \
		[1:a][2:a]acrossfade=d=$fadeduration[fa]" \
		-map [fv] -map [fa] -map -0:v:1 -map_metadata -1 -c:v libx264 -c:a libopus "${i%.*}.mp4"
		unset fadetime
	done
fi

# fade=in:st=0:d=2,scale=$res (0:v)
# acrossfade=d=$fadeduration