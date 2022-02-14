# CFCE Certificate Rotation

## Using credhub concatentate option that allows for multiple "active" versions at the same time

## Procedure

1. Backup existing certs and deploymentmanifest prior to rotation
 
    * ```credhub export --path=/<director>/<deployment name> --file=ch-backup```
    * ```bosh -d deploymentname manifest > deploymentname-backup.yml```

2.  Regenerate your CA certificate with the transitional flag. This creates a new version that will not be used for signing yet, but can be added to your servers trusted certificate lists. Then, propagate the concatenated CAs to your deployment (e.g. BOSH redeploy).
    
    * Ensure all bosh and credhub env vars are set in your shell for access and authentication
    * Use the vault-env function if you store creds in vault.
       *  ``` 
          'vault-env <vault-path-to-creds>'
          ```
          
          ```
          vault-env () {
                         eval "$(
                            vault read -format json $1 |
                            jq -r '.data|to_entries[]|"export \(.key)=\"\(.value)\""'
                          )"
                        }
          ```
          
    * Validate that credhub CA's have only one credhub version of the certificate, see commands below.  It is VERY important to cleanup/delete all previous versions except the one in use. 
      * ```./check_ca_certs.sh <bosh deployment name>```
    * execute ```phase1-generate-transition-ca.sh <bosh deployment name>```
    * validate new CA's have been created with transitional flag set to true
      * ```./check_ca_certs.sh <bosh deployment name>```
    * Run bosh deploy against cfce bosh deployment (use manifest backup file create earlier)
       * ```bosh deploy -d <bosh deployment name> backup.yml```

3. Remove the transitional flag from the new CA certificate, and add it to the old CA certificate. This means that the new certificate will start to be used for signing, but the old one will remain as trusted.  Delete all leaf certificates in prep for recreation during bosh deploy signed be the new CA's
    
    * execute ```phase2-move-transitional-delete-leafs.sh <bosh deployment name>```
    * Run bosh deploy against cfce bosh deployment
       * ```bosh deploy -d <bosh deployment name> manifest.yml```
    * Validate transition flag has moved from the New to the Old certificate
       * ```./check_ca_certs.sh <bosh deployment name>```
    
4. Remove the transitional flag from the old CA certificate and delete it so only new CA certificate version remains. Propagate changes to your deployment to remove old CA's (e.g. BOSH redeploy).
    
    * execute ```phase3-remove-transition-flag.sh <bosh deployment name>```
    * Run bosh deploy against the cfce bosh deployment
       * '''bosh deploy -d <bosh deployment name> manifest.yml'''
    * Validate that only a single version per ca certficate exists
       * ```./check_ca_certs.sh <bosh deployment name>```

## Automation is based on the guidance found in these docs

* https://github.com/pivotal/credhub-release/blob/main/docs/ca-rotation.md
* https://lists.cloudfoundry.org/g/cf-dev/message/7804
* https://docs.vmware.com/en/Spring-Cloud-Gateway-for-VMware-Tanzu/1.1/spring-cloud-gateway/GUID-rotating-certificates.html

## Usual Command Examples

#### Get list of all certificates

*   ```credhub curl -p "/api/v1/certificates"```
*   ```credhub curl -p "/api/v1/certificates?name=/test-deleteme" | jq ".certificates[].id"```

#### View transitional values cert meta data

* ```credhub curl -p "/api/v1/certificates?name=/test-deleteme"```

#### View transitional value and current active certificate and pems

* ```credhub curl -p "/api/v1/data?name=/test-deleteme&current=true"```

#### View transitional values, and certificates

* ```credhub curl -p "/api/v1/data?name=/test-deleteme"```

#### View Number of Certificate versions

* ```./check_ca_certs.sh <deployment name>```   
    
#### Delete unused certificate versions
    credhub curl -p "/api/v1/certificates/${CERT_ID}/versions/${UNUSED_CERT_ID}" -i -X DELETE

#### List All CA's for a deployment

```
export CFDEP=c-ho-g6-cf
credhub curl -p "/api/v1/certificates" -X GET | jq '.certificates[]
| select((.name | contains('\"${CFDEP}\"')) and
.versions[0].certificate_authority == true) | .name'
````

#### List Leaf Certs for a deployment

```
credhub curl -p "/api/v1/certificates" -X GET | jq '.certificates[] |
select((.name | contains('\"${CFDEP}\"')) and
.versions[0].certificate_authority == false) | .name'
```

#### Create test CA Cert

* ```credhub generate --name="/test-deleteme" --type=certificate --duration=730 --common-name=test-deleteme --is-ca --self-sign```

