#!/bin/bash

declare -A base_colors
base_colors=( [default]=0 [black]=1 [red]=2 [green]=3 [yellow]=4 [blue]=5 [magenta]=6 [cyan]=7 [white]=8 )

current_desktop=$(xdotool get_desktop)

colorschemes=~/.config/orw/colorschemes
all_colors=$colorschemes/colors

root=~/.orw

dotfiles=$root/dotfiles
config=$dotfiles/.config

bash_conf=$dotfiles/.bashrc
lock_conf=$config/i3lockrc
cava_conf=$config/cava/config
dunst_conf=$config/dunst/dunstrc
sxiv_conf=$config/X11/xresources
term_conf=$config/termite/config
rofi_conf=$config/rofi/theme.rasi
ncmpcpp_conf=$config/ncmpcpp/config
vim_conf=$config/nvim/colors/orw.vim
vifm_conf=$config/vifm/colors/orw.vifm
qb_conf=$config/qutebrowser/config.py
tmux_hidden_conf=$config/tmux/tmux_hidden.conf
tmux_conf=$config/tmux/tmux.conf
picom_conf=$config/picom/picom.conf

themes=$root/themes
gtk_conf=$themes/theme/gtk-2.0/gtkrc
ob_conf=$themes/theme/openbox-3/themerc
firefox_conf=$themes/firefox/userChrome.css
notify_conf=$themes/theme/xfce-notify-4.0/gtk.css

bar_conf=$root/scripts/bar/generate_bar.sh

update_colors=~/.orw/scripts/update_colors.sh
pick_color=~/.orw/scripts/pick_color.sh
colorctl=~/.orw/scripts/colorctl.sh

#                  
#       
icon=
icon="<span font='Iosevka Orw 12'>$icon   </span>"
icon=''

function assign_value() {
	[[ $2 && ! $2 =~ [-+][[:alnum:]]+ ]] && eval "$1=$2"
}

function log() {
	shift
	grep "$@" ~/.orw/colorschemes/.change_log
	exit
}

function get_color_properties() {
	color_properties="$(awk '\
		BEGIN { c = "'${1:-$color}'" }
		{
			cc = (c ~ /^[0-9]+$/) ? NR : (c ~ /^#/) ? $2 : $1
			if(cc == c) {
				print NR, $0
				exit
			}
		}' $all_colors)"

	[[ $color_properties ]] && read color_index color_name color <<< "$color_properties"
}

save_color() {
	local overwrite_color

	local var=${1-color}
	local var_name=${var}_name

	while [[ $(grep "^${!var_name} " $all_colors) && $overwrite_color != y ]]; do
		read -rsn 1 -p "${!var_name^^} is already defined, would you like to overwrite it? [y/N]"$'\n' overwrite_color

		[[ $overwrite_color == y ]] && sed -i "/^${!var_name} / s/#\w*$/#${!var: -6}/" $all_colors ||
			read -p 'Enter new color name: ' $var_name
	done

	[[ $overwrite_color != y || $add_color ]] && echo "${!var_name} ${!var}" >> $all_colors
	[[ $change_color_name ]] && sed -i "/^$existing_color /d" $all_colors

	eval ${var}_index=$(wc -l < $all_colors)
	$update_colors
}

function offset_color() {
	$colorctl -o ${2:-$offset} -h ${1:-$color}
}

function get_color() {
	color=${1:-$color}

	if [[ $color =~ ^(default|none)$ ]]; then
		 [[ ${2:-$offset} && ${inherited_module:-$module} =~ ^(tmux|vim)$ ]] && color=$(parse_module bg term)
	else
		get_color_properties

		property_to_check=${inherited_property:-$property}

		[[ $property_to_check && ${base_colors[${property_to_check#br_}]} && $colorscheme ]] &&
			color=$(awk '/^colors/ { print $('$color_index' + 1) }' $colorscheme)

		[[ ! $color =~ ^# ]] && echo "$color color doesn't exist, exiting.." && exit
	fi

	if [[ ${2:-$offset} ]]; then
		((${#color} > 8)) && local transparency_level_backup=${color:0:3}
		color=$(offset_color ${color: -6} ${2:-$offset})
		unset color_{index,name}
		get_color_properties
		[[ $transparency_level_backup ]] && color=$transparency_level_backup${color: -6}
	fi

	if [[ $transparency_level || $transparency_offset ]]; then
		#transparency_hex=$(([[ $edit_colorscheme ]] && cat $edit_colorscheme || get_$module) | \
		#	awk -Wposix '/^('${property//\*/\.\*}') / {
		#			c = $NF
		#			l = length(c)
		#			exit
		#		} END {
		#			tl = "'$transparency_level'"

		#			if(!tl) {
		#				if(length(tl)) tl = 0
		#				else {
		#					tl = (l && l > 7) ? sprintf("%d", "0x" substr(c, 2, 2)) : 255
		#					ntl = int(tl '$transparency_offset' * 2.55)
		#				}
		#			}

		#			t = ntl ? ntl : int(tl * 2.55)
		#			printf("%.2x\n", (t > 0) ? (t > 255) ? 255 : t : 0)
		#		}')

		#echo $color
		transparency_hex=$(awk -Wposix '{
				c = $0
				l = length(c)
				tl = "'$transparency_level'"

				if(!tl) {
					if(length(tl)) tl = 0
					else {
						tl = (l && l > 7) ? sprintf("%d", "0x" substr(c, 2, 2)) : 255
						ntl = int(tl '$transparency_offset' * 2.55)
						#system("~/.orw/scripts/notify.sh \"" pn "\"")
					}
				}

				t = ntl ? ntl : int(tl * 2.55)
				printf("%.2x\n", (t > 0) ? (t > 255) ? 255 : t : 0)
			}' <<< $color)

		#echo $transparency_hex
		#exit
		color="#$transparency_hex${color: -6}"
	fi
}

function parse_module() {
	([[ $colorscheme && ! $@ ]] && sed -n "/${inherited_module:-${module}}/,/^$/p" $colorscheme ||
		get_${2:-${inherited_module:-$module}}) | sed -n "s/^${1:-${inherited_property:-$property}} //p"
}

function ob() {
	reload_ob=true

	if [[ $property =~ ^i ]]; then
		local inactive=in
		property=${property:1}
	fi

	case $property in
		t) local pattern="\.${inactive}active.label.text";;
		tb)
			if [[ ! $whole_module ]]; then
				[[ $inactive ]] && local patterns=( "inactive.*border" ) || ( property=b && ob )
				local patterns+=( "\.${inactive}active.label.text" )
			fi

			local patterns+=( "\.${inactive}active.*title" )
			patterns+=( "\.${inactive}active.*button.*bg" )
			patterns+=( "\.${inactive}active.button.disabled.image" );;
		b)
			local patterns=( "\.${inactive}active.*border" )

			if [[ ! $whole_module ]]; then
				patterns+=( "\.${inactive}active.\(client\|handle\|grip\)" )
				[[ $inactive ]] || patterns+=( "osd.\(bg\|label\|button\).*color" )
			fi;;
		c) local pattern="\.${inactive}active.client";;
		*bt*)
			if [[ $shade_offset ]]; then
				local shade=$(offset_color "${color: -6}" $shade_offset)
				property+=h
				ob
			fi

			[[ $property =~ h$ ]] && local hover='\(.hover\|\.pressed\)'

			case $property in
				c*) local pattern="close${hover-.unpressed}";;
				ma*) local pattern="max${hover-.unpressed}";;
				mi*) local pattern="iconify${hover-.unpressed}";;
				*) local pattern="\.${inactive}active.*${hover-unpressed}.image";;
			esac;;
		mbg)
			gtk
			local patterns=( '^menu.border' )
			patterns+=( '^menu.items.bg' )
			patterns+=( '^menu.separator' );;
		mfg)
			gtk
			local pattern='^menu.items.text';;
		mtbg) local pattern='^menu.title.bg';;
		mtfg) local pattern='^menu.title.text';;
		msbg)
			gtk
			local pattern='^menu.*active.bg';;
		msfg)
			gtk
			[[ ! $whole_module ]] && property=bsfg && ob
			local pattern='^menu.*active.text';;
		mb)
			[[ ! $whole_module ]] && property=mtbg && ob
			local pattern='menu.border';;
		ms) local pattern='^menu.separator';;
		bfg) local pattern='bullet.image';;
		bsfg) local pattern='bullet.selected.image';;
		osd) local pattern='osd.\(bg\|label\|button\).*color';;
		osdh) local pattern='osd.hilight';;
		osdu) local pattern='osd.unhilight';;
		s)
			read red green blue <<< $($colorctl -cps ' ' -h ${new_color:-$color})

			awk -i inplace \
				'/shadow-(red|green|blue)/ {
					if(/red/) c = '$red'
					else if(/green/) c = '$green'
					else c = '$blue'

					sub(/[0-9.]+/, c / 255)
				} { print }' $picom_conf

			return
	esac

	color=${shade:-$color}

	for p in ${patterns[*]:-$pattern}; do
		sed -i "/$p/ s/#.*/#${color: -6}/" $ob_conf
	done
}

