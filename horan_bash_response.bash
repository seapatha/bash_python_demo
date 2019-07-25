#!/usr/local/bin/bash
STATSDIR="${HOME}/jobstats"
rm -fr $STATSDIR
mkdir -p "${STATSDIR}/started"
mkdir -p "${STATSDIR}/finished"
declare -A deps
deps[job1]=''
deps[job2]='job1'
deps[job3]='job1 job2'
deps[job4]='job1 job2'
deps[job5]='job1 job2'
deps[job6]='job1 job2 job4 job5'
deps[job7]='job1 job2'
deps[job8]='job1 job2'
deps[job9]='job1 job2'
deps[job10]='job1 job2 job3 job4 job5 job6 job7 job8 job9'

function execute_job {
	startfile="${STATSDIR}/started/${1}"
	if [ ! -f "${startfile}" ]; then
		touch "${startfile}"
		echo "Executing Job ${1}"
		eval ./$1
		echo "Job ${1} is finished."
		touch "${STATSDIR}/finished/${1}"
	fi
}

function wait_job {
	job="$1"
	readarray -td ' ' mydeps <<< "${deps[$job]}"
	waitsneeded="${#mydeps[@]}"
	for dep in ${mydeps[@]}; do
		dep=$(echo $dep |tr -d '\n')
		if [ -f "${STATSDIR}/finished/${dep}" ]; then
			let waitsneeded-=1
		fi
	done
	if [[ "${waitsneeded}" -eq 0 ]]; then
		execute_job $job &
	else
		echo "Waiting for ${job}'s dependencies to finish"
		sleep 1
		wait_job $job
	fi
}

for job in "${!deps[@]}"; do
	jobdeps=${deps[$job]}
	echo "$jobdeps" | grep -Eq '[0-9]'
	rc=$?
	if [[ $rc == 1 ]];  then
		echo "$job has no dependencies - executing"
		execute_job $job &
	else
		wait_job $job &
	fi
	#echo "value: ${array[$job]}"
done
finished=0
numdeps="${#deps[@]}"
while [[ $finished -ne $numdeps ]]; do
	echo "$finished finished, $numdeps total"
	sleep 1	
	finished=$(ls -l ${STATSDIR}/finished/* 2> /dev/null|wc -l|xargs)
done
echo "All jobs finished."
