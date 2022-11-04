#!/bin/bash
set -o errexit
set -o pipefail

usage() {
	echo
	echo "Pass a source and an output name."
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
		    break;;
		\?) 
			echo "$OPTARG is not a valid option."
			usage
			shift
			break;;    
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
endtime="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1" | tr -d $'\r')"
end_opt=""
fi
length1="$(echo $endtime - $starttime | bc)"
length2="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 outro.mp4 | tr -d $'\r')"
wmlength="$(echo $length1 - 5 | bc)"	
	read -p "Enter fade duration in seconds: " -ei 2 fadeduration
	if ! [[ "$fadeduration" =~ ^[0-9]+$ ]] || [[ "$fadeduration" -eq 2 ]]; then 
		fadeduration=2 
		echo "WARNING: defaulting to $fadeduration seconds."
	else echo "Using fade duration of $fadeduration."
	fi
	wmstream1="[2:v]lut=a=val*0.7,fade=in:st=15:d=3:alpha=1,fade=out:st=$wmlength:d=3:alpha=1[v2];"
 	wmstream2="[v2][tmp2]scale2ref=w=oh*mdar:h=ih*0.06[wm_scaled][video];"
	read -e -n1 -p "Select watermark position:
1) Bottom left
2) Top left
3) Top right
4) No watermark
" ans
case $ans in
  1)  echo "Defaulting to bottom-left position."
      wmpos="80:H-h-50"
      wmstream3="[video][wm_scaled]overlay=$wmpos:shortest=1:format=auto[outv];"				
			;;
  2)  echo
			echo "Positioning watermark at top-left."
			wmpos="80:50"
			wmstream3="[video][wm_scaled]overlay=$wmpos:shortest=1:format=auto[outv];"
		  ;;
  3)  echo
			echo "Positioning watermark at top-right."
			wmpos="W-w-80:50"
			wmstream3="[video][wm_scaled]overlay=$wmpos:shortest=1:format=auto[outv];"
			;;
	4)  echo
			echo "Disabling watermark."
			unset wmstream1
			unset wmstream2
			wmstream3="[tmp2]setsar=1[outv];"
			;;
  *)  echo "WARNING: invalid option selected, defaulting to bottom-left position."
			wmpos="80:H-h-50"
			wmstream3="[video][wm_scaled]overlay=$wmpos:shortest=1:format=auto[outv];"
      ;;
	esac
	read -p "Start fade at custom time in first input? [y/N] " -n1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		while [[ -z "$fadetime" ]]; do
		echo
		read -p "Enter custom start time in seconds: " fadetime
		echo "WARNING: using custom fade time of $fadetime seconds from first input.".
	done
  fi
	if [[ -z "$fadetime" ]]; then fadetime="$(echo "$length1" - "$fadeduration" | tr -d $'\r' | bc)" &&
		echo "Defaulting to adding fade -$fadeduration seconds from first input, at $fadetime seconds." 
	fi
 	total="$(echo "$length1 + $length2 - $fadeduration" | tr -d $'\r' | bc)"
	ffmpeg -y	$start_opt $end_opt -i "$1" -i "outro.mp4" -loop 1 -i "../Watermark/Watermark.png" \
	-movflags +faststart \
	$preset \
	-filter_complex \
 	"color=black:16x16:d=$total[base];
	[0:v]scale=-2:'max(1080,ih)':flags=lanczos,setpts=PTS-STARTPTS[v0];
	[1:v]fade=in:st=0:d=$fadeduration:alpha=1,setpts=PTS-STARTPTS+(($fadetime)/TB)[v1];
	$wmstream1
	[base][v0]scale2ref[base][v0];
	[base][v0]overlay[tmp];
	[tmp][v1]overlay,setsar=1[tmp2];
	$wmstream2
	$wmstream3
	[0:a]afade=out:st=$fadetime:d=$fadeduration[0a];
	[0a][1:a]concat=n=2:v=0:a=1[outa]" \
	-map "[outv]" -map "[outa]" -c:v libx264 -crf 17 -c:a libopus "$2" 
	unset fadetime
fi

# loudnorm=I=-18 