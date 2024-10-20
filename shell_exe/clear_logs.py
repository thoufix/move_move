import os

# Define the log files to clear
log_files = [
    '/home/pi/shell_exe/move_qbittorrent_files.log',
    '/home/pi/shell_exe/watchdog.log'
]

# Clear the log files
for log_file in log_files:
    try:
        with open(log_file, 'w') as file:
            file.truncate(0)  # Clear the contents
        print(f"Cleared: {log_file}")
    except Exception as e:
        print(f"Error clearing {log_file}: {e}")
