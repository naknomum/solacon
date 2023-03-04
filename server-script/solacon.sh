#!/bin/bash

# Generate and save [Solacon images](https://github.com/misaki-web/solacon)
# without user interaction.
# 
# Run `solacon.sh -h` for more details.

################################################################################
# CONFIGURATION
################################################################################

# Note that configuration variables can be set in a file "./solacon.conf.sh".

# Path to Chrome/Chromium
conf_chrome_path="chromium-browser"

# Solacon distant base URL
conf_solacon_distant_base_url="https://misaki-web.github.io/solacon/"

# If access from outside is enabled, base URL
conf_solacon_outside_base_url="0.0.0.0:850"

# If access from outside is enabled, URL scheme
conf_solacon_outside_url_scheme="http"

# If access from outside is enabled, path to the file "index.php"
conf_solacon_path_to_index_php="access-from-outside/index.php"

# If access from outside is enabled, run the script with the specified user
conf_solacon_outside_user=""

# Solacon local base URL (if PHP is installed, a built-in web server
# will be started locally; keep empty to disable the local server)
conf_solacon_local_base_url="0.0.0.0:851"

# If a built-in server is started locally, number of server workers
conf_nb_server_workers=1

# If a built-in server is started locally, path to the file "index.html"
conf_solacon_path_to_index_html="../index.html"

# If a built-in server is started locally, keep it running at the end of the script
conf_keep_web_server_running=true

# Add the string to the image file name
conf_add_string_to_image_name=true

# Script return ("save", "content", "b64" or "name+b64")
conf_return="save"

# History file name (must end with ".csv"; keep empty to disable history)
conf_history_file_name="solacon-history.csv"

# Log file name (must end with ".log"; keep empty to disable log)
conf_log_file_name="solacon.log"

################################################################################
# FUNCTIONS
################################################################################

# Thanks to <https://stackoverflow.com/a/59592881>.
# catch STDO_VAR STDE_VAR COMMAND [ARGS]
catch() {
	{
		IFS=$'\n' read -r -d '' "${1}";
		IFS=$'\n' read -r -d '' "${2}";
		(IFS=$'\n' read -r -d '' _ERRNO_; return "${_ERRNO_}");
	} < <( ( printf '\0%s\0%d\0' "$( ( ( ( { shift 2; "${@}"; echo "${?}" 1>&3-; } | tr -d '\0' 1>&4- ) 4>&2- 2>&1- | tr -d '\0' 1>&4- ) 3>&1- | exit "$(cat)" ) 4>&1- )" "${?}" 1>&2 ) 2>&1 )
}

cd_exit() {
	local path=$1
	
	# ----------
	
	debug "Can't enter the directory \"$path\"."
	
	exit 1
}

convert_to_base64url() {
	tr '+/' '-_' | tr -d '='
}

debug() {
	local content=$1
	local display=$2
	
	if [[ $display != true && $display != false ]]; then
		display=true
	fi
	
	# ----------
	
	if [[ -n $content ]]; then
		if [[ $display == true ]]; then
			echo "$content" 1>&2
		fi
		
		if [[ -f $LOG_FILE ]]; then
			echo "$EPOCHSECONDS:$content" >> "$LOG_FILE"
		fi
	fi
}

# First argument passed by reference.
get_server_pid() {
	local -n pid_array=$1
	local base_url=$2
	
	# ----------
	
	# shellcheck disable=SC2034
	mapfile -t pid_array < <(pgrep -f "php -S $base_url")
}

image_is_valid() {
	local image_path=$1
	
	# ----------
	
	[[ -f $image_path ]] && \
	(( $(stat --printf="%s" "$image_path") > 0 )) && \
	{ \
		{ [[ $image_path =~ ".png"$ ]] && identify +ping "$image_path" &> /dev/null; } || \
		{ [[ $image_path =~ ".svg"$ ]] && [[ $(head -n 1 "$image_path") =~ ^'<svg xmlns="http://www.w3.org/2000/svg" ' ]]; } \
	}
}

