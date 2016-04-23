#!/bin/bash
set -eo pipefail

# Load config.  Default to "config.sh" in the same directory as the script.
confpath="${1:-$(dirname $0)/config.sh}"
source "$confpath"

# Clean up lingering tmp files from previous runs.
rm "${BACKUP_DIR}"/mysql-backup.*.sql.bz2.gpg.tmp 2>/dev/null || true

# And clean up backups from the previous month, to keep the directory lean.
last_month="$(date -u '+%Y-%m' --date='last month')"
rm "${BACKUP_DIR}"/mysql-backup.${last_month}-*.sql.bz2.gpg 2>/dev/null || true

# Prepare the backup file name with the current date (in UTC).
ts="$(date -u '+%Y-%m-%d_%H%M%S')"
backup_path="${BACKUP_DIR}/mysql-backup.${ts}.sql.bz2.gpg"

# Dump the nominated databases, compress, and encrypt them.
# "${GPGKEYS[@]/#/--recipient=}" converts the array of keys into a series of
# "--recipient=KEY" parameters.
# We pipe to a .tmp file so that other scripts that may be running concurrently
# can search for *.gpg and be certain not to read a truncated file.
mysqldump --defaults-file="$DEFAULTS_FILE" --databases $TABLES \
  | bzip2 -9 \
  | gpg --batch --trust-model always \
    --encrypt "${GPGKEYS[@]/#/--recipient=}" \
  > "${backup_path}.tmp"

# Move the backup to it's proper place.
mv "${backup_path}.tmp" "${backup_path}"