function gtk() {
	folder() {
		flat() {
			[[ $1 == fill ]] && local pattern='"fill:' || local pattern='opacity:.;[^#]*\|;fill:\|color:'
			sed -i "s/\($pattern\)#\w\{6\}/\1${2:-$color}/g" ~/.orw/themes/icons/{16x16,48x48}/$folders_flat/*
		}

		papirus() {
			if [[ $1 == fill ]]; then
				exp='\(.*\)#\w*/\1'
				local pattern='/width="50"\|circle.*;/'
			else
				exp='#\w*/'
				local pattern='/opacity\|width="[45][0-9]"/!'
			fi

			sed -i "$pattern s/$exp${2:-$color}/" ~/.orw/themes/icons/{16x16,48x48}/$folders_papirus/*
		}

		[[ $(ls -d ~/.icons/orw/48x48/folders_*) =~ flat ]] &&
			folders_flat=folders_flat folders_papirus=folders ||
			folders_flat=folders folders_papirus=folders_papirus

		[[ $1 == fill ]] && folder_property=ff || folder_property=fs
		current_color=$(parse_module $folder_property)

		if [[ $current_color != ${2:-$color} ]]; then
			flat $@
			papirus $@
		fi
	}

	case $property in
		fc)
			folder fill $(offset_color "#${color: -6}" ${shade_offset-+40})
			folder stroke $(offset_color "#${color: -6}" ${secondary_shade_offset--30});;
		ff) folder fill;;
		fs) folder stroke;;
		*)
			#if [[ $property == active ]]; then
			#	[[ $(which convert) ]] &&
			#		convert -size 2x2 xc:\#${color: -6} ${gtk_conf%/*}/apps/assets/underline.png
			#		exit
			#fi
			if [[ $property == active && $(which convert) ]]; then
				convert -size 2x2 xc:$color ${gtk_conf%/*}/apps/assets/active.png
				convert -size 2x2 xc:$(offset_color $color ${secondary_shade_offset-+30}) ${gtk_conf%/*}/apps/assets/hover.png
			fi

			sed -i "/\<${property}_color\>/ s/#\w\{6\}/#${color: -6}/" $gtk_conf
	esac
}

function dunst() {
	reload_dunst=true

	[[ $property =~ ^c ]] &&
		urgency=critical property=${property:1}

	case $property in
		bg) local pattern=background;;
		fg) local pattern=foreground;;
		fc) local pattern=frame_color;;
		*)
			sed -i "/^$property/ s/#\w*/#${color: -6}/" ~/.orw/scripts/notify.sh
	esac

		[[ $pattern ]] && sed -i "/urgency_${urgency:-normal}/,/^$/ { /$pattern/ s/#\w*/#${color: -6}/ }" ${dunst_conf%/*}/*

	#if [[ $property == pbfg ]]; then
	#	sed -i "/^pbe\?fg/ s/#\w*/#${color: -6}/" ~/.orw/scripts/notify.sh
	#else
	#	[[ $property =~ ^c ]] && urgency=critical property=${property:1}

	#	#case $property in
	#	#	*bg) local pattern=background;;
	#	#	*fg) local pattern=foreground;;
	#	#	*fc) local pattern=frame_color;;
	#	#	*)
	#	#esac

	#	case $property in
	#		bg) local pattern=background;;
	#		fg) local pattern=foreground;;
	#		fc) local pattern=frame_color;;
	#		*)
	#	esac

	#	sed -i "/urgency_${urgency:-normal}/,/^$/ { /$pattern/ s/#\w*/#${color: -6}/ }" ${dunst_conf%/*}/*
	#fi
}

function term() {
	reload_term=true

	case $property in
		bg)
			if [[ $transparency ]]; then
				read term_transparency term_pattern <<< $(awk -Wposix '{
						tl = sprintf("%d", "0x" $0)
						printf("%.2f [0-9.]\\\\+", tl / 255)
					}' <<< ${color:1:2})
			fi

			rgb=$($colorctl -c -h "#${color: -6}")
			sed -i "/^background/ s/\([0-9,]\+\),$term_pattern/$rgb$term_transparency/" $term_conf;;
			#sed -i "/^background/ s/\([0-9,]\+\),/$rgb/" $term_conf;;
		fg) sed -i "/^foreground/ s/#.*/#${color: -6}/" $term_conf;;
		colors)
			awk -i inplace 'NR == FNR { a[ci++] = $1; next } \
				{ if(/^color[0-9]/) { rci = int(substr($1, 6)); if(rci < ci) $NF = a[rci] } \
				else if($1 ~ /^(br_)?('$(tr " " "|" <<< ${!base_colors[*]})')$/) $NF = a[FNR - 1]; print }' \
					<(for color in $color; do echo $color; done) $term_conf $all_colors 2> /dev/null;;
		*)
			new_color=$color

			for terminal_color in $(awk '/^('${property//\*/.*}')/ && NR < 17 { print $1 }' $all_colors); do
				get_color_properties $terminal_color

				sed -i "/^color$((color_index - 1)) / s/#\w*/#${new_color: -6}/" $term_conf
				sed -i "${color_index}s/#\w*/#${new_color: -6}/" $all_colors
			done
	esac
}

function vim() {
	reload_vim=true
	[[ $color =~ ^\# ]] && local color="#${color: -6}"
	sed -i "/^let [gs]:$property / s/'.*'/'$color'/" $vim_conf
}

function vifm() {
	reload_vifm=true
	get_color_properties

	#[[ $color =~ \# ]] && local color=$((color_index - 1 ))
	#sed -i "/^let \$$property / s/\w*$/$color/" $vifm_conf

	awk -i inplace '{ if(/let \$'$property'/ && ! d++)
			sub("[^ ]?\\w+.?$", ("'$color'" ~ "^#") ? '$color_index' - 1 : "'\''default'\''")
		print }' $vifm_conf
}

get_bar_configs() {
	if [[ -z $bar_configs ]]; then
		bar_configs_path=$config/orw/bar/configs
		bar_configs=$(awk -F '=' '/^last_running/ {
			split($NF, ab, ",")
			for(bi in ab) printf "%s ", "'"$bar_configs_path/"'" ab[bi] }' ~/.orw/scripts/barctl.sh)

		bar_colorschemes=$(awk '{
				c = gensub(/.*-c ([^ ]{3,}) .*/, "\\1", 1)

				if(cp !~ c) {
					aca[++ci] = c
					cp = cp "," c
				}
			} END { for(ci in aca) printf "%s ", "'"$colorschemes"'/" aca[ci] ".ocs "
		}' $bar_configs)
	fi
}

function bar() {
	reload_bar=true
	#bar_modules=${bar_conf%/*}/module_colors
	get_bar_configs

	if [[ $transparency ]]; then
		((${#color} > 7)) && local hex_range=8 ||
			local hex_range=6 pattern='\(#\w*\)\w\{6\}' group='\1'
	else
		local hex_range=6
	fi

	#local default_bar_configs="$bar_conf $bar_modules"




	#new approach - affect currently used colorschemes
	#sed -i "/^$property/ s/${pattern:-#\w*}/${group:-#}${color: -$hex_range}/" $bar_colorschemes

	[[ $whole_module ]] || local containing_files=$(grep -l "^$property" $bar_colorschemes | xargs)

	if [[ $containing_files || $whole_module ]]; then
		sed -i "/^$property/ s/${pattern:-#\w*}/${group:-#}${color: -$hex_range}/" ${containing_files:-$bar_colorschemes}
	else
		for bar_colorscheme in $bar_colorschemes; do
			echo "$property #${color: -$hex_range}" >> $bar_colorscheme
		done
	fi

	#exit

	#if sed -n "/^$property/ s/${pattern:-#\w*}/${group:-#}${color: -$hex_range}/p" $bar_colorschemes; then
	#	echo exist
	#else
	#	for bar_colorscheme in $bar_colorschemes; do
	#		echo "$property #${color: -$hex_range}" $bar_colorscheme
	#	done
	#fi




	##if [[ $(grep "^${property}" $bar_conf $bar_modules) ]]; then
	#if [[ $(eval grep "^${property}" "${edit_colorscheme:-$default_bar_configs}") ]]; then
	#	eval "sed -i '/^$property/ s/${pattern:-#\w*}/${group:-#}${color: -$hex_range}/' ${edit_colorscheme:-$default_bar_configs}"
	#	#echo $property $color "${edit_colorscheme:-$default_bar_configs}"
	#else
	#	if [[ $edit_colorscheme ]]; then
	#		echo "$property #${color: -$hex_range}" >> $edit_colorscheme
	#	else
	#		color_type=${property: -2:1}
	#		[[ $property =~ [bf]g$ ]] && local color_format="%{${color_type^}#${color: -$hex_range}}"
	#		echo "$property=\"${color_format:-#${color: -$hex_range}}\"" >> $bar_modules
	#	fi

	#	#echo "$property=\"${color_format:-#${color: -$hex_range}}\"" >> ${edit_colorscheme:-$bar_modules}
	#	#echo $property $color ${edit_colorscheme:-$bar_modules}
	#fi
}

check_ncmpcpp_mode() {
	[[ $ncmpcpp_mode ]] ||
		ncmpcpp_mode=$(awk '/^song_list/ { print /[0-9]+/ ? "dual" : "single" }' $ncmpcpp_conf)
}

function ncmpcpp() {
	reload_ncmpcpp=true
	get_color_properties

	if ((color_index)); then
		case $property in
			[at]c)
				check_ncmpcpp_mode
				[[ $ncmpcpp_mode != dual ]] && ~/.orw/scripts/toggle.sh ncmpcpp -r no
				ncmpcpp_mode=dual

				[[ $property == ac ]] && local property_index=1 || local property_index=2

				local pattern='^song_list';;
			ec) local pattern='empty';;
			c2) local pattern='color_2';;
			pc) local pattern='progressbar_color';;
			etc) local pattern='empty_tag_color';;
			pec) local pattern='progressbar_elapsed_color';;
			npp) local pattern='now_playing_prefix';;
			vc)
				local pattern='visualizer_color'
				local old_color_index=$(sed -n "/^#/! s/visualizer_color[^0-9]*\([0-9]\+\).*/\1/p" $ncmpcpp_conf)

				[[ -f $cava_conf ]] && sed -i "/^foreground\|color_1/ s/'.*'/'$color'/" $cava_conf;;
			*)
				case $property in
					sc) local pattern='^header\|volume\|statusbar';;
					mc) local pattern='main\|^[^n].*prefix';;
					*) local pattern='selected_item';;
				esac
		esac

		sed -i "/${pattern:-$property}/ s/\<${old_color_index-[0-9]\+}\>/$color_index/${property_index-g}" $ncmpcpp_conf*
	else
		error_message='Provided color is not defined, please save it under some label.'
		echo $error_message
		$root/scripts/notify.sh -p "$icon <b>$error_message</b>" &
	fi
}

