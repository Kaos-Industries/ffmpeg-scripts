#!/bin/bash
set -e
usage() {
	echo
	echo "Pass two sources and an output name."
	echo "usage: $(basename "$0") source1.mp4 source2.mkv Final.mp4"
	echo " -h --help     Print this help."
	echo " -f --final    Disable the ultrafast preset to produce a final file."
	exit
}
if [ $# -lt 2 ]; then usage
else
	preset="-preset ultrafast"
	length1="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1" | tr -d $'\r')"
	length2="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$2" | tr -d $'\r')"
	length3="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 outro.mp4 | tr -d $'\r')"
	wmlength="$(echo $length2 - 5 | bc)"
	options=$(getopt -l "final,help" -o "fh" -a -- "$@")
	eval set -- "$options"
	while true
	do
		case "$1" in
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
	read -p "Enter first fade duration in seconds: " -ei 2 fadeduration1
	if ! [[ "$fadeduration1" =~ ^[0-9]+$ ]] || [[ "$fadeduration1" -eq 2 ]]; then 
		fadeduration1=2 
		echo "WARNING: defaulting duration of first fade to $fadeduration1 seconds."
	else echo "Setting first fade duration to $fadeduration1."
	fi
	read -p "Enter second fade duration in seconds: " -ei 2 fadeduration2
	if ! [[ "$fadeduration2" =~ ^[0-9]+$ ]] || [[ "$fadeduration2" -eq 2 ]]; then 
		fadeduration2=2 
		echo "WARNING: defaulting duration of second fade to $fadeduration2 seconds."
	else echo "Setting second fade duration to $fadeduration2."
	fi
	wmstream1="[3:v]lut=a=val*0.7,fade=in:st=10:d=3,fade=out:st=$wmlength:d=3[v3];"
 	wmstream2="[v3][video]scale2ref=w=oh*mdar:h=ih*0.08[wm_scaled][video];"
	read -e -n1 -p "Select watermark position:
1) Top right
2) Top left
3) Bottom left
4) No watermark
" ans
case $ans in
  1)  echo "Defaulting to top-right position."
      wmpos="W-w-100:80"
      wmstream3="[video][wm_scaled]overlay=$wmpos:format=auto:shortest=1[outv];"				
			;;
  2)  echo
			echo "Positioning watermark at top-left."
			wmpos="100:80"
			wmstream3="[video][wm_scaled]overlay=$wmpos:format=auto:shortest=1[outv];"
		  ;;
  3)  echo
			echo "Positioning watermark at bottom-left."
			wmpos="100:H-h-80"
			wmstream3="[video][wm_scaled]overlay=$wmpos:format=auto:shortest=1[outv];"
			;;
	4)  echo
			echo "Disabling watermark."
			unset wmstream1
			unset wmstream2
			wmstream3="[tmp2]setsar=1[outv];"
			;;
  *)  echo "WARNING: invalid option selected, defaulting to top-right position."
			wmpos="W-w-100:80"
			wmstream3="[video][wm_scaled]overlay=$wmpos:format=auto:shortest=1[outv];"
      ;;
	esac
	read -p "Start fade at custom time in first input? [y/N] " -n1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		while [[ -z "$fadetime1" ]]; do
		echo
		read -p "Enter custom start time for first input, in seconds: " fadetime1
		echo "Using custom fade time of -$fadeduration1 seconds from first input at $fadetime1 seconds".
	done
  fi
	if [[ -z "$fadetime1" ]]; then fadetime1="$(echo "$length1" - "$fadeduration1" | tr -d $'\r' | bc)"	
		echo "Defaulting to adding fade -$fadeduration1 seconds from first input at $fadetime1 seconds." 
	fi	
	read -p "Start fade at custom time in second input? [y/N] " -n1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		while [[ -z "$fadetime2" ]]; do
		echo
		read -p "Enter custom start time for second input, in seconds: " fadetime2
		echo "Using custom fade time of -$fadeduration2 seconds from second input at $fadetime2 seconds".
	done
  fi
	if [[ -z "$fadetime2" ]]; then fadetime2="$(echo "$length1 + $length2 - $fadeduration1 - $fadeduration2" | tr -d $'\r' | bc)"
		echo "Defaulting to adding fade -$fadeduration2 seconds from second input at $fadetime2 seconds." 
	fi
 	total="$(echo "$length1 + $length2 + $length3 - $fadeduration1 - $fadeduration2" | tr -d $'\r' | bc)"
	ffmpeg -y -i "$1" -i "$2" -i "outro.mp4" -loop 1 -i "../Watermark/Watermark.png" \
	-movflags faststart \
	$preset \
	-filter_complex \
	"color=black:16x16:d=$total[base];
	[0:v]scale=-2:'max(1080,ih)',setpts=PTS-STARTPTS[v0]; 
	[1:v]fade=in:st=0:d=$fadeduration1:alpha=1,setpts=PTS-STARTPTS+(($fadetime1)/TB)[v1]; 
	[2:v]fade=in:st=0:d=$fadeduration2:alpha=1,setpts=PTS-STARTPTS+(($fadetime2)/TB)[v2]; 
	[base][v0]scale2ref[base][v0];
	[base][v0]overlay[tmp]; 
	[tmp][v1]overlay[tmp2]; 
	[tmp2][v2]overlay,setsar=1[video]; 
	$wmstream1 
	$wmstream2 
	$wmstream3 
	[0:a][1:a]acrossfade=d=$fadeduration1,asetpts=PTS-STARTPTS[aud_tmp]; 
	[aud_tmp][2:a]acrossfade=d=$fadeduration2,asetpts=PTS-STARTPTS[outa]" \
	-map "[outv]" -map "[outa]" -c:v libx264 -crf 17 -c:a libopus -shortest "$3"
	unset fadetime1
	unset fadetime2
fi


# -r 25     needed or not?
