#!/bin/bash

[[ $1 ]] || id=$(wmctrl -l | awk '$2 >= 0 { print $1; exit }')

current_workspace=$(xdotool get_desktop)

#tiling_workspaces=$(sed -n '/^tiling/ s/[^0-9]*\(.\)[^0-9]*/\1\n/gp' \
#	~/.orw/scripts/spy_windows.sh | sort -n)
tiling_workspaces=$(sed -n '/^tiling/ s/.*(\s*\|\s*)//gp' \
	~/.orw/scripts/spy_windows.sh | tr ' ' '\n')

floating_workspace=$(comm -3 \
	<(wmctrl -d | cut -d ' ' -f 1) \
	<(echo -e "$tiling_workspaces") | head)

wmctrl -s $floating_workspace

#if [[ -z $id ]]; then
#if [[ true ]]; then
	fifo=/tmp/borders.fifo
	mkfifo $fifo

	~/.orw/scripts/set_geometry.sh -c size -w 120 -h 120
	alacritty -t get_borders --class=custom_size -e \
		/bin/bash -c "~/.orw/scripts/get_borders.sh > $fifo" &> /dev/null &

	read x_border y_border < $fifo
	rm $fifo
#else
#	read x_border y_border <<< $(~/.orw/scripts/get_borders.sh)
#fi

wmctrl -s $current_workspace
echo $x_border $y_border
