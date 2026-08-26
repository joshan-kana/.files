#
# volume_up.py: a script to turn up the volume and send a notification
#

# Import the required modules
import os

# Get the status of volume
volume_status = os.popen("wpctl get-volume @DEFAULT_AUDIO_SINK@").read()

# Extract the volume level from the status
volume_level = volume_status.split(" ")[-1]

# Extract if the volume is muted or not
# This is by checking if the volume status contains the word "[MUTED]"
volume_muted = "[MUTED]" in volume_status

# Send a notification to the user using dunstify
# The notification will contain a bar that represents the volume level


# print(volume_level)

# print(volume_muted)

# print(volume_status)
