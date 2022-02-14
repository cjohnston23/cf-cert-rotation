#!/bin/bash
#set -x

if [[ -z ${1} ]]; then
  echo "please provide deployment name"
  exit 1
fi

export CFDEP=${1}

CALIST=$(credhub curl -p "/api/v1/certificates" -X GET | jq '.certificates[]
| select((.name | contains('\"${CFDEP}\"')) and
.versions[0].certificate_authority == true) | .name')

CALISTCLEAN=$(echo ${CALIST} | tr -d '"' | xargs -n1 | sort | xargs)
#echo ${CALISTCLEAN}

#CALISTCLEAN=$(echo ${CALIST} | sort)
#echo ${CALISTCLEAyylkN}

# Generate Transition CA Version for each CA
for i in ${CALISTCLEAN}
  do
    echo ${i}
    credhub curl -p "/api/v1/certificates?name=${i}" | jq -r '.certificates[] | .versions[]'
    echo
    echo
  done
