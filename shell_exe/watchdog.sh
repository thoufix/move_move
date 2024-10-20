#!/bin/bash

# Path to the script you want to trigger
SCRIPT_TO_RUN="/home/pi/shell_exe/move_qbittorrent_files.sh"

# Torrent base directory to watch
TORRENT_BASE_DIR="/mnt/ssd/mnt/ssd/Downloads"  # Correct path

# Log file for the watchdog
WATCHDOG_LOG="/home/pi/shell_exe/watchdog.log"

# Idle time threshold (in seconds)
IDLE_THRESHOLD=300  # 5 minutes for longer idle detection

echo "Watchdog started at $(date)" >> "$WATCHDOG_LOG"

# Infinite loop to periodically check the directory
while true; do
    sleep 300  # Wait for 5 minutes before each check

    # Loop through each folder in the torrent base directory
    for torrent_folder in "$TORRENT_BASE_DIR"/*; do
        if [ -d "$torrent_folder" ]; then
            folder_basename=$(basename "$torrent_folder")
            
            # Skip the main categories folder like "movies" and "tvshows"
            if [[ "$folder_basename" == "movies" || "$folder_basename" == "tvshows" ]]; then
                continue
            fi

            # Get the last modified time of the folder
            last_modified=$(stat -c %Y "$torrent_folder")
            current_time=$(date +%s)
            let "idle_time=current_time-last_modified"
            
            # Check if the folder has been idle for more than the threshold
            if [ "$idle_time" -gt "$IDLE_THRESHOLD" ]; then
                # Check if there are incomplete downloads (.part or .!qB files)
                if [ -z "$(find "$torrent_folder" -name '*.part' -o -name '*.!qB')" ]; then
                    echo "Detected completed download: $folder_basename at $(date)" >> "$WATCHDOG_LOG"
                    
                    # Trigger the existing move script
                    bash "$SCRIPT_TO_RUN"

                    # Optionally, remove the folder or perform additional actions
                    # rm -r "$torrent_folder"  # Uncomment to delete after moving
                else
                    echo "Download not complete for: $folder_basename, skipping at $(date)" >> "$WATCHDOG_LOG"
                fi
            fi
        fi
    done
done
