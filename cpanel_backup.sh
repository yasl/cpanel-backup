#!/bin/bash
set -eo pipefail

# Load config.  Default to "config.sh" in the same directory as the script.
confpath="${1:-$(dirname $0)/config.sh}"
source "$confpath"

# Cleanup backup files from previous runs.
# The backups *include* the $HOME/backups directory, so this avoids nesting.
rm "${BACKUP_DIR}"/backup-*_"${CP_USER}".tar.gz.gpg 2>/dev/null || true
rm "${HOME}"/backup-*_"${CP_USER}".tar.gz.gpg 2>/dev/null || true

# Make an HTTP request to cPanel to prompt the creation of a new backup.
# Alas, `--netrc-file` is a newish curl parameter that we can't rely on.
curl --silent --http1.0 --netrc \
  "https://${CP_DOMAIN}:2083/frontend/${CP_SKIN}/backup/dofullbackup.html?submit=Generate Backup"

# Wait for the backup to be generated.
sleep "$WAITSECS"

# Encrypt the generated backup, including any made manually since last run.
# "${GPGKEYS[@]/#/--recipient=}" converts the array of keys into a series of
# "--recipient=KEY" parameters.
# We wait until the end to move the file into the backups directory so that
# other scripts that may be running concurrently can be certain to not read a
# truncated file.
for archive in "${HOME}"/backup-*_${CP_USER}.tar.gz ; do
  gunzip < "$archive" \
    | gzip -9 \
    | gpg --batch --trust-model always \
      --encrypt "${GPGKEYS[@]/#/--recipient=}" \
    > "${archive}.gpg"
  mv "${archive}.gpg" "${BACKUP_DIR}/"
  rm "${archive}"
done
