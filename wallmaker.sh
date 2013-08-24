#!/bin/bash

## Automatically makes wallpapers for Android phones out of big pictures.
## ImageMagick is supposed to be installed.

HELP_LINES="-h|--help"

if [[ ${1} =~ ${HELP_LINES} ]]
then
  echo "Automatically makes wallpapers for Android phones out of big pictures."
  echo "Usage:"
  echo "  bash ${0} [DIRECTORY]"
  echo "[DIRECTORY] must contain subdirectories with pictures (JPEG or PNG only)."
  exit 0
fi

## FILE 1:
# MediaInfo parameters.
## FORMAT:
# Image;%Width%x%Height%
# Video;%Width%x%Height%
MInfoFile='mediainfo.ini'

## FILEi 2:
# Screen sizes list.
## FORMAT:
# WidhtxHeight
# e.g. 240x320
ScreensFile='screens.ini'

## DIRECTORY 1:
# Subdirs of this dir are the categories of pictures (Animals, Buildings, Landscapes etc.)
OrigDir="$1"

_ERR_()
{
	echo "$2"
	exit $1
}

test "$OrigDir" || _ERR_ 1 "Directory not specified"
test -d "$OrigDir" || _ERR_ 2 "No such directory"
test -f "$MInfoFile" || _ERR_ 3 "File not found: ${MInfoFile}"
test -f "$ScreensFile" || _ERR_ 4 "File not found: ${ScreensFile}"

#for Size in `cat "$ScreensFile"`
cat "$ScreensFile" | \
while read Size
do
	x=`echo $Size | awk -Fx '{ print 2*$1 }'` # Wallpaper width = double screen width
	y=`echo $Size | awk -Fx '{ print $2 }'`   # Wallpaper height = screen height
	a=`echo "scale=4; $x / $y" | bc`          # Aspect ratio x:y

	ScrDir="${x}x${y}"
	test -d "$ScrDir" || mkdir "$ScrDir"

	for SubDir in "${OrigDir}/"*
	do
		ScrCatDir=`basename "$SubDir"`
		ScrCatDir="${ScrDir}/${ScrCatDir}"
		test -f "$ScrCatDir" && continue
		test -d "$ScrCatDir" || mkdir "$ScrCatDir"
		
		for File in "${SubDir}/"*
		do
			Format=`mediainfo --Inform="General;%Format%" "$File"`
			test "$Format" != "JPEG" -a "$Format" != "PNG" && continue

			PicSize=`mediainfo --Inform="file://${MInfoFile}" "$File"`
			xp=`echo $PicSize | awk -Fx '{ print $1 }'`
			yp=`echo $PicSize | awk -Fx '{ print $2 }'`
			test $xp -lt $x -o $yp -lt $y && continue
			ap=`echo "scale=4; $xp / $yp" | bc`

			#if [[ $a -gt $ap ]]
			if [[ `echo "$a > $ap" | bc` -ne 0 ]]
			then
				ypn=`echo "scale=0; $xp / $a" | bc`
				top=1
				crop=`echo "scale=0; ($yp - $ypn) / 2" | bc`
			else
				xpn=`echo "scale=0; $yp * $a" | bc`
				top=0
				crop=`echo "scale=0; ($xp - $xpn) / 2" | bc`
			fi
			
			FileName=`basename "$File"`
			FileName=${FileName%.*}
			OutputFile="${ScrCatDir}/${FileName}.jpg"

			if [[ $top -eq 1 ]]
			then
				convert "$File" -crop ${xp}x${ypn}+0+${crop} -resize $ScrDir -quality 95% "$OutputFile" && echo -n "ok" || echo -n "ERROR"
			else
				convert "$File" -crop ${xpn}x${yp}+${crop}+0 -resize $ScrDir -quality 95% "$OutputFile" && echo -n "ok" || echo -n "ERROR"
			fi
			
			printf "\t\t(${OutputFile})\n";
		done
	done
done

echo "DONE"

exit 0

