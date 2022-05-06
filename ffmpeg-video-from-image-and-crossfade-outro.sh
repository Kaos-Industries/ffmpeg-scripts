#!/bin/bash
set -e
usage() {
	echo
	echo "Pass an image input and an audio input."
	echo "usage: `basename $0` frame.jpg audio.opus"
	echo " -h --help     Print this help."
	echo " -f --final    Disable the ultrafast preset to produce a final file."
	exit
}
if [ $# -lt 2 ]; then usage
else
	preset="-preset ultrafast"
	options=$(getopt -l "final,help" -o "fh" -a -- "$@")
	eval set -- "$options"
	while true
	do
		case $1 in
		-f|--final) 
		    preset=""
		    ;;
		-h|--help) 
		    usage
			shift
		    ;;
		--)
		    shift
		    break;;
		\?) 
			echo "$OPTARG is not a valid option."
			usage
			shift
			break;;    
		esac
		shift
	done
	read -p "Enter fade duration in seconds: " -i 2 -e fadeduration
	if [[ -z "$fadeduration" || "$fadeduration" -eq 2 ]]; then 
		fadeduration=2 
		echo "Defaulting to 2 seconds."
	fi
	read -p "Start fade at custom time in first input? [y/N] " -n1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		while [[ -z "$fadetime" ]]; do
		echo
		read -p "Enter custom start time in seconds: " fadetime
		echo "WARNING: using custom fade time of $fadetime seconds from first input.".
	done
  fi
  img="$1"			# process the first argument and then remove it from the  
	shift					# arguments array before looping through the rest of it  
	for i in "$@"; do
		length1="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1" | tr -d $'\r')"
		length2="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 outro.mp4 | tr -d $'\r')"
		if [[ -z "$fadetime" ]]; then fadetime="$(echo "$length1" - "$fadeduration" | tr -d $'\r' | bc)" && 
			echo "Defaulting to adding fade near the end of the first input."
		fi
	 	total=$(echo "$length1 + $length2 - $fadeduration" | tr -d $'\r' | bc)
		ffmpeg -y -loop 1 -t 2 -i "$img" -i "$i" -i "outro.mp4" \
		-preset ultrafast \
		-movflags faststart \
		-filter_complex \
		"color=black:1920x1080:d=$total[base];
		[0:v]fade=in:st=0:d=2,scale=-2:'max(1080,ih)',setpts=PTS-STARTPTS[v0];
		[2:v]fade=in:st=0:d=$fadeduration:alpha=1,setpts=PTS-STARTPTS+(($fadetime)/TB)[v2];
		[base][v0]overlay[tmp];
		[tmp][v2]overlay,format=yuv420p[fv];
		[1:a]afade=out:st=$fadetime:d=$fadeduration[1a];
		[1a][2:a]acrossfade=d=$fadeduration[fa]" \
		-map [fv] -map [fa] -map -0:v:1 -map_metadata -1 -c:v libx264 -c:a libopus "${i%.*}.mp4"
		unset fadetime
	done
fi

# concat=n=2:v=0:a=1