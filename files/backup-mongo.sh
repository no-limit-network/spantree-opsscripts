#!/usr/bin/env bash

TMP_DIR=/var/db/mongobackups

prereqs () {
cat << EOF
${0} assumes you have the following components:

   * tar
   * mongo
   * mongodump

EOF
}

prereqs_s3 () {
cat << EOF
${0} assumes you have the following components:

   * s3cmd configured (run s3cmd --configure)

EOF
}

usage () {
cat << EOF
usage: ${0} [OPTIONS]

OPTIONS:
  -n | --name                 label (mandatory)
  -b | --bucket               s3 bucket (optional)

EXAMPLE:
   Create backup of all the mongo databases in a local server, archive them on a file named 'LABEL.tar.gz'
   and upload to bucket 'bucketname'
     ${0} -b bucketname -n LABEL
   Create backup of all the mongo databases in a local server and archive them on a file named 'LABEL.tar.gz'
     ${0} -n LABEL
EOF
}

if [[ $# < 1 ]]; then
  usage
  exit 1
fi

TAR=$(command -v tar)
MONGO=$(command -v mongo)
MDUMP=$(command -v mongodump)

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
      S3CMD=$(command -v s3cmd)
      shift
      ;;
  esac
done

if [ -z "${LABEL}" ]; then
  echo "Label is mandatory"
  usage
  exit 1
fi

if [[ -z ${TAR} ]] || [[ -z ${MONGO} ]] || [[ -z ${MDUMP} ]]; then
  prereqs
  echo "One of the following tools is missing: tar, s3cmd, mongo, mongodump"
  exit 1
fi

# if bucket not specified we do not test for s3cmd
if [ ! -z "${S3BUCKET}" ]; then 
  if [ -z ${S3CMD} ]; then
    prereqs_s3
    echo "One of the following tools is missing: tar, s3cmd, mongo, mongodump"
    exit 1
  fi
  # check that s3cmd is configured
  ${S3CMD} 2>&1 | grep "Consider using --configure" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "s3cmd needs to be configured for this script to be run"
    echo "Run s3cmd --configure"
    exit 1
  fi
fi

if test -z "${TMP_DIR}"; then
  # just being extra cautios 
  exit 1
fi
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"/{out,bak}
OUT_DIR="${TMP_DIR}/out"
BAK_DIR="${TMP_DIR}/bak"

pushd "${TMP_DIR}" > /dev/null 2>&1

BACKUP_FILE="${BAK_DIR}/${LABEL}.tar.gz"

lock_db () {
  echo "Locking mongo database"
  ${MONGO} admin --eval 'printjson(db.fsyncLock());' > /dev/null 2>&1
}

unlock_db () {
  echo "Unlocking mongo database"
  ${MONGO} admin --eval 'printjson(db.fsyncUnlock());' > /dev/null 2>&1
}

do_backup () {
  lock_db
  echo "Backing up mongo database"
  ${MDUMP} -o "${OUT_DIR}" > /dev/null 2>&1
  unlock_db
}

pushd "${OUT_DIR}" > /dev/null 2>&1

do_backup 

${TAR} -czf "${BACKUP_FILE}" *

if [ ! -z "${S3BUCKET}" ]; then
  ${S3CMD} put "${BACKUP_FILE}" s3://"${S3BUCKET}"/backup/
  # if command succeds then remove temp file
  if [ $? -ne 0 ]; then
    if test -z "${BACKUP_FILE}"; then
      # just being extra cautios
      exit 1
    fi
    rm -rf "${BACKUP_FILE}"
  fi
else
  echo "Bucket not specified so skipping s3 upload"
  echo "Backup file is located in ${BACKUP_FILE}"
fi

popd > /dev/null 2>&1
popd > /dev/null 2>&1

