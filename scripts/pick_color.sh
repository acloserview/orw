#!/bin/bash

pick_offset=$1

preview=/tmp/color_preview.png
colorctl=~/.orw/scripts/colorctl.sh

border=$(awk '/^x_border/ { print $NF }' ~/.config/orw/config)
read x y <<< $(~/.orw/scripts/windowctl.sh -p | awk '\
		{ print $3 + ($5 - 100) - '$border', $4 + ($2 - $1) + '$border' }')
		#BEGIN { b = '$border' } { print $3 + ($5 - 100) - b, $4 + ($2 - $1) - b }')

~/.orw/scripts/set_geometry.sh -t image_preview -x $x -y $y

while
	color=$(colorpicker -od)
	[[ $pick_offset ]] && color=$($colorctl -o $pick_offset -h $color)

	convert -size 100x100 xc:$color $preview
	feh -g 100x100 --title 'image_preview' $preview &

	read -srn 1 -p $'Keep color? [Y/n]\n' keep_color

	kill $! &> /dev/null

	[[ $keep_color == n ]]
do
	continue
done

rm $preview
echo $color
