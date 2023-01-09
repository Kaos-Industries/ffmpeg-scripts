#!/bin/bash
set -o errexit
set -o pipefail

watermark="D:\Users\Hashim\Documents\Projects\YouTube Channel 1\Meta\Watermark\Watermark.png"

err='\e[31m'
warn='\e[33m'
rc='\033[0m' # Reset colour

usage() {
	echo
	echo "Pass a source file and an output name."
	echo "usage: `basename $0` source.mp4 Final.mp4"
	echo " -h --help     Print this help."
	echo " -f --final    Disable the ultrafast preset to produce a final file."
	exit
}

if [ $# -lt 2 ]; then usage
else
	preset="-preset ultrafast"
	length1="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1" | tr -d $'\r')"
	length2="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 outro.mp4 | tr -d $'\r')"
	wmlength="$(echo $length1 - 5 | bc)"
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
	
	read -p "Enter fade duration in seconds: " -ei 2 fadeduration
	if ! [[ "$fadeduration" =~ ^[0-9]+$ ]] || [[ "$fadeduration" -eq 2 ]]; then 
		fadeduration=2 
		echo -e "${warn}Defaulting to $fadeduration seconds.${rc}"
	else echo "Using fade duration of $fadeduration."
	fi

	wmstream1="[2:v]lut=a=val*0.7,fade=in:st=15:d=3:alpha=1,fade=out:st=$wmlength:d=2:alpha=1[v2];"
	wmstream2="[v2][tmp2]scale2ref=w=oh*mdar:h=ih*0.07[wm_scaled][video];"
	read -e -n1 -p "Select watermark position:
1) Top right
2) Top left
3) Bottom left
4) No watermark
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
	ffmpeg -y -hide_banner -i "$1" -i "outro.mp4" -loop 1 -i "../Watermark/Watermark.png" \
	-movflags +faststart \
	$preset \
	-filter_complex \
	"color=black:1920x1080:d=$total[base];
	[0:v]setpts=PTS-STARTPTS[v0];
	[1:v]fade=in:st=0:d=$fadeduration:alpha=1,setpts=PTS-STARTPTS+(($fadetime)/TB)[v1];
	$wmstream1
	[v0]split[original][copy];
	[copy]scale=ih*16/9:-2,crop=h=iw*9/16,boxblur=lr=50:lp=2[blurred];
	[blurred][original]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2,scale=-2:1080[main];
	[base][main]overlay[tmp];
	[tmp][v1]overlay,setsar=1[tmp2];
	$wmstream2
	[video][wm_scaled]overlay=$wmpos:shortest=1:format=rgb[outv];
	[0:a]afade=out:st=$fadetime:d=$fadeduration[0a];
	[0a][1:a]concat=n=2:v=0:a=1[outa]" \
	-map "[outv]" -map "[outa]" -c:v libx264 -crf 17 -c:a libopus -pix_fmt yuv420p "$2"
	unset fadetime
fi

# gblur=sigma=70:steps=2
# smartblur=lr=5:ls=10


