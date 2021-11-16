select ans in "Top-right" "Top-left" "Bottom-left" "No watermark"; do
  while read -n1; do 
  PS3="Select watermark position: "
    case $ans in
    "Top-right")
        echo "WARNING: defaulting to top-right position."
        wmpos="W-w-50:50"
        wmstream3="[video][wm_scaled]overlay=$wmpos:format=auto:shortest=1[outv];"
        break
      ;;
    "Top-left")
    		echo "Positioning watermark at top-left."
    		wmpos="50:50"
    		wmstream3="[video][wm_scaled]overlay=$wmpos:format=auto:shortest=1[outv];"
        break
      ;;
    "Bottom-left")
    		echo "Positioning watermark at bottom-left."
    		wmpos="50:H-h-50"
    		wmstream3="[video][wm_scaled]overlay=$wmpos:format=auto:shortest=1[outv];"
        break
      ;;
    "No watermark")
    		echo "Disabling watermark."
    		unset wmstream1
    		unset wmstream2
    		wmstream3="[tmp2]setsar=1[outv];"
        break
      ;;
    *) 
      echo "Invalid option $REPLY"
      ;;
  esac
done 
done