function tmux() {
	reload_tmux=true

	#if [[ $property =~ ^(bg|mc) ]]; then
	if [[ $property =~ ^(b[cg]|mc) ]]; then
		reload_tmux_hidden=true
		local hidden=$tmux_hidden_conf
	fi

	[[ $color =~ ^\# ]] && local color="#${color: -6}"
	
	sed -i "/^$property=/ s/'.*'/'$color'/" $tmux_conf $hidden
}

function rofi() {
	#sed -i "/^\s*$property:/ s/ [^;]*/ #${color: -6}/" $rofi_conf
	sed -i "/^\s*$property:/ s/\w\{6\};/${color: -6};/" $rofi_conf

	[[ ! $whole_module && $property == bg ]] && property=".*bt.*c\|tbg" && rofi

	if [[ $property == ibg ]]; then
		#border_width=$(awk '/^\sborder/ { print gensub(/.* ([0-9]*).*/, "\\1", 1); exit }' $rofi_conf)
		#border_width=$(awk '/window-border:/ { print gensub(/.* ([0-9]+).*/, "\\1", 1) }' ~/.config/rofi/list.rasi)
		#border_width=$(awk '$1 == "window-border:" {
		#	print gensub(/.* ([0-9]+).*/, "\\1", 1) }' ~/.config/rofi/theme.rasi)
		read rofi_bg rofi_bc border_width <<< $(awk -F '[ ;]' \
				'/^\s*b[cg]/ { print $(NF - 1) }
				/window-border:/ { print gensub(/.* ([0-9]+).*/, "\\1", 1) }' $rofi_conf | xargs)

		if [[ $rofi_bg != $rofi_bc ]]; then
			[[ "#${color: -6}" == $rofi_bg ]] && input_border=$border_width padding=20 margin=10 ln=12
			[[ "#${color: -6}" == $rofi_bc ]] && input_border=0 padding=0 element_padding=10 margin=0 ln=8

			if [[ $padding && $margin ]]; then
				#~/.orw/scripts/borderctl.sh -c list rln $ln
				#~/.orw/scripts/borderctl.sh -c list rim $margin
				#~/.orw/scripts/borderctl.sh -c list rwp $padding
				#~/.orw/scripts/borderctl.sh -c list ribw $input_border
				#~/.orw/scripts/borderctl.sh -c list rip ${item_padding-3 5}

				#echo $input_border $padding $element_padding $margin $ln

				awk -i inplace '{
					if ($1 == "lines:") { sub(/[0-9]+/, '$ln') }
					else if($1 ~ "-padding:") {
						if($1 ~ "(element|input)" && ! "'$element_padding'") {
							sub(/([0-9]+px ?){2}/, "3px 5px")
						} else {
							gsub(/[0-9]+/, ($1 ~ "window") ? '$padding' : '${element_padding:-0}')
						}
					} else if ($1 ~ "^input-[^p]") {
						v = ($1 ~ "margin") ? '$margin' : '$input_border'
						sub(/[0-9]+px/, v "px")
					}
				}
				{ print }' ~/.config/rofi/list.rasi
			fi
		fi
	fi
}

function bash() {
	reload_bash=true

	awk -i inplace '{ \
		if(/^\s*'$property'=/) {
			#c = ("'$color'" ~ /^#/) ? sprintf("%d;%d;%d;", 0x'${color:1:2}', 0x'${color:3:2}', 0x'${color:5:2}') : "'$color'"
			#sub("[0-9;]+", c)

			c = ("'$color'" ~ /^#/) ? sprintf("%d;%d;%d;", 0x'${color: -6:2}', 0x'${color: -4:2}', 0x'${color: -2:2}') : "'$color'"
			sub(/".*"/, "\"" c "\"")
		}
		print
	}' $bash_conf
}

function fff() {
	case $property in
		st*) col=2;;
		dir*) col=1;;
		cur*) col=4;;
		sel*) col=3;;
	esac

	#col_index=${base_colors[${color_name#br_}]}
	#((!col_index)) && col_index=9

	sed -i "/FFF_COL$col/ s/[0-9]$/$((col_index - 1))/" $fff_conf

	#export FFF_COL$col=$((col_index - 1))
}

