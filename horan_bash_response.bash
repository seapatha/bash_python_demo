#!/usr/local/bin/bash
set -m #allow job control to avoid fg problems in execute_job
STATSDIR="${HOME}/jobstats"
rm -fr $STATSDIR
mkdir -p "${STATSDIR}/started"
mkdir -p "${STATSDIR}/finished"
mkdir -p "${STATSDIR}/failed"
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
	if [[ -f "${STATSDIR}/abort" ]]; then
		echo "Not executing ${1}.  Abort condition exists with job $(cat "${STATSDIR}/abort")."
		return
	fi	
	startfile="${STATSDIR}/started/${1}"
	if [[ ! -f "${startfile}" ]]; then
		touch "${startfile}"
		echo "Executing Job ${1}"
		eval ./$1 &
		echo $! > "${startfile}"
		fg > /dev/null
		rc=$?
		echo "Job ${1} is finished."
		touch "${STATSDIR}/finished/${1}"
		if [[ ! $rc -eq 0 ]]; then
			echo $1 > "${STATSDIR}/abort"
			echo "JOB ${1} FAILED:  Exit status ${rc}."
			echo "Future jobs will not be executed."
			echo $rc > "${STATSDIR}/failed/${1}"
		else
			echo $1 > "${STATSDIR}/success/${1}"
		fi
	fi
}

function wait_job {
	job="$1"
	readarray -td ' ' mydeps <<< "${deps[$job]}"
	waitsneeded="${#mydeps[@]}"
	while [[ $waitsneeded -eq 0 ]]; do
		for dep in ${mydeps[@]}; do
			dep=$(echo $dep |tr -d '\n')
			if [ -f "${STATSDIR}/finished/${dep}" ]; then
				let waitsneeded-=1
			else
				echo "Waiting for ${job}'s dependencies to finish"
				wait $(cat "${STATSDIR}/started/${job}")
			fi	
		done
	done
	execute_job $job
}

for job in "${!deps[@]}"; do
	wait_job $job &
done
finished=0
numdeps="${#deps[@]}"
while [[ $finished -ne $numdeps ]]; do
	echo "$finished finished, $numdeps total"
	sleep 1	
	if [[ -f "${STATSDIR}/abort" ]]; then
		echo "Abort condition detected.  Exiting."
		exit 1
	else
		finished=$(ls -l ${STATSDIR}/finished/* 2> /dev/null|wc -l|xargs)
	fi
done
echo "All jobs finished."
