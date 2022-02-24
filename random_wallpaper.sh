#!/bin/bash
THRESHOLD="35"               # Darkness threshold
CONDITION="-gt"              # Means lighter than
HEIC_TEMP="/tmp/rw_heic.bmp" # The temorary file for converted HEIC image
HISTORY_FILE="/tmp/rw_history"
MAX_HISTORY="1000"
DEBUG="0" # Debug
# Wallpapers resource paths
declare -a WALL_PATHS=(
  "$HOME/Pictures/Wallpapers"
  "$HOME/.local/share/wallpapers"
  "$HOME/.local/share/backgrounds"
  "/usr/share/wallpapers"
  "/usr/share/backgrounds"
)
# The excluded keywords in image path
declare -a EXCLUDE_KEYWORDS=(
  '*screenshot*' '*sceenshot*'
  '*1024*' '*1440*' '*1600*' '*1920*'
  '*kookkini*' '*sway*'
)

# Find a wallpaper brighter than some value.
n=0
while [ -z "$brightness" ] || ! test "${brightness%%.*}" $CONDITION $THRESHOLD; do
  if [ $((n++)) -gt 10 ]; then
    >&2 echo "Script error!"
    exit 1
  fi
  # Add exclude keywords
  # Excluded by the array
  exclude_arguements=()
  for exc in "${EXCLUDE_KEYWORDS[@]}"; do
    exclude_arguements+=("-not" "-iname" "$exc")
  done

  # Exclude repeat files in history
  while IFS='' read -r exc; do
    exclude_arguements+=("-not" "-path" "$exc")
  done < <(tail -$MAX_HISTORY /tmp/rw_history) 

  false
  if ! random_wall=$(find "${WALL_PATHS[@]}" -type f "${exclude_arguements[@]}" | shuf -n 1); then
    >&2 echo "Due to the settings, can't find required files."
    exit 1
  fi

  # Find Wallpaper's root path
  for wall_root_path in "${WALL_PATHS[@]}"; do
    if [[ "${random_wall}" = "$wall_root_path"* ]]; then
      wall_root_path=${wall_root_path%%/}
      break
    fi
  done

  # Continue if it isn't a image
  if file "$random_wall" | grep -qvi image; then
    continue
  fi

  # Process HEIC file
  if [ "${random_wall##*.}" = "heic" ]; then
    dunstify -r 143212 -t 120000 -i info "Loading..." "${random_wall#$wall_root_path/}"
    n=$(identify "$random_wall" | wc -l)
    rand=$(shuf -i 0-$((n - 1)))
    while IFS= read -r i; do
      convert "${random_wall}[$i]" "$HEIC_TEMP"
      brightness=$(convert "$HEIC_TEMP" -crop x10%+0+0 -colorspace gray -resize 1x1 txt:- \
        | grep -Po "(?<=graya\(|gray\()[^%,)]*")
      test $DEBUG = "1" && dunstify --icon=info "${random_wall##*/}[$i] brightness" "$brightness"
      if test "${brightness%%.*}" $CONDITION $THRESHOLD; then
        break
      fi
    done <<< "$rand"
    #dunstify --icon=info "${random_wall##*/} brightness" "$b"
  # For ather image type
  else
    brightness=$(convert "$random_wall" -crop x10%+0+0 -colorspace gray -resize 1x1 txt:- \
      | grep -Po "(?<=graya\(|gray\()[^%,)]*")
    test $DEBUG = "1" && dunstify --icon=info "${random_wall##*/} brightness" "$brightness"
    # Add record to history
    echo "$random_wall" >> $HISTORY_FILE
  fi
done

# Detect desktop environment
if [ "${random_wall##*.}" = "heic" ]; then
  bg_path=$HEIC_TEMP
  bg_name="${random_wall#$wall_root_path/}[$i]"
else
  bg_path=$random_wall
  bg_name="${random_wall#$wall_root_path/}"
fi
if [ "$XDG_CURRENT_DESKTOP" = "" ]; then
  desktop=$(echo "$XDG_DATA_DIRS" | sed 's/.*\(xfce\|kde\|gnome\).*/\1/')
else
  desktop=$XDG_CURRENT_DESKTOP
fi
desktop=${desktop,,} # convert to lower case

# Set Wallpaper
case $desktop in
  i3 | bspwm)
    dunstify --replace 143212 --icon="$random_wall" "Wallpaper switch to" "$bg_name"
    feh --conversion-timeout 5 --bg-fill -z "$bg_path"
    ;;
  kde)
    notify-send --icon="$random_wall" -h string:x-canonical-private-synchronous:random_wall "Wallpaper switch to" "$bg_name"
    #dunstify --replace 143289 --icon=info "Wallpaper brightness" "$brightness"
    cmd='var allDesktops = desktops();print (allDesktops);for (i=0;i<allDesktops.length;i++) {d = allDesktops[i];d.wallpaperPlugin = "org.kde.image";d.currentConfigGroup = Array("Wallpaper", "org.kde.image", "General");d.writeConfig("Image", "file://'"$bg_path"'/")}'
    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$cmd"
    ;;
esac