function qb() {
	reload_qb=true
	sed -i "/\(^\|--\)$property/ s/#\w*/#${color: -6}/" $qb_conf ${qb_conf%/*}/home.css
}

function firefox() {
	sed -i "/--$property:/ s/#\w\{6\}/$color/" $firefox_conf
}

function wall() {
	~/.orw/scripts/xwallctl.sh -s "$color"
}

function sxiv() {
	reload_sxiv=true
	sed -i "/Sxiv.${property:0:1}/ s/#\w*/#${color: -6}/" $sxiv_conf
}

function lock() {
	if ((${#color} > 7)); then
		color="${color: -6}${color:1:2}"
	else
		[[ $transparency ]] && local color_range='\{6\}' || color+=ff
	fi

	sed -i "s/\(^$property\)=\w${color_range-*}/\1=${color#\#}/" $lock_conf
}

function get_ob_property() {
	sed -n "/$1.*#/ s/[^#]*//p" $ob_conf
}

function get_ob() {
	get_buttons() {
		[[ $1 == hover ]] && hover=h state=hover || state=unpressed

		echo cbt$hover $(get_ob_property ".*\.close.$state")
		echo mabt$hover $(get_ob_property ".*\.max.$state")
		echo mibt$hover $(get_ob_property ".*\.iconify.$state")
	}

	awk -F '[ ;]' '{
		i = (/inactive/) ? "i" : ""
		if(/.*active.label.text.*#/) print i "t", $NF
		else if(/.*active.*title.bg.*#/) print i "tb", $NF
		else if(/.*active.*border.*#/) print i "b", $NF
		else if(/.*active.client.*#/) print i "c", $NF
		else if(/button.*(close|iconify|max).(unpressed|hover).*#/) {
			h = (/hover/) ? "h" : ""
			
			if(/close/) print "cbt" h, $NF
			if(/iconify/) print "mibt" h, $NF
			if(/max/) print "mabt" h, $NF
		}
		else if(/.*\.inactive.*unpressed.*image.*#/) print "ibt", $NF
		else if(/.*\.inactive.*hover.*image.*#/) print "ibth", $NF
		else if(/^menu.items.bg.*#/) print "mbg", $NF
		else if(/^menu.items.text.*#/) print "mfg", $NF
		else if(/^menu.title.bg.*#/) print "mtbg", $NF
		else if(/^menu.title.text.*#/) print "mtfg", $NF
		else if(/^menu.*active.bg.*#/) print "msbg", $NF
		else if(/^menu.*active.text.*#/) print "msfg", $NF
		else if(/menu.border.*#/) print "mb", $NF
		else if(/^menu.separator.*#/) print "ms", $NF
		else if(/.*bullet.image.*#/) print "bfg", $NF
		else if(/.*bullet.selected.image.*#/) print "bsfg", $NF
		else if(/^osd.bg.color.*#/) print i "osd", $NF
		else if(/^osd.hilight.*#/) print i "osdh", $NF
		else if(/^osd.unhilight.*#/) print i "osdu", $NF
		else if(/^shadow-(red|green|blue)/) rgb = rgb sprintf("%.2x", sprintf("%.0f", $(NF - 1) * 255))
		} END { print "s #" rgb }' $ob_conf $picom_conf

		#read red green blue <<< $(awk -F '[ ;]' '/^shadow-(red|green|blue)/) {
		#	rgb = rgb " " int($(NF - 1) * 255)
		#} END { print rgb }' $picom_conf)

	#cat <<- EOF
	#	t $(get_ob_property '.*\.active.label.text')
	#	tb $(get_ob_property '.*\.active.*title.bg')
	#	b $(get_ob_property '.*\.active.*border')
	#	c $(get_ob_property '.*\.active.client')
	#	it $(get_ob_property '.*inactive.label.text')
	#	itb $(get_ob_property '.*\.inactive.*title.bg')
	#	ib $(get_ob_property '.*\.inactive.*border')
	#	ic $(get_ob_property '.*\.inactive.client')
	#	$(get_buttons)
	#	$(get_buttons hover)
	#	ibt $(get_ob_property '.*\.inactive.*unpressed.*image')
	#	ibth $(get_ob_property '.*\.inactive.*hover.*image')
	#	mbg $(get_ob_property '^menu.items.bg')
	#	mfg $(get_ob_property '^menu.items.text')
	#	mtbg $(get_ob_property '^menu.title.bg')
	#	mtfg $(get_ob_property '^menu.title.text')
	#	msbg $(get_ob_property '^menu.*active.bg')
	#	msfg $(get_ob_property '^menu.*active.text')
	#	mb $(get_ob_property 'menu.border')
	#	ms $(get_ob_property '^menu.separator')
	#	bfg $(get_ob_property '.*bullet.image')
	#	bsfg $(get_ob_property '.*bullet.selected.image')
	#	osd $(get_ob_property '^osd.bg.color')
	#	osdh $(get_ob_property '^osd.hilight')
	#	osdu $(get_ob_property '^osd.unhilight')
	#EOF
}

function get_gtk() {
	if [[ $(ls -d ~/.icons/orw/48x48/folders_*) =~ flat ]]; then
		sed -n 's/.*\(#\w*\).*width="50".*/ff \1/p' ~/.icons/orw/48x48/folders/folder.svg
		sed -n '/opacity/! s/.*\(#\w*\).*d=.*/fs \1/p' ~/.icons/orw/48x48/folders/folder.svg
	else
		sed -n 's/^[^:]*:\(#.\w*\).*\(#\w*\).*/ff \1\nfs \2/p' ~/.icons/orw/48x48/folders/folder.svg
	fi

	sed -n '/ms\?[bf]g\|text\|link\|panel/! s/^.*"\(.*\)_color\>:.*\(#\w\+\).*/\1 \2/p' $gtk_conf
}

function get_dunst() {
	awk -F '"' '/urgency_normal/ { nr = NR }; { if(nr && NR > nr) \
		{ if($0 ~ /background/) print "bg", $2; \
		else if(/foreground/) print "fg", $2; \
		else if(/frame/) { print "fc", $2; exit } } }' ${dunst_conf%/*}/dunstrc
	awk '/^\w*[bf]g/ { print gensub("(.*)=.*(#\\w*).*", "\\1 \\2", 1) }' ~/.orw/scripts/notify.sh
	#awk '/^pbfg/ { print gensub("(.*)=.*(#\\w*).*", "\\1 \\2", 1) }' ~/.orw/scripts/notify.sh
}

function get_term() {
	awk '\
		$1 == "background" {
			argb = gensub(".*\\(([0-9,]*),(.*[0-9]).*", "\\2,\\1", 1)
			split(argb, argba, ",")
			printf "bg #%.2x%.2x%.2x%.2x\n", int(argba[1] * 255), argba[2], argba[3], argba[4]
		}
		$1 == "foreground" { print "fg", $NF }
		/^color[0-9]/ {
			if(/color15/) {
				print "colors" c " " $NF
				exit
			} else {
				c = c " " $NF
			}
		}' $term_conf
}

get_vim() {
	#sed -n '/let.*g:bg/,/^$/ s/.*g:\([^ ]*\).*\(#\w*\).*/\1 \2/p' $vim_conf
	sed -n "s/^let.*g:\([^ ]*\).*'\(.*\)'.*/\1 \2/p" $vim_conf
}

get_vifm() {
	while read vifm_property index; do
		[[ $index == default ]] && color=$index || get_color_properties $((index + 1))
		echo $vifm_property $color
	done <<< $(sed -n "s/^let \$\(\w*\) = '\?\([^']*\).*/\1 \2/p" $vifm_conf)
}

function get_bar() {
	#bar_modules=${bar_conf%/*}/module_colors
	#awk '/^\w{1,4}[cg]=/ { print gensub("(.*)=.*(#\\w*).*", "\\1 \\2", 1) }' $bar_conf $bar_modules

	#get_bars
	get_bar_configs

	#bars=$(awk -F '=' '/^last_running/ {
	#	ab = $NF
	#	if(ab ~ ",") { s = "{"; e = "}" }
	#	print s ab e }' ~/.orw/scripts/barctl.sh)

	#colorschemes=$(awk '{
	#		c = gensub(/.*-c ([^ ]{3,}) .*/, "\\1", 1)
	#		if(ac !~ c) ac = ac "," c
	#	} END {
	#		if(ac ~ "[a-z],") { s = "{"; e = "}" }
	#		print s substr(ac, 2) e }' $(eval ls ~/.config/orw/bar/configs/$bars))

	#eval grep -hv '^#' ~/.config/orw/colorschemes/$colorschemes.ocs | sort -k 1,1 -u

	grep -hv '^#' $bar_colorschemes | sort -k 1,1 -u
}

function get_ncmpcpp() {
	while read -r ncmpcpp_property index; do
		get_color_properties $index
		echo $ncmpcpp_property $color
	done < <(\
		check_ncmpcpp_mode ;
		([[ $ncmpcpp_mode == dual ]] && sed -n '/^song_list/ s/.*(\([0-9]*\).*(\([0-9]*\).*/ac \1\ntc \2/p' $ncmpcpp_conf) ;

		sed -n "/main\|now_playing\|empty\|color2\|selected\|progressbar\|statusbar\|visualizer_color/ \
			{ /^#/! s/\(\w\)[^_]*\(_\)\?\([2eipt]\)\?.*\([2pc]\).*=[^0-9]*\([0-9]\+\).*/\1\3\4 \5/p }" $ncmpcpp_conf)
		#sed -n "/main\|empty\|color2\|selected\|progressbar\|statusbar\|visualizer_color/ \
		#	{ /^#/! s/\(\w\)[^_]*\(_\)\?\(e\)\?.*\([2ic]\).*=[^0-9]*\([0-9]\+\).*/\1\3\4 \5/p }" $ncmpcpp_conf )
}

function repeat_pattern() {
	printf "%0.s$1" $(seq 1 ${2-1})
}

function get_tmux() {
	sed -n "/^bg/,/^$/ s/\(.*\)='\(.*\)'/\1 \2/p" $tmux_conf
}

function get_rofi() {
	sed -n "s/.*\t\(.*\):.*\(#\w*\);/\1 \2/p" $rofi_conf
}

function get_bash() {
	awk -F '[";]' '/^\s*[^#m]{1,2}[cg]=/ {
		p = gensub("^\\s*(\\w*).*", "\\1", 1, $1)
		if($2 == "default") {
			print gensub("\\s*(\\w*).*", "\\1 " $2, 1)
		} else {
			printf("%s #%.2x%.2x%.2x\n", p, $2, $3, $4)
		}
	}' $bash_conf
}

function get_fff() {
	while read -r property color; do
		((color)) && get_color_index $color || terminal_color=default
		echo $property $terminal_color
	done <<< $(awk -F '=' '/FFF_COL/ \
		{ if($1 ~ /1$/) p = "dir"; else if($1 ~ /2$/) p = "st"; else if($1 ~ /3$/) p = "sel"; else p = "cur"; \
			print p, ($2 < 8) ? $2 + 1 : "default" }' $bash_conf)
}

function get_firefox() {
	sed -n 's/.*--\(.*\):.*\(#\w\{6\}\).*/\1 \2/p' $firefox_conf
}

function get_qb() {
	sed -n "s/\(^\w*[bf]g\)[^#]*\(#\w*\)./\1 \2/p" $qb_conf
}

function get_wall() {
	awk -F '"' '/desktop_'$current_desktop'/ {
		wall = $(NF - 1); if(wall ~ /^#/) print "bg", wall
		}' ~/.config/orw/config
}

function get_sxiv() {
	sed -n 's/Sxiv.\(.\)[^ ]*/\1g/p' $sxiv_conf
}

function get_lock() {
	awk -F '=' '/^\w*c=/ { print gensub("(.*)=(.{6})(.*)", "\\1 #\\3\\2", 1) }' $lock_conf
}

function assign_offset() {
	[[ $1 && $1 =~ [+-][0-9]+ ]] && eval "${2-offset}=$1"
}

add_notification() {
	full_message+="$notification\n"
}

shadow() {
	read red green blue <<< $($colorctl -cps ' ' -h $color)

	awk -i inplace \
		'/shadow-(red|green|blue)/ {
			if(/red/) c = '$red'
			else if(/green/) c = '$green'
			else c = '$blue'

			sub(/[0-9.]+/, c / 255)
		} { print }' ~/.config/picom/picom.conf
}

#all_modules=( ob gtk dunst term vim vifm bar ncmpcpp tmux rofi bash lock firefox $wall )
#all_modules=( ob gtk dunst term vim vifm bar ncmpcpp tmux rofi bash qb lock $wall )
all_modules=( ob dunst term vim vifm bar ncmpcpp tmux rofi bash qb lock $wall sxiv )

while getopts :o:O:tCp:e:Rs:S:m:cM:P:Bbr:Wwl flag; do
	case $flag in
		o) shade_offset=$OPTARG;;
		O) secondary_shade_offset=$OPTARG;;
		s)
			[[ $color ]] && set_color=$color
			[[ $offset ]] && set_offset=$offset && unset offset

			assign_value color ${!OPTIND} && shift
			assign_offset ${!OPTIND} && shift

			if [[ ! $color ]]; then
				[[ $module == term && ${base_colors[${property#br_}]} ]] &&
					get_color $property || color=$(parse_module)
			fi

			get_color
			color="#${color: -6}"

			if [[ $offset ]]; then
				unset color_{index,name}
				get_color_properties
			fi

			[[ $color_name ]] && existing_color=$color_name
			color_name=$OPTARG

			if [[ $existing_color ]]; then
				if (( ${base_colors[${existing_color#br_}]} )); then
					echo "Color $color is already defined as base ${existing_color^^} color."
					read -rsn 1 -p "Would yo like to add it anyway? [y/N]"$'\n' add_color
				else
					echo "Color $color is already defined under name $existing_color."
					read -rsn 1 -p "Would yo like to change its name to $color_name? [y/N]"$'\n' change_color_name
				fi

				[[ ${add_color:-$change_color_name} == y ]] && save_color
				unset add_color change_color_name
			else
				save_color
			fi

			$root/scripts/notify.sh -p "$icon color saved as <b>$color_name</b>."

			[[ $set_color ]] && get_color $set_color || unset color{_{name,index},}
			[[ $set_offset ]] && offset=$set_offset || unset offset

			$update_colors;;
		t)
			transparency=true

			if ! assign_offset ${!OPTIND} transparency_offset; then
				assign_value transparency_level ${!OPTIND}
			fi

			[[ ${transparency_level:-$transparency_offset} ]] && shift;;
		c)
			assign_value color ${!OPTIND} && shift
			assign_offset ${!OPTIND} pick_offset && shift

			if [[ ! $color ]]; then
				display_color_preview() {
					convert -size 100x100 xc:$color $preview
					feh -g 100x100 --title 'image_preview' $preview &
				}

				echo "Pick a color:"
				color=$($pick_color | awk '{ print tolower($0) }')
				#color=${color,,}

				read -srn 1 -p $'Offset color? [y/N]\n' offset_color

				if [[ $offset_color == y ]]; then
					preview=/tmp/color_preview.png

					read x y <<< $(~/.orw/scripts/windowctl.sh -p | awk '{ print $3 + ($5 - 100), $4 + ($2 - $1) }')
					~/.orw/scripts/set_geometry.sh -t image_preview -x $x -y $y
					display_color_preview

					while
						read -rsn 1 -p $'Whole/properties/done? [w/p/D]\n' offset_type
						[[ $offset_type == w ]]
					do
						read -p 'Enter offset: ' offset
						color=$($colorctl -o $offset -h $color)

						kill $!
						display_color_preview
					done

					kill $!

					[[ $offset_type == p ]] && $colorctl -P $color

					fifo=/tmp/color_preview.fifo
					read color < $fifo
					unset offset
				fi
			fi

			get_color $color $pick_offset
			unset transparency_{level,offset};;
		p)
			property=${OPTARG//,/|}

			if [[ ! $color ]]; then
				if assign_value color ${!OPTIND};then
					shift
					assign_offset ${!OPTIND} && shift
				fi
			fi

			[[ $color ]] && get_color $color

			if [[ $replace_color ]]; then
				new_color=$color
				new_color_index=$color_index
				unset color offset color_index
			fi;;
		e) edit_colorscheme=~/.config/orw/colorschemes/$OPTARG.ocs;;
			#colorscheme_name=$OPTARG

			#[[ $color ]] || get_color $(parse_module)
			#colorscheme=~/.config/orw/colorschemes/$colorscheme_name.ocs

			#if [[ ! ${property//[A-Za-z_]/} ]]; then
			#	grep -h "^$property" $colorscheme &> /dev/null ||
			#		(echo "$property $color" >> $colorscheme && exit)
			#fi

			#awk -i inplace '/^('${property//\*/\.\*/}') / { $NF = "'$color'" } { print }' $colorscheme

			#bar=$(ps aux | awk '\
			#		BEGIN { b = "" }
			#		/-c '$colorscheme_name'/ { 
			#			n = gensub(".*-n (\\w*).*", "\\1", 1)
			#			if(b !~ n) b = b "," n
			#		}
			#		END { print substr(b, 2) }')

			#[[ $bar ]] && ~/.orw/scripts/barctl.sh -b $bar
			#exit;;
		R)
			replace_color=true
			[[ ${!OPTIND} =~ ^a ]] && replace_all_modules=( ${all_modules[*]} ) && shift;;
		m)
			module="${OPTARG//,/ }"
			[[ $module =~ ':' ]] && multiple_modules=true
			[[ $module =~ bar ]] && bar_modules=${bar_conf%/*}/module_colors
			if [[ $module =~ tmux ]]; then
				assign_value tmux_hidden ${!OPTIND} && shift

				if [[ $tmux_hidden ]]; then
					reload_tmux_hidden=true
					tmux_conf=$tmux_hidden_conf
				fi
			fi;;
		C)
			arg=${!OPTIND}
			[[ $arg && ! $arg == -[[:alpha:]] ]] && colorscheme=$colorschemes/$arg.ocs && shift || colorscheme=$colorschemes/orw_default.ocs
			[[ ! -f $colorscheme ]] && echo "colorscheme doesn't exist, please try again." && exit 1;;
		M) inherited_module=$OPTARG;;
		P)
			inherited_property=$OPTARG
			assign_offset ${!OPTIND} && shift;;
		[Bb])
			[[ $flag == [[:lower:]] ]] && backup=true || backup=all
			assign_value backup_name ${!OPTIND} && shift;;
		r) reload=$OPTARG;;
		W) wall=wall;;
		w)
			backup=all
			wallpaper_name=$(awk -F '"' '{ if(/^primary/) { p = $NF; gsub(/.*_/, "", p) }; \
				if(/^desktop_'$current_desktop'/) { print gensub(/(.*\/|\..*)/, "", "g", $(p * 2)) } }' ~/.config/orw/config)
			backup_name="wall_${wallpaper_name// /_}";;
		l) log "$@";;
	esac
done

function inherit() {
	if [[ ${inherited_module:-$module} == term && ! ${inherited_property:-$property} =~ ([bf]g|colors) ]]; then
		[[ ${inherited_property:-$property} =~ ^[a-z_]+$ ]] &&
			get_color ${inherited_property:-$property} || multiple_colors=true
	else
		#[[ $edit_colorscheme && ! $inherited_module ]] && colorscheme=$edit_colorscheme
		[[ $inherited_property ]] && property_to_check=inherited_property || property_to_check=property
		[[ ${!property_to_check} && ! ${!property_to_check//[A-Za-z_]/} ]] && get_color $(parse_module)
	fi
}

if [[ ! $color && ! $backup ]]; then
	if [[ $new_color ]]; then
		unset transparency_{level,offset}
		[[ $edit_colorscheme ]] && colorscheme=$edit_colorscheme
	fi

	inherit

	if [[ $replace_color && ! $new_color ]]; then
		new_color=$color new_color_index=$color_index new_color_name=$color_name
		unset inherited_module inherited_property colorscheme color offset transparency_{level,offset}

		[[ $edit_colorscheme ]] && colorscheme=$edit_colorscheme

		inherit
	fi
fi

multiple_properties() {
	local color=$color
	property=${1:-$property}

	if [[ $module == bar && ${property//[A-Za-z]/} =~ ^\|+$ && (! $colorscheme || $inherited_property) ]]; then
		for property in ${property//|/ }; do
			$module
		done
	else
		[[ $inherited_module ]] && unset colorscheme

		while read -r property color; do
			$module
		done <<< $(sed -n "/#$module\|\".*\"/,/^$/p" ${colorscheme:-$colorschemes/orw_default.ocs} $bar_modules | \
			awk -F '[= ]' 'BEGIN { c = "'$color'" }
				$1 ~ "^('${property//\*/.*}')$" { print $1, gensub(".*(#\\w*).*", "\\1", 1, c ? c : $NF) }' | sort -uk1,1)
	fi
}

if [[ $edit_colorscheme ]]; then
	colorscheme_name=${edit_colorscheme##*/}

	bar=$(ps aux | awk '\
		BEGIN { b = "" }
			/-c '${colorscheme_name%.*}'/ { 
				n = gensub(".*-n (\\w*).*", "\\1", 1)
				if(b !~ n) b = b "," n
			}
		END { print substr(b, 2) }')

	if [[ $new_color ]]; then
		if [[ $transparency ]]; then
			if ((${#new_color} < 8)); then
				#color=${color: -6}
				((${#color} > 8)) &&
					new_color=${color:0:3}${new_color: -6} ||
					color=${color: -6}
			fi
		else
			new_color=${new_color: -6}
		fi

		current_color=${color#\#}
		new_color=${new_color#\#}
		edit_pattern=.*

		awk -i inplace '/^('${edit_pattern:-${property//\*/\.\*}}') / {
			sub("'${current_color:-.*}'", "'${new_color:-$color}'", $NF)
		} { print }' $edit_colorscheme
	else
		if [[ ${property//[A-Za-z_]/} ]]; then
			multiple_properties
		else
			[[ $color ]] || get_color $(parse_module)
			bar
		fi
	fi

	[[ $bar ]] && ~/.orw/scripts/barctl.sh -b $bar
	exit
fi

if [[ $backup ]]; then
	[[ ! -d $colorschemes ]] && mkdir $colorschemes

	if [[ $backup_name ]]; then
		if [[ -f $colorschemes/$backup_name.ocs ]]; then
			read -p "Colorscheme already exist, would you like to overwrite it? [Y/n] " overwrite
			[[ $overwrite == [Nn] ]] && exit || rm $colorschemes/$backup_name.ocs
		fi
	else
		generic_name="backup_$(date +"%Y-%m-%d")"
		count=$(ls $colorschemes/$generic_name* 2> /dev/null |wc -l)
		[[ $count -gt 0 ]] && generic_name+="_$count"
	fi

	filename=${backup_name:-$generic_name}

	[[ $backup == all ]] && backup_modules=${all_modules[*]} ||
		backup_modules=${module:-${all_modules[*]}} notification="<b>$module</b> module "

	notification+="colorscheme saved as <b>$filename</b>."
	add_notification

	for backup_module in ${backup_modules[*]}; do
		echo -e "#$backup_module\n$(get_$backup_module)\n" >> $colorschemes/$filename
	done

	sed -i '$d' $colorschemes/$filename

	mv $colorschemes/${existing:-$filename} $colorschemes/$filename.ocs

	final_filename=${backup_name:-${existing:-$generic_name}}
	echo "colorscheme ${final_filename%.*}.ocs changed on $(date +"%Y-%m-%d") at $(date +"%H:%M").." >> $colorschemes/.change_log
fi

if [[ ! $backup && ${replace_all_modules[*]:-${module:-${all_modules[*]}}} =~ ncmpcpp|vifm
	&& (! $colorscheme || ($colorscheme && ($inherited_module || $inherited_property))) ]]; then

	[[ $replace_color ]] && var_name=new_color || var_name=color
	index=${var_name}_index

	if [[ ! ${!index} ]]; then
		echo "${!var_name} is undefined. In order to apply provided color to ncmpcpp/vifm, you need to save it."
		read -rsn 1 -p $'Would you like to save color? [Y/n] \n' save_color

		if [[ $save_color != n ]]; then
			read -rsn 1 -p $'Would you like to name color or save it under generic name - sc_INDEX? [y/N] \n' name_color

			[[ $name_color == y ]] && read -p 'Enter color name: ' ${var_name}_name ||
				eval ${var_name}_name=$(awk '$1 ~ "^sc_" { lsc = $1 } END { sub("sc_", "", lsc); print "sc_" lsc + 1 }' \
				$all_colors)

			save_color $var_name
		fi
	fi
fi

if [[ $replace_color ]]; then
	replace_modules="${replace_all_modules[*]:-${module:-${all_modules[*]}}}"

	if [[ $replace_all_modules ]]; then
		modules="all modules"
	else
		previous_modules="${replace_modules% *}"
		last_module=${replace_modules##* }
		modules="${previous_modules// /, } and $last_module"
	fi

	notification="<b>${modules^} $color</b> color has been replaced with <b>$new_color</b>"

	for replace_module in $replace_modules; do
		eval "reload_$replace_module=true"
		config_file=${replace_module}_conf

		if [[ $replace_module =~ vifm|ncmpcpp ]]; then
			all_indexes=$(awk '\
				BEGIN { c = "'$color'" }
				$2 == c {
					i = ("'$replace_module'" == "vifm") ? NR - 1 : NR
					ai = ai "\\\\|" i
				} END { print substr(ai, 4) }' $all_colors)

			if [[ $replace_module == vifm ]]; then
				new_index=$((new_color_index - 1))
				pattern='/^\s*let \$\w*[cg]/'
			else
				new_index=$new_color_index
				pattern='/delay\|columns\|interval\|change/!'

				sed -i "/^foreground/ s/${color: -6}/${new_color: -6}/" $cava_conf
			fi

			sed -i "$pattern s/\<\($all_indexes\)\>/$new_index/g" ${!config_file}*
		else
			if [[ $replace_module == term ]]; then
				[[ $term_transparency && ${#color} -lt 8 ]] && color="#$term_transparency${color#\#}"

				awk --non-decimal-data -i inplace '
					/^background/ {
						r = "'${color: -6:2}'"
						g = "'${color: -4:2}'"
						b = "'${color: -2:2}'"

						nr = "'${new_color: -6:2}'"
						ng = "'${new_color: -4:2}'"
						nb = "'${new_color: -2:2}'"

						if("'$transparency'") {
							t = "'${color:1:2}'"
							a = sprintf("%.2f", sprintf("%.2d", "0x" t) / 255)

							nt = "'${new_color:1:2}'"
							na = sprintf("%.2f", sprintf("%.2d", "0x" nt) / 255)
						}

						rgb = sprintf("%.2d,%.2d,%.2d,", "0x" r, "0x" g, "0x" b)
						nrgb = sprintf("%.2d,%.2d,%.2d,", "0x" nr, "0x" ng, "0x" nb)

						sub(rgb a, nrgb na)
					}
					/^foreground/ {
						sub("'${color: -6}'", "'${new_color: -6}'")
					} { print }' $term_conf
			else
				[[ $module == term && ${#color} -gt 7 ]] &&
					color="#${color: -6}" term_transparency="${color:1:2}"

				case $replace_module in
					bash)
						rgb_color=$($colorctl -c -s ';' -h $color)
						new_rgb_color=$($colorctl -c -s ';' -h $new_color)
						sed -i "s/$rgb_color/$new_rgb_color/" $bash_conf;;
					tmux)
						[[ $new_color =~ ^# && ${#new_color} -gt 8 ]] && new_color="#${new_color: -6}"
						sed -i "/^\w*[gc]=/ s/${color#\#}/${new_color#\#}/" $tmux_conf;;
					lock)
						((${#color} > 7)) && lock_color=${color:3}${color:1:2} new_lock_color=${new_color:3}${new_color:1:2} ||

						sed -i "s/${lock_color:-${color:1}}/${new_lock_color:-$new_color}/" ${!config_file};;
					*)
						replace_config=${!config_file}

						if [[ $transparency ]]; then
							((${#new_color} < 8)) && color=${color: -6}
						else
							new_color=${new_color: -6}
						fi

						if [[ $replace_module == ob ]]; then
							#shadow_color=$(awk -F '[ ;]' '/^shadow-(red|green|blue)/ {
							#		rgb = rgb sprintf("%.2x", int($(NF - 1) * 255))
							#	} END { print "#" rgb }' $picom_conf)

							replace_shadow=$(awk -F '[ ;]' '/^shadow-(red|green|blue)/ {
									rgb = rgb sprintf("%.2x", sprintf("%.0f", $(NF - 1) * 255))
								} END { print ("#" rgb == "'$color'") }' $picom_conf)

							#shadow_color=$(awk -F '[ ;]' '/^shadow-(red|green|blue)/ {
							#		rgb = rgb sprintf("%.2x", sprintf("%.0f", $(NF - 1) * 255))
							#	} END { print "#" rgb }' $picom_conf)
							#echo $replace_shadow $shadow_color $color

							((replace_shadow)) && property=s && ob
						elif [[ $replace_module == qb ]]; then
							replace_config+=" ~/.orw/dotfiles/.config/qutebrowser/home.css"
						elif [[ $replace_module == dunst ]]; then
							replace_config+=" ~/.orw/scripts/notify.sh"
						elif [[ $replace_module == bar ]]; then
							replace_config="$bar_conf $bar_module_colors"

							#running_bars=$(ps aux |
							#	awk '/lemonbar.*-n \w*$/ {
							#		if(c) { s = ","; bs = "{"; be = "}" }
							#		rb = rb gensub(".* (\\w*)$", s "\\1", 1)
							#		c++
							#	} END { print bs rb be }')

							#if [[ $running_bars ]]; then
							#	running_bar_configs="$(eval ls ~/.config/orw/bar/configs/$running_bars)"
							#	bar_colorschemes=$(awk '{
							#			if(c) { s = ","; bs = "{"; be = "}" }
							#			cs = cs gensub(".*-c ([^-]\\w*).*", s "\\1", 1)
							#			c++
							#		} END { print "~/.config/orw/colorschemes/" bs cs be ".ocs" }' \
							#			$running_bar_configs)

							#	#[[ $bar_colorschemes ]] &&
							#	#	eval sed -i "s/${color#\#}/${new_color#\#}/" $bar_colorschemes

							#	[[ $bar_colorschemes ]] && replace_config+=" $bar_colorschemes" reload_bar=true
							#		#replace_config=$bar_colorschemes || replace_config="$bar_conf $bar_module_colors"
							#	#if [[ $bar_colorschemes ]]; then
							#	#	eval sed -i "s/${color#\#}/${new_color#\#}/" $bar_colorschemes

							#	#	~/.orw/scripts/barctl.sh -b ${running_bars//[{\}]/} &
							#	#	continue
							#	#fi
							#fi

							get_bar_configs
							[[ $bar_colorschemes ]] && replace_config+=" $bar_colorschemes"
						fi

						#[[ $replace_module == bar ]] && bar_module_colors=$bar_modules || bar_module_colors=''
						#sed -i "s/${color#\#}/${new_color#\#}/" ${!config_file} $bar_module_colors
						eval sed -i "s/${color#\#}/${new_color#\#}/" "$replace_config"
				esac

					#[[ $replace_module == bar ]] && bar_module_colors=$bar_modules || bar_module_colors=''
					#sed -i "s/$color/$new_color/" ${!config_file} $bar_module_colors
			fi
		fi
	done
elif [[ $property || $multiple_modules ]]; then
	notification="<b>$module</b>'s <b>$property</b> property has been changed"

	if [[ $multiple_modules ]]; then
		for module_properties in $module; do
			module=${module_properties%:*}
			property=${module_properties#*:}
			multiple_properties ${property//_/|}
		done
	else
		if [[ ${property//[A-Za-z_]/} ]]; then
			notification="<b>$module</b>'s properties has been changed"

			if [[ $module == term && ! $property =~ ([bf]g|colors) ]]; then
				$module
			else
				multiple_properties
			fi
		else
			[[ ! $@ =~ -s ]] && $module
		fi
	fi
else
	if [[ $colorscheme ]]; then
		whole_module=true

		if [[ ${module//[^ ]/} ]]; then
			module_count=modules

			previous_modules="${module% *}"
			last_module=${module##* }
			modules="${previous_modules// /, } and $last_module"
		else
			module_count=module
			modules=$module
		fi

		[[ $module ]] && notification="<b>${modules^}</b> $module_count " || notification="Colorscheme "

		for module in ${module:-$(sed -n 's/^#//p' $colorscheme)}; do
			while read -r property color; do
				$module
			done <<< $(sed "/^#$module/,/^\w*$/!d;//d" $colorscheme)
		done
	else
		$root/scripts/notify.sh -p "$icon ${full_message%\\*}" &
		exit
	fi
fi

colorscheme=${colorscheme%.*}
colorscheme=${colorscheme##*/}
[[ $colorscheme ]] && notification+="has been changed to <b>$colorscheme</b> colorscheme." || notification+="."
add_notification

if [[ ${reload-yes} == yes ]]; then
	#if [[ $reload_ob ]]; then $(which openbox) --reconfigure & fi
	#if [[ $reload_bar ]]; then ~/.orw/scripts/barctl.sh &> /dev/null & fi
	#if [[ $reload_vim ]]; then ~/.orw/scripts/source_neovim_colors.py & fi
	#if [[ $reload_ncmpcpp ]]; then ~/.orw/scripts/ncmpcpp.sh -a & fi
	#if [[ $reload_term ]]; then killall -USR1 termite & fi
	#if [[ $reload_sxiv ]]; then xrdb -load $sxiv_conf & fi
	[[ $reload_ob ]] && $(which openbox) --reconfigure
	[[ $reload_bar ]] && ~/.orw/scripts/barctl.sh &> /dev/null
	[[ $reload_vim ]] && ~/.orw/scripts/source_neovim_colors.py
	[[ $reload_ncmpcpp ]] && ~/.orw/scripts/ncmpcpp.sh -a
	[[ $reload_term ]] && killall -USR1 termite
	#[[ $reload_sxiv ]] && xrdb -load $sxiv_conf
	[[ $reload_sxiv ]] && xrdb -merge $sxiv_conf

	if [[ $reload_vifm ]]; then
		vifm=$(which vifm)
		[[ $($vifm --server-list) ]] && $vifm --remote -c "colorscheme orw" &
	fi

	if [[ $reload_qb ]]; then
		qb_pid=$(pgrep qutebrowser)
		((qb_pid)) && qutebrowser ":config-source" &> /dev/null &
	fi

	if [[ $reload_tmux ]]; then
		tmux=$(which tmux)
		if [[ $($tmux ls 2> /dev/null) ]]; then [[ $tmux_hidden ]] || $tmux source-file $tmux_conf & fi
		if [[ $reload_tmux_hidden && $($tmux -S /tmp/tmux_hidden ls 2> /dev/null) ]]; then
			$tmux -S /tmp/tmux_hidden source-file $tmux_hidden_conf &
		fi
	fi

	if [[ $reload_dunst ]]; then
		command=$(ps -C dunst -o args= | awk '{ if($1 == "dunst") $1 = "'$(which dunst)'"; print }')
		#command=$(ps -C dunst -o args= | awk '$1 == "dunst" { $1 = "'$(which dunst)'" } { print }')

		killall dunst
		$command &> /dev/null &
		#killall dunst
		#/usr/local/bin/dunst &> /dev/null &
	fi
fi

$root/scripts/notify.sh -p "$icon <span font='Iosevka Orw 8'>${full_message%\\*}</span>" &
