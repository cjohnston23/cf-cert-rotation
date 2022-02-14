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

# Removing extra quotas and  sorting
# Sort is required to place the regeneration of application_ca prior to diego_instance_identity_ca
# diego_instance_identity_ca is signed by application_ca and therefore must go first
CALISTCLEAN=$(echo ${CALIST} | tr -d '"' | xargs -n1 | sort | xargs)

# Generate New Transition CA Version for each CA
for i in ${CALISTCLEAN}
  do
    echo $i
    # Delete diego_instance_identity_ca to allow bosh deploy to recreate
    if [[ ${i} =~ .*diego_instance_identity_ca.* ]]; then
      echo "deleting diego_instance_identity_ca"
      credhub delete --name=${i}
    else
      CERTID=$(credhub curl -p "/api/v1/certificates?name=${i}" | jq -r '.certificates[].id')
      echo $CERTID
      credhub curl -p "/api/v1/certificates/${CERTID}/regenerate" -d '{"set_as_transitional": true}' -X POST
      echo
    fi
  done
