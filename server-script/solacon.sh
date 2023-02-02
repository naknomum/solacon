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

# Solacon local base URL (if PHP is installed, a built-in web server will be started)
conf_solacon_local_base_url="0.0.0.0:8000"

# If a built-in server is started, path to the file "index.html"
conf_solacon_path_to_index_html="../index.html"

# If a built-in server is started, keep it running at the end of the script
conf_keep_web_server_running=true

# Add the string to the image file name
conf_add_string_to_image_name=true

# Return the image content instead of saving it
conf_return_image_content=false

# Log file name (keep empty to disable log)
conf_log_file_name="solacon-log.csv"

################################################################################
# FUNCTIONS
################################################################################

base64_url_encode() {
	local string=$1
	local is_base64=$2
	
	if [[ $is_base64 != true && $is_base64 != false ]]; then
		is_base64=false
	fi
	
	# ----------
	
	if [[ $is_base64 == true ]]; then
		echo -n "$string" | tr '+/=' '-_*'
	else
		echo -n "$string" | base64 -w 0 | tr '+/=' '-_*'
	fi
}

base64_url_decode() {
	local string=$1
	
	# ----------
	
	echo -n "$string" | tr -- '-_*' '+/=' | base64 -d
}

cd_exit() {
	local path=$1
	
	# ----------
	
	debug "Can't enter the directory \"$path\"."
	
	exit 1
}

debug() {
	echo "$1" 1>&2
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
	local separator=${1-}
	local fields=${2-}
	
	# ----------
	
	if shift 2; then
		printf %s "$fields" "${@/#/$separator}"
	fi
}

url_encode() {
	local text=$1
	
	# ----------
	
	if [[ -n $text ]]; then
		printf "%s" "$text" | od -An -tx1 -v -w"${#text}" | tr ' ' % | tr -d $'\n'
	fi
}

usage() {
	echo ""
	echo "Usage: $0 [-b BACKGROUND] [-c COLOR] [-d DIRECTORY] [-f FORMAT] [-h] [-k] [-s SIZE] [-t TEXT]"
	echo ""
	echo "  -b: Image background: \"colored\" or \"white\". If empty, the background will be transparent."
	echo "  -c: Hex or RGB color. If empty, a random color will be used."
	echo "  -d: Directory where to save the images. If empty, the current script directory will be used."
	echo "  -f: Image format: \"png\" or \"svg\". If empty, the format will be \"svg\"."
	echo "  -h: Display help."
	echo "  -k: Kill the PHP built-in web server if it's running. It'll override configuration settings."
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
# CONSTANTS
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

################################################################################
# ARGUMENTS
################################################################################

solacon_background="" # -b
solacon_color=""      # -c
solacon_dir=""        # -d
solacon_format=""     # -f
solacon_size=""       # -s
solacon_text=""       # -t

while getopts ':b:c:d:f:hks:t:' opt; do
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
			conf_keep_web_server_running=false
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

solacon_img=$solacon_img_tpl
php_web_server_pid=""

if wget --spider "http://$conf_solacon_local_base_url/" &> /dev/null; then
	php_web_server_pid=$(pgrep -f "php -S $conf_solacon_local_base_url")
	solacon_url="http://$conf_solacon_local_base_url/"
elif type -p php > /dev/null; then
	if [[ $conf_solacon_path_to_index_html == "../index.html" ]]; then
		conf_solacon_path_to_index_html="$SCRIPT_DIR/$conf_solacon_path_to_index_html"
	fi
	
	cd "${conf_solacon_path_to_index_html%/*}" || cd_exit "${conf_solacon_path_to_index_html%/*}"
	php -S "$conf_solacon_local_base_url" > /dev/null 2>&1 &
	php_web_server_pid=$!
	solacon_url="http://$conf_solacon_local_base_url/"
else
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

headless_cmd=("$conf_chrome_path" "--headless" "--virtual-time-budget=10000" "--timeout=10000" "--dump-dom" "$solacon_url")

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
	
	html=$("${headless_cmd[@]}" 2> /dev/null)
	string_base64=$(grep -m 1 -oP ' data-stringbase64="\K[^"]+' <<< "$html")
	string_base64_url=$(base64_url_encode "$string_base64" true)
	string=$(echo -n "$string_base64" | base64 -d)
	color=$(grep -m 1 -oP ' data-color="\K[^"]+' <<< "$html")
	
	if [[ $conf_add_string_to_image_name == true ]]; then
		solacon_img=${solacon_img_tpl//"%STRING%"/"-$string_base64_url"}
	else
		solacon_img=${solacon_img_tpl//"%STRING%"/}
	fi
	
	debug "--------------------"
	debug "Date:                $(date -d "@${current_date%%.*}" "+%Y-%m-%d %H:%M:%S")"
	debug "Solacon URL:         $solacon_url"
	
	if [[ -n $php_web_server_pid ]]; then
		debug "PHP web server PID:  $php_web_server_pid"
	fi
	
	debug "--------------------"
	debug "Format:              $solacon_format"
	debug "Color:               $color"
	debug "Background:          $solacon_background"
	debug "Size:                $solacon_size"
	debug "--------------------"
	debug "String:              $string"
	debug "String (base64):     $string_base64"
	debug "String (base64_url): $string_base64_url"
	debug "--------------------"
	
	if [[ $conf_return_image_content == false ]]; then
		debug "File:                $solacon_img"
	fi
	
	grep -m 1 -oP "$grep_regex_img" <<< "$html" | base64 -d > "$solacon_img"
	
	((i++))
done

delete_image=false

if image_is_valid "$solacon_img"; then
	if [[ $solacon_format == "svg" ]]; then
		sed -Ei 's#(fill="rgba\(([0-9]{1,3}),([0-9]{1,3}),([0-9]{1,3}), ([0-9.]{1,5})\)")#\1 style="fill:rgb(\2,\3,\4);fill-opacity:\5"#g' \
			"$solacon_img"
	fi
	
	if [[ -n $conf_log_file_name && ! $conf_log_file_name =~ "/"$ ]]; then
		log_file="$SCRIPT_DIR/${conf_log_file_name##*/}"
		image_hash=$(sha256sum "$solacon_img" | cut -d ' ' -f 1)
		echo "$current_date,$string,$color,${solacon_img##*/},$image_hash" >> "$log_file"
	fi
	
	if [[ $conf_return_image_content == true ]]; then
		cat "$solacon_img"
		delete_image=true
	fi
else
	delete_image=true
fi

if [[ $delete_image == true ]]; then
	rm -f "$solacon_img"
fi

if [[ -n $php_web_server_pid && $conf_keep_web_server_running == false ]]; then
	kill "$php_web_server_pid"
fi
