#!/usr/bin/env bash

prereqs () {
cat << EOF
${0} assumes you have the following components:

   * curl.
   * s3 bucket with write and read permission.
   * elasticsearch (locally running).
   * elasticsearch aws plugin configured (see https://github.com/elasticsearch/elasticsearch-cloud-aws#generic-configuration). 

EOF
}

usage () {
cat << EOF
usage: ${0} [OPTIONS]

OPTIONS:
  -n | --name                 label (mandatory)
  -b | --bucket               s3 bucket (mandatory)

EXAMPLE:
   Create s3 snapshot backup of all the elasticsearch indices in a local server, archive them on a snapshot named 'LABEL'.
     ${0} -b bucketname -n LABEL
EOF
prereqs
}

if [[ $# < 1 ]]; then
  usage
  exit 1
fi

CURL=$(command -v curl)

if [[ -z "${CURL}" ]]; then
  prereqs
  echo "Missing curl tool."
  exit 1
else
  CURLCMD="${CURL} --connect-timeout 10"
fi

while [[ $# > 1 ]]
do
  key="${1}"
  shift
  case "${key}" in
    -n|--name)
      LABEL="${1}"
      shift
      ;;
    -b|--bucket)
      S3BUCKET="${1}"
      shift
      ;;
  esac
done

if [ -z "${LABEL}" ]; then
  echo "Label is mandatory"
  usage
  exit 1
fi

# if bucket not specified we do not test for s3cmd
if [ -z "${S3BUCKET}" ]; then 
  echo "The s3 bucket is mandatory"
  usage
  exit 1
fi

setup_snapshot_repo () {
  echo "Creating s3 backed snapshot repository in bucket ${S3BUCKET}"
  ${CURLCMD} -sS -XPUT 'http://127.0.0.1:9200/_snapshot/backup?wait_for_completion=true&pretty' -d '{ "type": "s3", "settings": { "bucket": "'"${S3BUCKET}"'" } }'
}

create_snapshot () {
  echo "Creating snapshot into bucket s3://${S3BUCKET}/backup with label ${LABEL}"
  $CURLCMD -sS -XPUT "http://127.0.0.1:9200/_snapshot/backup/"${LABEL}"?wait_for_completion=true&pretty" | tee /tmp/out | grep state | grep -q SUCCESS
  if [ $? -ne 0 ]; then
    echo "creation of snapshot failed"
    cat /tmp/out
  fi
}

setup_snapshot_repo
create_snapshot

