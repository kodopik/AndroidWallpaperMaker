#!/usr/bin/env bash
#
# AndroidWallpaperMaker
# v.1
# Automatically makes wallpapers for Android phones out of big pictures.
# ImageMagick is supposed to be installed.
#
# (c) Anton 'KodopiK' Konoplev, 2013
# kodopik@kodopik.ru

set -eo pipefail

HELP_LINES="-h|--help"

if [[ ${1} =~ ${HELP_LINES} ]]; then
  echo "Automatically makes wallpapers for Android phones out of big pictures."
  echo "Usage:"
  echo "  bash ./wallmaker.bash DIRECTORY"
  echo "DIRECTORY must contain subdirectories with pictures (JPEG or PNG)."
  exit 0
fi

declare -r QUALITY='92%'

# FILE 1:
# MediaInfo parameters.
#
# FORMAT:
# Image;%Width%x%Height%
# Video;%Width%x%Height%
#
# EXAMPLE:
# Image;%Width%x%Height%
# Video;%Width%x%Height%
declare -r MI_FILE='mediainfo.ini'

# FILEi 2:
# Screen sizes list.
#
# FORMAT:
# WidhtxHeight
#
# EXAMPLE:
# 240x320
declare -r SCR_FILE='screens.ini'

## DIRECTORY 1:
# Subdirs of this dir are the categories of pictures (Animals, Buildings, Landscapes etc.)
declare -r ORIG_DIR="$1"

function print_error()
{
  if [[ -z $1 ]]; then
    err_status=1
  else
    err_status=$1
  fi
  
  if [[ -z $2 ]]; then
    err_mess="Error"
  else
    err_mess=$2
  fi
  
  echo "${err_mess}"
  exit $err_status
}

test "$ORIG_DIR"    || print_error 2 "Directory not specified"
test -d "$ORIG_DIR" || print_error 3 "No such directory"
test -f "$MI_FILE"  || print_error 4 "File not found: ${MI_FILE}"
test -f "$SCR_FILE" || print_error 5 "File not found: ${SCR_FILE}"

#for Size in `cat "$SCR_FILE"`
cat "$SCR_FILE" | \
while read size; do
  x=`echo $size | awk -Fx '{ print 2*$1 }'` # Wallpaper width = double screen width
  y=`echo $size | awk -Fx '{ print $2 }'`   # Wallpaper height = screen height
  a=`echo "scale=4; $x / $y" | bc`          # Aspect ratio x:y

  scr_dir="${x}x${y}"
  test -d "$scr_dir" || mkdir "$scr_dir"

  for sub_dir in "${ORIG_DIR}/"*; do
    ScrCatDir=`basename "$sub_dir"`
    ScrCatDir="${scr_dir}/${ScrCatDir}"
    test -f "$ScrCatDir" && continue
    test -d "$ScrCatDir" || mkdir "$ScrCatDir"
    
    for file in "${sub_dir}/"*; do
      format=`mediainfo --Inform="General;%Format%" "$file"`
      test "$format" != "JPEG" -a "$format" != "PNG" && continue

      pic_size=`mediainfo --Inform="file://${MI_FILE}" "$file"`
      xp=`echo $pic_size | awk -Fx '{ print $1 }'`
      yp=`echo $pic_size | awk -Fx '{ print $2 }'`
      test $xp -lt $x -o $yp -lt $y && continue
      ap=`echo "scale=4; $xp / $yp" | bc`
      
      if [[ `echo "$a > $ap" | bc` -ne 0 ]]; then
        ypn=`echo "scale=0; $xp / $a" | bc`
        top=1
        crop=`echo "scale=0; ($yp - $ypn) / 2" | bc`
      else
        xpn=`echo "scale=0; $yp * $a" | bc`
        top=0
        crop=`echo "scale=0; ($xp - $xpn) / 2" | bc`
      fi
      
      file_name=`basename "$file"`
      file_name=${file_name%.*}
      out_file="${ScrCatDir}/${file_name}.jpg"

      if [[ $top -eq 1 ]]; then
        convert "$file" \
          -crop ${xp}x${ypn}+0+${crop} \
          -resize $scr_dir \
          -quality $QUALITY \
          "$out_file" \
          && echo -n "ok" \
          || echo -n "ERROR"
      else
        convert "$file" \
          -crop ${xpn}x${yp}+${crop}+0 \
          -resize $scr_dir \
          -quality $QUALITY \
          "$out_file" \
          && echo -n "ok" \
          || echo -n "ERROR"
      fi
      
      printf "\t\t(${out_file})\n";
    done
  done
done

echo "DONE"

exit 0
