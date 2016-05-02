#!/bin/bash
: ${BUCKET_NAME:=emdentec/backup}
: ${BACKUP_NAME:=$(hostname)} # defaults to the hostname of the container, which is the container id
: ${MAX_BACKUP_COUNT:=5} # number of backups to keep in storage

# abort if anything fails
set -e

# make sure the account id is set
if [[ -z $ACCOUNT_ID ]]; then
    echo "ACCOUNT_ID is a required environment variable. Run with \`-e ACCOUNT_ID=xxx\`."
    exit 1
# make sure the application key is set
elif [[ -z $APPLICATION_KEY ]]; then
    echo "APPLICATION_KEY is a required environment variable. Run with \`-e APPLICATION_KEY=xxx\`."
    exit 1
# make sure the volume path is set
elif [[ -z $VOLUME ]]; then
    echo "VOLUME is a required environment variable. Run with \`-e VOLUME=/path/to/volume\`."
    exit 1
# make sure the volume path is a directory
elif [[ ! -d $VOLUME ]]; then
    echo "$VOLUME was not a directory found on the host."
    exit 1
fi

# Authorize the account
b2 authorize_account ${ACCOUNT_ID} ${APPLICATION_KEY}

if [[ "$1" = 'b2' ]]; then

    # Switch to /tmp because that's where everything happens
    cd /tmp

    # Get the ID of the bucket if it exists
    B2_BUCKET_ID=$(b2 list_buckets | grep ${BUCKET_NAME} | awk '{print $1}')

    BACKUP_ARCHIVE_NAME="${BACKUP_NAME}.tar.bz2"

    if [[ "$2" = 'backup' ]]; then

        # Create the bucket if it doesn't exist
        if [[ -z $B2_BUCKET_ID ]]; then
            echo "Creating bucket ${BUCKET_NAME}..."
            B2_BUCKET_ID=$(b2 create_bucket ${BUCKET_NAME} allPrivate)
        fi

        echo "Backing up to bucket $BUCKET_NAME with ID $B2_BUCKET_ID..."

        if [ ! "$(ls -A "$VOLUME")" ]; then
            echo "$VOLUME is empty, aborting."
            exit 1
        fi

        echo "Copying directory to /tmp..."
        cp "$VOLUME" "/tmp/${BACKUP_NAME}" -R

        echo "Archiving directory..."
        tar -cjf "$BACKUP_ARCHIVE_NAME" "${BACKUP_NAME}"

        echo "Erasing directory copy /tmp..."
        rm -rf "/tmp/${BACKUP_NAME}"

        # Get the sha1 of the archive
        SHA_1=$(openssl dgst -sha1 $BACKUP_ARCHIVE_NAME | awk '{print $2;}')

        # Get the sha1 of the latest backup
        LATEST_UPLOAD_ID=$(b2 ls --long $BUCKET_NAME | grep $BACKUP_ARCHIVE_NAME | awk '{print $1}')
        LATEST_UPLOAD_SHA_1=$(b2 get_file_info $LATEST_UPLOAD_ID | jsawk 'return this.contentSha1')

        echo "Comparing previous sha1 ($LATEST_UPLOAD_SHA_1) with archive sha1 ($SHA_1)..."

        # Upload the backup
        if [[ $SHA_1 != $LATEST_UPLOAD_SHA_1 ]]; then
            echo "Uploading ${BACKUP_ARCHIVE_NAME}..."
            b2 upload_file \
                --sha1 $SHA_1 \
                --contentType "application/bzip2" \
                $BUCKET_NAME $BACKUP_ARCHIVE_NAME $BACKUP_ARCHIVE_NAME
        else
            echo "${BACKUP_ARCHIVE_NAME} has not changed since the previous backup."
        fi

        echo "Finding previous file versions for $BACKUP_ARCHIVE_NAME..."

        # Get a list of file versions that match the backup name
        b2 list_file_versions ${BUCKET_NAME} | \
            jsawk 'return this.files' | jsawk 'if (this.fileName != "'"$BACKUP_ARCHIVE_NAME"'") return null' > /tmp/file_versions
        FILE_VERSION_COUNT=$(cat /tmp/file_versions | jsawk -a 'return this.length')

        echo "$FILE_VERSION_COUNT file versions found (max: $MAX_BACKUP_COUNT)..."

        FILE_VERSION_SURPLUS=$(($FILE_VERSION_COUNT - $MAX_BACKUP_COUNT))

        if [[ $FILE_VERSION_SURPLUS -gt 0 ]]; then
            echo "Deleting $FILE_VERSION_SURPLUS surplus file versions..."

            # Get the identifiers for the stale revisions
            FILE_VERSIONS_TO_DELETE=$(cat /tmp/file_versions | \
                jsawk \
                    -b 'return _.sortBy(IS, "uploadTimestamp")' \
                    -a 'return RS.slice(0, '"$FILE_VERSION_SURPLUS"')' | \
                jsawk 'return this.fileId' \
                    -a 'return RS.join("\n")')

            while read -r FILE_VERSION; do
                b2 delete_file_version $BACKUP_ARCHIVE_NAME $FILE_VERSION
            done <<< "$FILE_VERSIONS_TO_DELETE"
        else
            echo "No surplus file versions."
        fi

        # Remove everything in the ephermeral directory (echo to prevent error code)
        rm -rf /var/lib/emdentec/backup/tmp/{*,.*} || echo "Removed ephemeral files"

    elif [[ "$2" = 'restore' ]]; then

        # Exit if the bucket doesn't exist
        if [[ -z $B2_BUCKET_ID ]]; then
            echo "No bucket with name $BUCKET_NAME found."
            exit
        fi

        # Get the latest backup file info
        LATEST_UPLOAD_ID=$(b2 ls --long $BUCKET_NAME | grep "\b$BACKUP_ARCHIVE_NAME\b" | awk '{print $1}')

        # Exit if no existing backups
        if [[ -z $LATEST_UPLOAD_ID ]]; then
            echo "No files with name $BACKUP_ARCHIVE_NAME found."
            exit
        fi

        # Remove everything in the ephermeral directory (echo to prevent error code)
        rm -rf /var/lib/emdentec/backup/tmp/{*,.*} || echo "Removed ephemeral files"

        b2 download_file_by_id $LATEST_UPLOAD_ID $BACKUP_ARCHIVE_NAME

        # Extract the file data
        tar xfj "$BACKUP_ARCHIVE_NAME"

        cp "/tmp/$BACKUP_NAME/." "$VOLUME/" -R
        chown -R $(stat $VOLUME -c %u:%g) $VOLUME

        rm $BACKUP_ARCHIVE_NAME
        rm -rf "/tmp/$BACKUP_NAME"
    fi
else
    exec "$@"
fi