#!/usr/bin/env bash

TMP_DIR=/tmp/backup

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
  -b | --bucket               s3 bucket (mandatory)

EXAMPLE:
     ${0} -b bucketname -n LABEL

EOF
}

if [[ $# < 1 ]]; then
  usage
  exit 1
fi

TAR=$(command -v tar)
MONGO=$(command -v mongo)
MRESTORE=$(command -v mongorestore)

while [[ $# > 1 ]]
do
  key="${1}"
  shift
  case ${key} in
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

if [[ -z ${TAR} ]] || [[ -z ${MONGO} ]] || [[ -z ${MRESTORE} ]]; then
  prereqs
  echo "One of the following tools is missing: tar, mongo, mongorestore"
  exit 1
fi

# if bucket not specified we do not test for s3cmd
if [ ! -z ${S3BUCKET} ]; then 
  if [ -z ${S3CMD} ]; then
    prereqs_s3
    echo "s3cmd is missing. aborting."
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

BACKUP_FILE="${BAK_DIR}/${LABEL}.tar.gz"

pushd "${OUT_DIR}" > /dev/null 2>&1

s3get () {
  if [ ! -z "${S3BUCKET}" ]; then
    ${S3CMD} get --force "s3://${S3BUCKET}/backup/${LABEL}.tar.gz" "${BACKUP_FILE}"
    if [ $? -ne 0 ]; then
      echo "S3CMD failed"
      exit 1
    fi
  fi
}

extract () {
  echo "extracting ${BACKUP_FILE} to ${OUT_DIR}"
  ${TAR} xzf "${BACKUP_FILE}" -C "${OUT_DIR}"
}

DROPDB="${TMP_DIR}/dropalldbs.js"

cat << EOF > "${DROPDB}"
var dbs = db.getMongo().getDBNames()
for(var i in dbs){
  db = db.getMongo().getDB( dbs[i] );
  print( "dropping db " + db.getName() );
  db.dropDatabase();
}
EOF

dropdb () {
  ${MONGO} "${DROPDB}"
}

restoredb () {
  ${MRESTORE} "${OUT_DIR}"
}

s3get
extract
dropdb
restoredb

popd > /dev/null 2>&1

