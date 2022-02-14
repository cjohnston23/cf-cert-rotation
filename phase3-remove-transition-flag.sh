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

# Generate Transition CA Version for each CA
for i in ${CALISTCLEAN}
  do
    echo $i

    # Delete diego_instance_identity_ca to allow bosh deploy to recreate
    if [[ ${i} =~ .*diego_instance_identity_ca.* ]]; then
      echo "deleting diego_instance_identity_ca"
      echo
      credhub delete --name=${i}
    else
      # Get ID for Contcatenate CA
      CERTID=$(credhub curl -p "/api/v1/certificates?name=${i}" | jq -r '.certificates[].id')
      echo "CA Cert ID  ${CERTID}"
      # Get ID of the old CA
      OLDCAID=$(credhub curl -p "/api/v1/certificates?name=${i}" | jq -r '.certificates[] | .versions |  sort_by(.expiry_date) | .[0].id')
      echo "Old CA ID ${OLDCAID}"
      # Remove the Transitional Flag from the old certificate
      # Only one certificate ID should be active, the one with the false flag
      credhub curl -p /api/v1/certificates/${CERTID}/update_transitional_version -d '{"version": null}' -X PUT

      # Clean up and delete the old CA and go back to a single version
      credhub curl -p "/api/v1/certificates/${CERTID}/versions/${OLDCAID}" -i -X DELETE
    fi
  done
