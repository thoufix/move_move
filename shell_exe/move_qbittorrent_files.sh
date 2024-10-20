#!/bin/bash

LOG_FILE="/home/pi/shell_exe/move_qbittorrent_files.log"
TORRENT_BASE_DIR="/mnt/ssd/mnt/ssd/Downloads"  # Correct path

# Log when the script is triggered
echo "Script triggered at $(date)" >> "$LOG_FILE"

# Ensure the base torrent directory exists
if [ ! -d "$TORRENT_BASE_DIR" ]; then
    echo "Torrent base directory does not exist: $TORRENT_BASE_DIR" >> "$LOG_FILE"
    exit 1
fi

# Function to move entire folder including all related files
move_entire_folder() {
    local folder_name="$1"
    local destination="$2"
    
    # Ensure the destination exists
    if [ ! -d "$destination" ]; then
        echo "Destination folder does not exist, creating: $destination" >> "$LOG_FILE"
        mkdir -p "$destination"
    fi
    
    echo "Moving entire folder $folder_name to $destination" >> "$LOG_FILE"
    mv "$TORRENT_BASE_DIR/$folder_name" "$destination"
}

# Function to move TV show files to the appropriate season folder
move_tv_show() {
    local folder_name="$1"
    
    # Normalize show name for matching
    show_name=$(echo "$folder_name" | sed -E 's/\.[sS][0-9]+[eE][0-9]+.*//g' | tr '.' '_')
    
    # Extract the season information
    season=$(echo "$folder_name" | grep -oE '[sS][0-9]{2}|Season [0-9]+' | tr 's' 'S')

    # Clean up show name to prepare for search
    show_name=$(echo "$show_name" | sed -E 's/_/ /g; s/[[:space:]]+/ /g; s/[[:space:]]+$//; s/^[[:space:]]+//; s/ [0-9]{4}$//')

    echo "Extracted show name: $show_name" >> "$LOG_FILE"
    echo "Extracted season: $season" >> "$LOG_FILE"
    
    # Search for the correct destination directory
    # Normalize the search for underscores and space variations
    search_pattern=$(echo "$show_name" | sed 's/ /_/g')

    # Find matching directories
    destination_dir=$(find /mnt/ssd/mnt/ssd/Downloads/tvshows/ -type d -name "*${search_pattern}*" | head -n 1)

    if [ -n "$destination_dir" ]; then
        move_entire_folder "$folder_name" "$destination_dir"
    else
        echo "No matching folder found for $folder_name with show name $show_name and season $season" >> "$LOG_FILE"
        
        # If no matching directory is found, create one
        new_directory="${search_pattern}_${season:-Complete}"
        echo "Creating new directory: $new_directory" >> "$LOG_FILE"
        mkdir -p "/mnt/ssd/mnt/ssd/Downloads/tvshows/$new_directory"
        move_entire_folder "$folder_name" "/mnt/ssd/mnt/ssd/Downloads/tvshows/$new_directory"
    fi
}

# Function to move movie files after they have been seeding for 5 minutes (300 seconds)
move_movie() {
    local folder_name="$1"
    
    # Check if the folder exists and has been seeding for at least 5 minutes
    if [ -d "$TORRENT_BASE_DIR/$folder_name" ]; then
        # Get the last modified time of the folder in seconds since epoch
        last_modified=$(stat -c %Y "$TORRENT_BASE_DIR/$folder_name")
        current_time=$(date +%s)
        let "seed_time=current_time-last_modified"
        
        # Check if it has been more than 5 minutes (300 seconds)
        if [ "$seed_time" -gt 300 ]; then
            move_entire_folder "$folder_name" "/mnt/ssd/mnt/ssd/Downloads/movies/"
        else
            echo "$folder_name is still seeding or has not been active for 5 minutes, skipping for now." >> "$LOG_FILE"
        fi
    else
        echo "$folder_name does not exist in the torrent base directory." >> "$LOG_FILE"
    fi
}

# Main logic: Loop through all folders and files in the torrent directory
for torrent_path in "$TORRENT_BASE_DIR"/*; do
    folder_basename=$(basename "$torrent_path")
    
    # Skip category folders (movies and tvshows)
    if [[ "$folder_basename" == "movies" || "$folder_basename" == "tvshows" ]]; then
        echo "Skipping category folder: $folder_basename" >> "$LOG_FILE"
        continue
    fi
    
    echo "Processing: $folder_basename" >> "$LOG_FILE"
    
    # Check if file is still being downloaded (has .!qb extension)
    if [ -f "$torrent_path" ] && [[ "$torrent_path" == *.!qb ]]; then
        echo "$folder_basename is still downloading, skipping." >> "$LOG_FILE"
        continue
    fi
    
    # Handle TV shows (updated regex)
    if [[ -d "$torrent_path" && ("$folder_basename" =~ [sS][0-9]{2}[eE][0-9]{2} || "$folder_basename" =~ Season\ [0-9]+) ]]; then
        move_tv_show "$folder_basename"
        
    # Handle Movies
    elif [[ -d "$torrent_path" && "$folder_basename" != "tvshows" && "$folder_basename" != "movies" ]]; then
        move_movie "$folder_basename"
    
    # Handle other cases
    else
        echo "$folder_basename is a folder or does not match the criteria, skipping." >> "$LOG_FILE"
    fi
done
