# 96boards-d3-mezzanine
Testing D3 mezzanine


# this has been tested with following kernel/branch:
https://git.linaro.org/people/loic.poulain/linux.git/log/?h=mainline-d3-mezzanine

## build steps
ARCH=arm64 make defconfig qcom.config
make


Example:

# Video preview (720p) camera native format (request GUI)
sh d3-ov5640-db410c.sh preview UYVY8_2X8 720p

# Video preview (vga) with NV12 format (display native)
# Convertion from camera UYVY8_2X8 to UYVY8_1_5X8 (NV12) is done in hardware
sh d3-ov5640-db410c.sh preview UYVY8_1_5X8 vga

# Record video in mp4/h264 (hardware encoding)
sh d3-ov5640-db410c.sh recordmpg UYVY8_2X8 1080p

# Take a snapshot
sh d3-ov5640-db410c.sh snapshot UYVY8_2X8 1080p

# Stream video via rtp (sent to 192.168.1.35, script variable)
sh d3-ov5640-db410c.sh rtp UYVY8_2X8 720p




