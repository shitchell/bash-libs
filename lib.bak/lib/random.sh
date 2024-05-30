# @description Generate <n> random bits
# @usage generate-random-bits [n]
# @attribution https://unix.stackexchange.com/a/157837/538359
function generate-random-bits() {
	local n=${1} rnd=${RANDOM} rnd_bitlen=15
	
	# Verify n is an integer
	if ! [[ "${n}" =~ ^[0-9]+ ]]; then
		echo "error: arg must be an integer" >&2
		return 1
	fi

	# Add more $RANDOM bits to rnd until 
 	while (( rnd_bitlen < n )); do
		rnd=$(( rnd<<15|RANDOM ))
		let rnd_bitlen+=15
	done

	echo $(( rnd>>(rnd_bitlen-n) ))
}
