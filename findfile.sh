# Such srcipt accepted a file name, and determine where such file can be reach from current working path as parent directory
# Note: 
# - if there exists several paths, only 1 of them will show
# - if there no such path, the original path after symbol link expand will show

fileName="$1"
curPath="$PWD"

if [[ ! -a $fileName ]]
then
	# output error message to standard error
	echo "File not exist" >&2
	exit -1
fi

# If it is symbol link, then expand to target, such that the call of dirname will work OK
if [[ -L "$fileName" ]]
then
	fileName="$(readlink "$fileName")"
fi

# Seperate the file base name and the file directory name
if [[ -n "$fileName" && ! -d "$fileName" ]]
then
	filePath="$(cd "$(dirname "$fileName")" && pwd)"
	basename="$(basename "$fileName")"
elif [[ -d "$fileName" ]]
then
	filePath="$fileName"
else
	filePath="$(cd "$(dirname "$fileName")" && pwd)"
fi

# To Save all the symbol links
array=()

# To temporary save the new found symbol links
tmparray=()

# To save the targets pointed by the symbol links
declare -A linkExisted

# Merge the new symbol links from tmparray to the array
function mergeLinkExist ()
{
	local j=0
	while [[ $j < ${#tmparray[@]} ]]
	do
		# To get the final target of the link
		theLink="$(readlink -v -f "${tmparray[$j]}")"
		if [[ -d "$theLink" ]]
		then
			if [[ ! -n "${linkExisted[$theLink]}" ]]
			then
				linkExisted["$theLink"]="${tmparray[$j]}"
				array=("${array[@]}" "${tmparray[$j]}")
			fi
		fi
		((j=$j+1))
	done
}

tarPath=$fileName
if [[ ! "$filePath" == "$curPath"* ]]
then
	# Read the all symbol links of current directory and the sub directory to the tmparray
	readarray -d $'\0' tmparray < <(find . -type l -print0)
	mergeLinkExist

	i=0
	while [[ $i < ${#array[@]} ]]
	do
		if [ -d "${array[$i]}" ]
		then
			# Read the all symbol links of such directory and its sub directory to the tmparray
			readarray -d $'\0' tmparray < <(find "${array[$i]}/" -type l -print0)
			mergeLinkExist
		fi
		((i=$i+1))
	done

	for i in "${!linkExisted[@]}"
	do
		if [[ "$fileName" == "$i"* ]]
		then
			# Join link path to form target path
			tarPath="${linkExisted[$i]}"${fileName##"$i"}
			break
		fi
	done
fi

echo -n $tarPath

