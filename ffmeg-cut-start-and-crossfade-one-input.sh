#!/bin/bash
set -e
usage() {
  echo
  echo "Pass a source and an output name."
  echo "usage: $(basename "$0") source.mp4 Final.mp4"
  echo " -h --help        Print this help."
  echo " -f --final   Disable the ultrafast preset to produce a final file."
  exit
}
if [ $# -lt 2 ]; then usage
else
  preset="-preset ultrafast"
  length1="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1" | tr -d $'\r')"
  length2="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 outro.mp4 | tr -d $'\r')"
  wmlength="283"
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
  read -p "Enter fade duration in seconds: " -ei 2 fadeduration
  if ! [[ "$fadeduration" =~ ^[0-9]+$ ]] || [[ "$fadeduration" -eq 2 ]]; then 
    fadeduration=2 
    echo "WARNING: defaulting to $fadeduration seconds."
  else echo "Using fade duration of $fadeduration."
  fi
  wmstream1="[2:v]format=rgba,lut=a=val*0.7,fade=in:st=35:d=3,fade=out:st=$wmlength:d=3:alpha=1[v2];"
  wmstream2="[v2][tmp2]scale2ref=w=oh*mdar:h=ih*0.07[wm_scaled][video];"
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
  ffmpeg -y -i "$1" -i "outro.mp4" -loop 1 -i "../Watermark/Watermark.png" \
  -movflags +faststart \
  $preset \
  -ss 31.500 \
  -filter_complex \
  "color=black:16x16:d=$total[base];
  [0:v]scale=1920:-2,setpts=PTS-STARTPTS[v0];
  [1:v]scale=1920:-2,fade=in:st=0:d=$fadeduration:alpha=1,setpts=PTS-STARTPTS+((286)/TB)[v1];
  $wmstream1
  [base][v0]scale2ref[base][v0];
  [base][v0]overlay[tmp];
  [tmp][v1]overlay,setsar=1[tmp2];
  $wmstream2
  $wmstream3
  [0:a]afade=out:st=286:d=2[0a];
  [0a][1:a]acrossfade=d=$fadeduration[outa]" \
  -map "[outv]" -map "[outa]" -c:v libx264 -crf 17 -c:a libopus -shortest "$2"
  unset fadetime
fi