# Such srcipt accepted a file name, and determine where such file can be reach from current working path as parent directory
# Note: 
# - if there exists several paths, only 1 of them will show
# - if there no such path, the original path after symbol link expand will show
declare -a ans
declare -a softLinkList
declare -A pathLinkMap
srcFileName=

# In order to switch debug output easily, define the variable dbg_echo
# dbg_echo=echo
dbg_echo="eval # ||"

function show_answer_and_exit()
{
	echo "$1"
	exit 0
}

function show_useage_and_exit()
{
	if [[ -n "$1" ]]
	then
		echo "$1" >&2
	fi
	cat  >&2 <<-USAGE
	Usage: $0 [file]
	USAGE
	exit -1
}

function show_error_and_exit()
{
	echo "$1" >&2
	exit -1
}

function try_the_link_path()
{
	$dbg_echo -n "$1 -v.s.- $2: "
	if [[ "$1" == "$2"* ]]
	then
		$dbg_echo "Pass"
		return 1
	else
		$dbg_echo "Fail"
		return 0
	fi
}

# $1 is the softlink
# The softlink list and linkpath map might updated
function handle_a_link()
{
	local curLink="$1"
	local curLinkPath="$(readlink -f "$curLink")"

	$dbg_echo "handling: $curLink --> $curLinkPath"
	if [[ -d "$curLinkPath" ]]
	then
		try_the_link_path "$srcFileName" "$curLinkPath"
		if [[ $? -eq 1 ]]
		then
			local ansPath="${curLink##"$curPath/"}${fileName##"$curLinkPath"}"
			if [[ ! -n "$ansPath" ]]
			then
				ansPath="."
			fi
			show_answer_and_exit "$ansPath"
		fi
		if [[ ! -n "${pathLinkMap[$curLinkPath]}" ]]
		then
			$dbg_echo "find and add new link from path: $curLinkPath: ${pathLinkMap[$curLinkPath]}"
			add_links_from_a_path "$curLinkPath"
			pathLinkMap["$curLinkPath"]="$curLink" # If need to support multipath, this should use array list
		fi
	fi
}

function add_links_from_a_path()
{
	local curPath="$1"

	readarray -d $'\0' tmparray < <(find "$curPath" -type l -print0)
	softLinkList=("${softLinkList[@]}" "${tmparray[@]}")
	$dbg_echo "current linklist of ($curPath): ""${softLinkList[@]}"
}

function search_links_of_path()
{
	local curPath="$1"
	add_links_from_a_path "$curPath"
	local i=0
	while [[ $i < ${#softLinkList[@]} ]]
	do
		handle_a_link "${softLinkList[$i]}"
		((i=$i+1))
	done
	return 1
}

function is_file_in_path()
{
	local file="$1"
	local curPath="$2"
	
	if [[ "$file" == "$curPath"* ]]
	then
		return 1
	fi

	local absFileDir="$(cd "$(dirname "$fileName")" && pwd)"
	local absCurPath="$(cd "$curPath" && pwd)"

	if [[ "$absFileDir" == "$absCurPath"* ]]
	then
		return 1
	fi

	return 0
}

fileName="$1"
curPath="$PWD"

if [[ ! -a "$fileName" ]]
then
	# output error message to standard error
	if [[ -n "$fileName" ]]
	then
		show_useage_and_exit "Error: Bad file name: $1"
	else
		show_useage_and_exit "Error: Please input a file"
	fi
fi

is_file_in_path "$fileName" "$curPath"
if [[ $? -eq 1 ]]
then
	show_answer_and_exit "$fileName"
elif [[ -L "$fileName" ]]  # If it is symbol link, then expand to target, such that the call of dirname will work OK
then
	srcFileName="$(readlink "$fileName")"
	is_file_in_path "$srcFileName" "$curPath"
	if [[ $? -eq 1 ]]
	then
		show_answer_and_exit "$srcFileName"
	fi
else
	srcFileName="$fileName"
fi

search_links_of_path "$curPath"
ans=("$1")

show_answer_and_exit "${ans[@]}"