implode() {
	local separator=$1
	local fields=("${@:2}")
	
	local imploded
	
	# ----------
	
	imploded=$(printf "$separator%s" "${fields[@]}")
	imploded=${imploded:${#separator}}
	
	echo -n "$imploded"
}

manage_access_from_outside() {
	local option=$1
	local path_to_index_php=$2
	local base_url=$3
	local nb_workers=$4
	
	if [[ ! $nb_workers =~ ^[1-9][0-9]*$ ]]; then
		nb_workers=1
	fi
	
	local demo_url interface ip_address php_parent_web_server_pid port rule success
	declare -a php_web_server_pid
	declare -a rules
	
	# ----------
	
	if [[ $option == "enable" ]]; then
		success=false
		
		if url_is_ok "$base_url"; then
			get_server_pid "php_web_server_pid" "$base_url"
			success=true
		elif type -p php > /dev/null; then
			cd "${path_to_index_php%/*}" || cd_exit "${path_to_index_php%/*}"
			PHP_CLI_SERVER_WORKERS=$nb_workers php -S "$base_url" > /dev/null 2>&1 &
			php_parent_web_server_pid=$!
			
			if [[ -n $php_parent_web_server_pid ]]; then
				success=true
			fi
		fi
		
		if [[ $success == true ]]; then
			port=${base_url##*:}
			
			ufw allow "$port"/tcp comment Solacon
			ufw --force enable
			
			for interface in /sys/class/net/*; do
				if [[ $(cat "$interface/operstate") == "up" ]]; then
					interface=${interface##*/}
					
					break
				fi
			done
			
			if [[ -n $interface ]]; then
				ip_address=$(LANG=c ifconfig "$interface" | grep -oP '^\s+inet \K[^ ]+')
				
				if [[ -n $ip_address ]]; then
					demo_url="$OUTSIDE_URL_SCHEME://$ip_address:$port/?string=lorem-ipsum&download=png&color=124e9b&background=colored&size=512"
					
					debug "Access from outside: $demo_url"
				fi
			fi
			
			get_server_pid "php_web_server_pid" "$base_url"
			
			if ((${#php_web_server_pid[@]} > 0)); then
				debug "PHP web server PID: ${php_web_server_pid[*]}"
			fi
		else
			debug "Can't enable access from outside."
		fi
	elif [[ $option == "disable" ]]; then
		if url_is_ok "$base_url"; then
			get_server_pid "php_web_server_pid" "$base_url"
			
			if ((${#php_web_server_pid[@]} > 0)); then
				debug "PHP web server PID to be closed: ${php_web_server_pid[*]}"
				
				kill "${php_web_server_pid[@]}"
			fi
		fi
		
		debug "Removing ufw rules..."
		
		mapfile -t rules < <(ufw status numbered | grep -oP '\[ *\K[0-9]+\] .+ # Solacon$' | cut -d ']' -f 1 | sort -nr)
		
		for rule in "${rules[@]}"; do
			ufw --force delete "$rule"
		done
	else
		debug "Invalid option \"$option\"."
	fi
}

url_encode() {
	local text=$1
	
	# ----------
	
	if [[ -n $text ]]; then
		printf "%s" "$text" | od -An -tx1 -v -w"${#text}" | tr ' ' % | tr -d $'\n'
	fi
}

url_is_ok() {
	local url=$1
	
	local domain port
	
	# ----------
	
	domain=${url%%:*}
	port=${url##*:}
	
	if [[ -z $port ]]; then
		port=80
	fi
	
	if [[ -n $domain ]]; then
		#php -r "(\$socket = @fsockopen(\"$domain\", \"$port\", \$errno, \$errstr, 5)) === false ? exit(1) : exit(0);"
		#nc -z -w 5 "$domain" "$port"
		#timeout 5 bash -c "cat /dev/null > /dev/tcp/$domain/$port"
		wget -T 5 -t 1 --spider "$domain:$port" &> /dev/null
	fi
}

usage() {
	echo ""
	echo "Usage: $0 [-b BACKGROUND] [-c COLOR] [-d DIRECTORY] [-f FORMAT] [-h] [-k] [-o OUTSIDE] [-r RETURN] [-s SIZE] [-t TEXT]"
	echo ""
	echo "  -b: Image background: \"colored\" or \"white\". If empty, the background will be transparent."
	echo "  -c: Hex or RGB color. If empty, a random color will be used."
	echo "  -d: Directory where to save the images. If empty, the current script directory will be used."
	echo "  -f: Image format: \"png\" or \"svg\". If empty, the format will be \"svg\"."
	echo "  -h: Display help and exit."
	echo "  -k: Kill the PHP built-in web server if it's running, and exit. It'll override configuration settings."
	echo "  -o: Toggle access from outside and exit. Options: \"enable\" or \"disable\"."
	echo "  -r: Set the script return type (\"save\", \"content\", \"b64\" or \"name+b64\"). It'll override configuration settings."
	echo "  -s: Image size (for PNG images). If empty, the size will be \"1024\"."
	echo "  -t: Text used to generate the solacon. If empty, a random string will be used."
	echo ""
	echo "Examples:"
	echo ""
	echo "  $0"
	echo "  $0 -c \"#2D73AF\""
	echo "  $0 -b colored -c \"rgb(45,115,175)\" -f png -s 512"
	echo "  $0 -c 2d73af -d \"/path/to/directory\" -f svg -t \"Lorem ipsum dolor sit amet\""
	echo ""
}

################################################################################
# CONSTANTS, 1 of 2
################################################################################

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
CONF_FILE="$SCRIPT_DIR/solacon.conf.sh"

declare -r SCRIPT_DIR CONF_FILE

################################################################################
# SOURCE
################################################################################

if [[ -f $CONF_FILE ]]; then
	# shellcheck source=./solacon.conf.sh
	source "$CONF_FILE"
fi

if [[ ! $conf_nb_server_workers =~ ^[1-9][0-9]*$ ]]; then
	conf_nb_server_workers=1
fi

if [[ ! $conf_outside_port =~ ^[1-9][0-9]*$ ]]; then
	conf_outside_port="850"
fi

conf_log_file_name=${conf_log_file_name##*/}

if [[ ! $conf_log_file_name =~ ".log"$ ]]; then
	conf_log_file_name+=".log"
fi

conf_history_file_name=${conf_history_file_name##*/}

if [[ ! $conf_history_file_name =~ ".csv"$ ]]; then
	conf_history_file_name+=".csv"
fi

if [[ $conf_return != "save" && $conf_return != "content" && $conf_return != "b64" && $conf_return != "name+b64" ]]; then
	conf_return="save"
fi

################################################################################
# CONSTANTS, 2 of 2
################################################################################

OUTSIDE_URL_SCHEME=$conf_solacon_outside_url_scheme

declare -r OUTSIDE_URL_SCHEME

HISTORY_FILE="$SCRIPT_DIR/$conf_history_file_name"
LOG_FILE="$SCRIPT_DIR/$conf_log_file_name"

declare -r HISTORY_FILE LOG_FILE

if [[ ! -e $HISTORY_FILE ]]; then
	touch "$HISTORY_FILE"
fi

if [[ -f $HISTORY_FILE ]]; then
	chmod 666 "$HISTORY_FILE"
fi

if [[ ! -e $LOG_FILE ]]; then
	touch "$LOG_FILE"
fi

if [[ -f $LOG_FILE ]]; then
	chmod 666 "$LOG_FILE"
fi

################################################################################
# ARGUMENTS
################################################################################

solacon_background="" # -b
solacon_color=""      # -c
solacon_dir=""        # -d
solacon_format=""     # -f
solacon_size=""       # -s
solacon_text=""       # -t

while getopts ':b:c:d:f:hko:r:s:t:' opt; do
	case "${opt}" in
		b)
			solacon_background=${OPTARG,,}
			;;
		c)
			solacon_color=${OPTARG,,}
			solacon_color=${solacon_color// /}
			;;
		d)
			solacon_dir=$OPTARG
			;;
		f)
			solacon_format=${OPTARG,,}
			;;
		h)
			usage
			
			exit 0
			;;
		k)
			if url_is_ok "$conf_solacon_local_base_url"; then
				get_server_pid "php_web_server_pid" "$conf_solacon_local_base_url"
				
				if ((${#php_web_server_pid[@]} > 0)); then
					kill "${php_web_server_pid[@]}"
				fi
			fi
			
			exit 0
			;;
		o)
			manage_access_from_outside "$OPTARG" "$conf_solacon_path_to_index_php" "$conf_solacon_outside_base_url" "$conf_nb_server_workers"
			
			exit 0
			;;
		r)
			[[ $OPTARG == "save" || $OPTARG == "content" || $OPTARG == "b64" || $OPTARG == "name+b64" ]] && conf_return=$OPTARG
			;;
		s)
			solacon_size=$OPTARG
			solacon_size=${solacon_size//px/}
			;;
		t)
			solacon_text=$OPTARG
			;;
		*)
			usage
			
			exit 1
			;;
	esac
done

if [[ $solacon_background != "colored" && $solacon_background != "white" ]]; then
	solacon_background=""
fi

if [[ ! $solacon_color =~ ^"#"?([a-f0-9]{3}|[a-f0-9]{6})$ && \
      ! $solacon_color =~ ^"rgb("([0-9]{1,3}","){2}[0-9]{1,3}")"$ ]]; then
	solacon_color=""
fi

if [[ ! -d $solacon_dir ]]; then
	solacon_dir=$SCRIPT_DIR
fi

if [[ $solacon_format != "png" && $solacon_format != "svg" ]]; then
	solacon_format="svg"
fi

if [[ ! $solacon_size =~ ^[1-9][0-9]*$ ]]; then
	solacon_size="1024"
fi

if [[ $solacon_format != "png" ]]; then
	solacon_size=""
fi

if [[ -n $solacon_text ]]; then
	solacon_text=$(url_encode "$solacon_text")
fi

################################################################################
# VARIABLES
################################################################################

current_date=$(date "+%s%3N" | sed -E 's/(...)$/.\1/')
png_file_tpl="solacon-${current_date}%STRING%.png"
svg_file_tpl="solacon-${current_date}%STRING%.svg"
solacon_img_tpl=""
solacon_img=""
grep_regex_img=""

if [[ $solacon_format == "png" ]]; then
	solacon_img_tpl="$solacon_dir/$png_file_tpl"
	grep_regex_img=' data-pngbase64="data:image/png;base64,\K[^"]+'
elif [[ $solacon_format == "svg" ]]; then
	solacon_img_tpl="$solacon_dir/$svg_file_tpl"
	grep_regex_img=' src="data:image/svg\+xml;base64,\K[^"]+'
fi

solacon_url=""
solacon_img=$solacon_img_tpl
php_parent_web_server_pid=""
php_web_server_pid=()

if [[ -n $conf_solacon_local_base_url ]]; then
	if url_is_ok "$conf_solacon_local_base_url"; then
		get_server_pid "php_web_server_pid" "$conf_solacon_local_base_url"
		solacon_url="http://$conf_solacon_local_base_url/"
	elif type -p php > /dev/null; then
		if [[ $conf_solacon_path_to_index_html == "../index.html" ]]; then
			conf_solacon_path_to_index_html="$SCRIPT_DIR/$conf_solacon_path_to_index_html"
		fi
		
		cd "${conf_solacon_path_to_index_html%/*}" || cd_exit "${conf_solacon_path_to_index_html%/*}"
		PHP_CLI_SERVER_WORKERS=$conf_nb_server_workers php -S "$conf_solacon_local_base_url" > /dev/null 2>&1 &
		php_parent_web_server_pid=$!
		
		if [[ -n $php_parent_web_server_pid ]]; then
			solacon_url="http://$conf_solacon_local_base_url/"
		fi
	fi
fi

if [[ -z $solacon_url ]]; then
	solacon_url=$conf_solacon_distant_base_url
fi

solacon_url_vars=()

if [[ -n $solacon_text ]]; then
	solacon_url_vars+=("string=$solacon_text")
fi

if [[ -n $solacon_background ]]; then
	solacon_url_vars+=("background=$solacon_background")
fi

if [[ -n $solacon_color ]]; then
	solacon_url_vars+=("color=$solacon_color")
fi

if [[ $solacon_format == "png" ]]; then
	if [[ -n $solacon_size ]]; then
		solacon_url_vars+=("size=$solacon_size")
	fi
	
	solacon_url_vars+=("download=$solacon_format")
fi

if ((${#solacon_url_vars} > 0)); then
	solacon_url+="?"
	solacon_url+=$(implode "&" "${solacon_url_vars[@]}")
fi

headless_cmd=("$conf_chrome_path" --headless --virtual-time-budget=10000 --timeout=10000 --disable-gpu)

if [[ -n $conf_solacon_outside_user ]]; then
	headless_cmd=(sudo -u "$conf_solacon_outside_user" "${headless_cmd[@]}")
else
	headless_cmd+=(--no-sandbox)
fi

headless_cmd+=(--dump-dom "$solacon_url")

################################################################################
# DEPENDENCIES
################################################################################

err=false

if ! type -p identify > /dev/null; then
	err=true
	debug "The package \"graphicsmagick-imagemagick-compat\" must be installed."
fi

if ! type -p "$conf_chrome_path" > /dev/null; then
	err=true
	debug "The package \"chromium-browser\" must be installed."
fi

if [[ $err == true ]]; then
	exit 1
fi

################################################################################
# SCRIPT
################################################################################

i=0

until image_is_valid "$solacon_img"; do
	if ((i > 10)); then
		break
	fi
	
	debug "Command:             ${headless_cmd[*]@Q}"
	
	html=""
	html_err=""
	catch html html_err "${headless_cmd[@]}"
	
	debug "$html_err" false
	
	string_base64=$(grep -m 1 -oP ' data-stringbase64="\K[^"]+' <<< "$html")
	string_base64url=$(echo -n "$string_base64" | convert_to_base64url)
	string=$(echo -n "$string_base64" | base64 -d)
	color=$(grep -m 1 -oP ' data-color="\K[^"]+' <<< "$html")
	
	if [[ $conf_add_string_to_image_name == true ]]; then
		solacon_img=${solacon_img_tpl//"%STRING%"/"-$string_base64url"}
	else
		solacon_img=${solacon_img_tpl//"%STRING%"/}
	fi
	
	if [[ ${#php_web_server_pid[@]} == 0 && -n $php_parent_web_server_pid ]]; then
		mapfile -t php_web_server_pid < <(pgrep -P "$php_parent_web_server_pid" | xargs echo "$php_parent_web_server_pid" | tr ' ' '\n')
	fi
	
	debug "--------------------"
	debug "Date:                $(date -d "@${current_date%%.*}" "+%Y-%m-%d %H:%M:%S")"
	debug "Solacon URL:         $solacon_url"
	
	if ((${#php_web_server_pid[@]} > 0)); then
		debug "PHP web server PID:  ${php_web_server_pid[*]}"
	fi
	
	debug "--------------------"
	debug "Format:              $solacon_format"
	debug "Color:               $color"
	debug "Background:          $solacon_background"
	debug "Size:                $solacon_size"
	debug "--------------------"
	debug "String:              $string"
	debug "String (base64):     $string_base64"
	debug "String (base64url):  $string_base64url"
	debug "--------------------"
	
	if [[ $conf_return == "save" ]]; then
		debug "File:                $solacon_img"
	fi
	
	if [[ -n $string_base64url ]]; then
		grep -m 1 -oP "$grep_regex_img" <<< "$html" | base64 -d > "$solacon_img"
	fi
	
	((i++))
done

delete_image=false

if image_is_valid "$solacon_img"; then
	if [[ $solacon_format == "svg" ]]; then
		sed -Ei 's#(fill="rgba\(([0-9]{1,3}),([0-9]{1,3}),([0-9]{1,3}), ([0-9.]{1,5})\)")#\1 style="fill:rgb(\2,\3,\4);fill-opacity:\5"#g' \
			"$solacon_img"
	fi
	
	if [[ -f $HISTORY_FILE ]]; then
		image_hash=$(sha256sum "$solacon_img" | cut -d ' ' -f 1)
		echo "$current_date,$string,$color,${solacon_img##*/},$image_hash" >> "$HISTORY_FILE"
	fi
	
	if [[ $conf_return == "content" || $conf_return == "b64" || $conf_return == "name+b64" ]]; then
		if [[ $conf_return == "content" ]]; then
			cat "$solacon_img"
		elif [[ $conf_return == "b64" ]]; then
			base64 -w 0 "$solacon_img"
		elif [[ $conf_return == "name+b64" ]]; then
			cat <(echo "${solacon_img##*/}") <(base64 -w 0 "$solacon_img")
		fi
		
		delete_image=true
	fi
else
	delete_image=true
fi

if [[ $delete_image == true ]]; then
	rm -f "$solacon_img"
fi

if ((${#php_web_server_pid[@]} > 0)) && [[ $conf_keep_web_server_running == false ]]; then
	kill "${php_web_server_pid[@]}"
fi
