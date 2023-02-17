#!/bin/bash
set -o errexit
set -o pipefail

watermark="D:\Users\Hashim\Documents\Projects\YouTube Channel 1\Meta\Watermark\Watermark.png"

err='\e[31m'
warn='\e[33m'
rc='\033[0m' # Reset colour

usage() {
	echo
	echo "Pass a source file and an output name. To crop, add optional start and end times."
	echo "usage: `basename $0` source.mp4 Final.mp4 [start_time] [end_time]"
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
	    break
	    ;;
		\?) 
			echo "$OPTARG is not a valid option."
			usage
			shift
			break
			;;    
		esac
		shift
	done

	if [ ! -z "$3" ]; then
		starttime="$3" 
		start_opt="-ss $3" 
		else 
		starttime=0
		start_opt=""
		fi 
		if [ ! -z "$4" ]; then
		endtime="$4" 
		end_opt="-to $4" 
		else 
		endtime="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$1" | tr -d $'\r')"
		end_opt=""
	fi
		
	read -p "Enter fade duration in seconds: " -ei 2 fadeduration
	if ! [[ "$fadeduration" =~ ^[0-9]+$ ]] || [[ "$fadeduration" -eq 2 ]]; then 
		fadeduration=2 
		echo -e "${warn}Defaulting to $fadeduration seconds.${rc}"
	else echo "Using fade duration of $fadeduration."
	fi

	# Preserve colour and prevent colour shifts by explicitly setting colour metadata
  height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "$1" | tr -d $'\r')
	colour_space=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_space -of default=nw=1:nk=1 "$1" | tr -d $'\r')
	if [[ $colour_space = "unknown" ]]; then
		echo -e "${err}Colorspace is unknown: setting metadata to safe default of BT601 (NTSC). Watch out for colour shifts and set manually if needed.${rc}" # BT601 is the most common for my (SD) video sources - change to BT701 if working with mostly HD sources.
		colour_metadata="-colorspace smpte170m -color_trc smpte170m -color_primaries smpte170m"
		elif [[ $height -lt "720" && $colour_space == "bt470bg" ]]; then # If input is standard definition and has BT.601 (PAL/SECAM) colorspace
		colour_metadata="-colorspace bt470bg -color_trc gamma28 -color_primaries bt470bg" # set all colour metadata to BT.601 (PAL/SECAM)
		elif [[ $height -lt "720" ]]; then # If input is standard definition and has any other colorspace
		colour_metadata="-colorspace smpte170m -color_trc smpte170m -color_primaries smpte170m" # set all colour metadata to BT.601 (NTSC)
		elif [[ $height -ge "720" ]]; then # If input is high definition
		colour_metadata="-colorspace bt709 -color_trc bt709 -color_primaries bt709" # set all colour metadata to BT.709
		else echo "${err}Weird colorspace $color_space detected, leaving colour metadata untouched.${rc}"
	fi

	length1="$(echo $endtime - $starttime | bc)"
	length2="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 outro.mp4 | tr -d $'\r')"
	wmlength="$(echo $length1 - 5 | bc)"	
	wmstream1="[2:v]lut=a=val*0.7,fade=in:st=15:d=3:alpha=1,fade=out:st=$wmlength:d=3:alpha=1[v2];"
	wmstream2="[v2][tmp2]scale2ref=w=oh*mdar:h=ih*0.07[wm_scaled][video];"
	read -e -n1 -p "Select watermark position:
1) Bottom left
2) Top left
3) Top right
4) Bottom right
" ans
	case $ans in
  1)  echo "Defaulting to bottom-left position."
      wmpos="80:H-h-50"
			;;
  2)  echo
			echo "Positioning watermark at top-left."
			wmpos="80:50"
		  ;;
  3)  echo
			echo "Positioning watermark at top-right."
			wmpos="W-w-80:50"
			;;
	4)  echo
			echo "Positioning watermark at bottom-right."
			wmpos="W-w-80:H-h-50"
			;;
  *)  echo -e "${warn}No option selected, defaulting to bottom-left position.${rc}"
			wmpos="80:H-h-50"
      ;;
	esac
	read -p "Start fade at custom time in first input? [y/N] " -n1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		while [[ -z "$fadetime" ]]; do
		echo
		read -p "Enter custom start time in seconds: " fadetime
		echo "Using custom fade time of -$fadeduration seconds from first input at $fadetime seconds".
	done
  fi
	if [[ -z "$fadetime" ]]; then fadetime="$(echo "$length1" - "$fadeduration" | tr -d $'\r' | bc)" && 
		echo -e "${warn}Defaulting to adding fade -$fadeduration seconds from first input, at $fadetime seconds.${rc}" 
	fi
 	total="$(echo "$length1 + $length2 - $fadeduration" | tr -d $'\r' | bc)"
	ffmpeg -y -hide_banner \
	$start_opt $end_opt -i "$1" -i "outro.mp4" -loop 1 -i "$watermark" \
	-movflags +faststart \
	$preset \
	-filter_complex \
	"color=black:1920x1080:d=$total[base];
	[0:v]setpts=PTS-STARTPTS[v0];
	[1:v]fade=in:st=0:d=$fadeduration:alpha=1,setpts=PTS-STARTPTS+(($fadetime)/TB)[v1];
	$wmstream1
	[v0]split=2[original][copy];
	[copy]scale=ih*16/9:-2,crop=h=iw*9/16,boxblur=lr=50:lp=1[blurred];
	[blurred][original]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2,scale=-2:1080[main];
	[base][main]overlay[tmp];
	[tmp][v1]overlay,setsar=1[tmp2];
	$wmstream2
	[video][wm_scaled]overlay=$wmpos:shortest=1:format=rgb[outv];
	[0:a]afade=out:st=$fadetime:d=$fadeduration[0a];
	[0a][1:a]concat=n=2:v=0:a=1[outa]" \
	-map "[outv]" -map "[outa]" -c:v libx264 -crf 15 -c:a libopus \
	-pix_fmt yuv420p $colour_metadata "$2"
	unset fadetime
fi

# gblur=sigma=70:steps=2
# smartblur=lr=5:ls=10


