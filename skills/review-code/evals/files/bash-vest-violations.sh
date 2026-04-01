#!/bin/bash

# Deploy script for staging environment

DEPLOY_DIR=/opt/app/staging
BACKUP_DIR=/opt/app/backups

deploy() {
    echo "Starting deployment to $DEPLOY_DIR"

    # Create backup
    timestamp=`date +%Y%m%d_%H%M%S`
    cp -r $DEPLOY_DIR $BACKUP_DIR/backup_$timestamp

    # Pull latest code
    cd $DEPLOY_DIR
    git pull origin main

    # Install dependencies
    for file in $(ls requirements/*.txt); do
        pip install -r $file
    done

    # Run migrations
    python manage.py migrate

    # Restart service
    if [ $? = 0 ]; then
        systemctl restart app-staging
        echo "Deploy complete"
    else
        echo "Migration failed, rolling back"
        cp -r $BACKUP_DIR/backup_$timestamp/* $DEPLOY_DIR/
    fi
}

cleanup() {
    # Remove old backups
    backups=$(ls -t $BACKUP_DIR | tail -n +6)
    for b in $backups; do
        rm -rf $BACKUP_DIR/$b
    done
}

deploy
cleanup
