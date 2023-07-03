#!/bin/bash

get_time() {
	read seconds time <<< "$(date +"%S $time_format")"
}

check_time() {
	local actions_{start,end}
	set_time_actions

	while true; do
		#eval echo "TIME:$time_content"
		get_time
		#~/.orw/scripts/notify.sh "TIME: $time_format: $seconds, $time"
		#echo "TIME: $seconds, $time" >> time.log
		print_module time
		sleep $((60 - ${seconds#0}))
	done
}

set_time_actions() {
	actions_start='%{A:~/.orw/scripts/show_calendar.sh:}' actions_end='%{A}'
}

make_time_content() {
	[[ ! $args ]] &&
		time_format='%I:%M' ||
		time_format="$(sed 's/[[:alpha:]]/%&/g' <<< "${args//_/ }")"

	#[[ ${joiner_modules[$opt]} ]] ||
	#	local tpbg='$tpbg' tpfg='$tpfg'
	#time_content="\$time_padding$tpbg$tpfg\$time\$time_padding"
	[[ ${joiner_modules[$opt]} ]] &&
		local tpbg='$tpbg' tpfg='$tpfg' ||
		local tpbg='${cjsbg:-$tsbg}' tpfg='${cjsfg:-$tsfg}' \
		time_frame_start=$module_frame_start time_frame_end=$module_frame_end

	#time_content="\$time_padding$tpbg$tpfg\$time\$time_padding"
	time_content="\${cjpbg:-\$tpbg}\$time_padding\${cjpfg:-\$tpfg}\$time\$time_padding"
	time_content="$time_frame_start$time_content$time_frame_end"
	#time_content="$frame_start$time_content$frame_end"
	#~/.orw/scripts/notify.sh "TIME: $time_content"
	#~/.orw/scripts/notify.sh "TIME: $time_format: $(date +"%S $time_format")"
}
