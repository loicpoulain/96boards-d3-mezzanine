#!/bin/sh
set -e

# example: ./ov5640-test.sh recordmpg UYVY8_2X8 1080p

MODE=${1}
FMT=${2}
RES=${3}
SENSOR_IDX=0
if [ ${SENSOR_IDX} -eq 1 ]; then
	SENSOR_SUBDEV="v4l-subdev11"
else
	SENSOR_SUBDEV="v4l-subdev10"
fi
SENSOR=`cat /sys/class/video4linux/${SENSOR_SUBDEV}/name | cut -f2 -d' '`
ENCODER_MAX_FR=30
RTP_CLIENT_IP="192.168.1.35"
VIDEO_DEV_RDI0="/dev/v4l/by-path/platform-1b0ac00.camss-video-index0"
VIDEO_DEV_RDI1="/dev/v4l/by-path/platform-1b0ac00.camss-video-index1"
VIDEO_DEV_PIX="/dev/v4l/by-path/platform-1b0ac00.camss-video-index3"

if [ $# -lt 3 ]; then
	echo "usage ${0} <mode> <format> <resolution> [fps]"
	echo "mode: [config|snapshot|preview|recordmpg|rtp|fb]"
	echo "format: [UYVY8_1_5X8|UYVY8_2X8|SBGGR8_1X8]"
	echo "resolution: [full|1080p|720p|vga]"
	exit 1
fi

if [ ${FMT} != "UYVY8_2X8" ] && [ ${FMT} != "SBGGR8_1X8" ] && [ ${FMT} != "UYVY8_1_5X8" ]; then
	echo "Unsupported format"
	exit 1
fi

if [ "${RES}" = "FULL" ] || [ "${RES}" = "full" ]; then
	WIDTH=2592
	HEIGHT=1944
	FRAMERATE=15
elif [ "${RES}" = "1080p" ] ||  [ "${RES}" = "hd" ]; then
	WIDTH=1920
	HEIGHT=1080
	FRAMERATE=30
elif [ "${RES}" = "720p" ]; then
	WIDTH=1280
	HEIGHT=720
	FRAMERATE=30
elif [ "${RES}" = "VGA" ]||  [ "${RES}" = "vga" ]; then
	WIDTH=640
	HEIGHT=480
	FRAMERATE=30
else
	echo "Unsupported resolution"
	exit 1
fi

media-ctl --reset || true

if [ ${FMT} = "UYVY8_1_5X8" ]; then
	# Use PIX interface, convert from UYVY8_2X8 to UYVY8_1_5X8(NV12)
	VIDEO_DEV=${VIDEO_DEV_PIX}
	FMT_BASE=UYVY8_2X8

	media-ctl -d /dev/media0 -l '"msm_csiphy'${SENSOR_IDX}'":1->"msm_csid'${SENSOR_IDX}'":0[1],"msm_csid'${SENSOR_IDX}'":1->"msm_ispif'${SENSOR_IDX}'":0[1],"msm_ispif'${SENSOR_IDX}'":1->"msm_vfe0_pix":0[1]';
	media-ctl -d /dev/media0 -V '"ov5640 '${SENSOR}'":0[fmt:'${FMT_BASE}'/'${WIDTH}x${HEIGHT}'@1/'${FRAMERATE}' field:none]'
	media-ctl -d /dev/media0 -V '"ov5640 '${SENSOR}'":0[fmt:'${FMT_BASE}'/'${WIDTH}x${HEIGHT}'@1/'${FRAMERATE}' field:none]'
	media-ctl -d /dev/media0 -V '"msm_csiphy'${SENSOR_IDX}'":0[fmt:'${FMT_BASE}'/'${WIDTH}x${HEIGHT}' field:none]'
	media-ctl -d /dev/media0 -V '"msm_csid'${SENSOR_IDX}'":0[fmt:'${FMT_BASE}'/'${WIDTH}x${HEIGHT}' field:none]'
	media-ctl -d /dev/media0 -V '"msm_ispif'${SENSOR_IDX}'":0[fmt:'${FMT_BASE}'/'${WIDTH}x${HEIGHT}' field:none]'
	media-ctl -d /dev/media0 -V '"msm_vfe0_pix":0[fmt:'${FMT_BASE}'/'${WIDTH}x${HEIGHT}' field:none]'
	media-ctl -d /dev/media0 -V '"msm_vfe0_pix":1[fmt:'${FMT}'/'${WIDTH}x${HEIGHT}' field:none]'
else
	# Use RAW interface
	if [ ${SENSOR_IDX} -eq 1 ] ; then
		VIDEO_DEV=${VIDEO_DEV_RDI1}
	else
		VIDEO_DEV=${VIDEO_DEV_RDI0}
	fi
	media-ctl -d /dev/media0 -l '"msm_csiphy'${SENSOR_IDX}'":1->"msm_csid'${SENSOR_IDX}'":0[1],"msm_csid'${SENSOR_IDX}'":1->"msm_ispif'${SENSOR_IDX}'":0[1],"msm_ispif'${SENSOR_IDX}'":1->"msm_vfe0_rdi'${SENSOR_IDX}'":0[1]';
	media-ctl -d /dev/media0 -V '"ov5640 '${SENSOR}'":0[fmt:'${FMT}'/'${WIDTH}x${HEIGHT}'@1/'${FRAMERATE}' field:none]'
	media-ctl -d /dev/media0 -V '"ov5640 '${SENSOR}'":0[fmt:'${FMT}'/'${WIDTH}x${HEIGHT}'@1/'${FRAMERATE}' field:none]'
	media-ctl -d /dev/media0 -V '"msm_csiphy'${SENSOR_IDX}'":0[fmt:'${FMT}'/'${WIDTH}x${HEIGHT}' field:none]'
	media-ctl -d /dev/media0 -V '"msm_csid'${SENSOR_IDX}'":0[fmt:'${FMT}'/'${WIDTH}x${HEIGHT}' field:none]'
	media-ctl -d /dev/media0 -V '"msm_ispif'${SENSOR_IDX}'":0[fmt:'${FMT}'/'${WIDTH}x${HEIGHT}' field:none]'
	media-ctl -d /dev/media0 -V '"msm_vfe0_rdi'${SENSOR_IDX}'":0[fmt:'${FMT}'/'${WIDTH}x${HEIGHT}' field:none]'
fi

if [ ${FMT} = "UYVY8_2X8" ]; then
	GST_FMT="UYVY"
elif [ ${FMT} = "UYVY8_1_5X8" ]; then
	GST_FMT="NV12"
elif [ ${FMT} = "SBGGR8_1X8" ]; then
	GST_FMT="bggr"
else
	echo "unknown format!"
	exit 1
fi

echo "GST_LAUNCH"

if [ ${MODE} = "config" ]; then
	echo "Mode configured: ${FMT} ${WIDTH}x${HEIGHT} ${FRAMERATE}fps"
elif [ ${MODE} = "snapshot" ]; then
	OUTFILE="snapshot_${FMT}_${WIDTH}_${HEIGHT}"
	if [ ${FMT} = "SBGGR8_1X8" ]; then
		gst-launch-1.0 -v -e v4l2src device=${VIDEO_DEV} num-buffers=1 ! \
		video/x-bayer,format=${GST_FMT},width=${WIDTH},height=${HEIGHT} ! \
		filesink location=${OUTFILE}.${GST_FMT}
	else
		gst-launch-1.0 -v -e v4l2src device=${VIDEO_DEV} num-buffers=1 ! \
		video/x-raw,format=${GST_FMT},width=${WIDTH},height=${HEIGHT} ! \
		filesink location=${OUTFILE}.${GST_FMT}
	fi
elif [ ${MODE} = "recordmpg" ]; then
	OUTFILE="video_${FMT}_${WIDTH}_${HEIGHT}.mp4"
	if [ ${FRAMERATE} -gt ${ENCODER_MAX_FR} ]; then
		FRAMERATE=${ENCODER_MAX_FR}
	fi
	if [ ${FMT} = "SBGGR8_1X8" ]; then
		gst-launch-1.0 -e v4l2src device=${VIDEO_DEV} ! \
		video/x-bayer,format=bggr,width=${WIDTH},height=${HEIGHT},framerate=${FRAMERATE}/1 ! \
		bayer2rgb ! \
		videoconvert ! \
		v4l2h264enc extra-controls="controls,h264_profile=4,h264_level=10,video_bitrate=2500000" ! \
		h264parse ! mp4mux ! filesink location=${OUTFILE}
	else
		gst-launch-1.0 -e v4l2src device=${VIDEO_DEV} ! \
		video/x-raw,format=${GST_FMT},width=${WIDTH},height=${HEIGHT} ! \
		videoconvert ! \
		v4l2h264enc extra-controls="controls,h264_profile=4,h264_level=10,video_bitrate=2500000" ! \
		h264parse ! mp4mux ! filesink location=${OUTFILE}
	fi
elif [ ${MODE} = "rtp" ]; then
	if [ ${FRAMERATE} -gt ${ENCODER_MAX_FR} ]; then
		FRAMERATE=${ENCODER_MAX_FR}
	fi
	if [ ${FMT} = "SBGGR8_1X8" ]; then
		gst-launch-1.0 -e v4l2src device=${VIDEO_DEV} ! \
		video/x-bayer,format=bggr,width=${WIDTH},height=${HEIGHT},framerate=${FRAMERATE}/1 ! \
		bayer2rgb ! \
		videoconvert ! \
		v4l2h264enc extra-controls="controls,h264_profile=4,h264_level=10,video_bitrate=2500000" ! \
		h264parse ! rtph264pay ! udpsink host=${RTP_CLIENT_IP} port=5000
	else
		gst-launch-1.0 -e v4l2src device=${VIDEO_DEV} ! \
		video/x-raw,format=${GST_FMT},width=${WIDTH},height=${HEIGHT},framerate=30/1 ! \
		videoconvert ! \
		v4l2h264enc extra-controls="controls,h264_profile=4,h264_level=10,video_bitrate=2500000" ! \
		h264parse ! rtph264pay ! udpsink host=${RTP_CLIENT_IP} port=5000
	fi
	# CLIENT: Run this command 'first' on client side
	# gst-launch-1.0 -v udpsrc port=5000 caps = "application/x-rtp, media=(string)video, encoding-name=(string)H264" ! queue ! rtph264depay ! decodebin ! videoconvert ! autovideosink
elif [ ${MODE} = "fb" ]; then
	if [ ${FMT} = "SBGGR8_1X8" ]; then
		gst-launch-1.0 -e v4l2src device=${VIDEO_DEV} ! \
		video/x-bayer,format=bggr,width=${WIDTH},height=${HEIGHT} ! \
		bayer2rgb ! \
		queue ! \
		fpsdisplaysink video-sink=fbdevsink
	else
		gst-launch-1.0 -e v4l2src device=${VIDEO_DEV} ! \
		video/x-raw,format=${GST_FMT},width=${WIDTH},height=${HEIGHT} ! \
		videoconvert ! \
		queue ! \
		fpsdisplaysink video-sink=fbdevsink
	fi
elif [ ${MODE} = "preview" ]; then
	export DISPLAY=:0
	if [ ${FMT} = "SBGGR8_1X8" ]; then
		gst-launch-1.0 -e v4l2src device=${VIDEO_DEV} ! \
		video/x-bayer,format=bggr,width=${WIDTH},height=${HEIGHT} ! \
		bayer2rgb ! \
		queue ! \
		fpsdisplaysink video-sink=glimagesink
	else
		gst-launch-1.0 -e v4l2src device=${VIDEO_DEV} ! \
		video/x-raw,format=${GST_FMT},width=${WIDTH},height=${HEIGHT} ! \
		queue ! \
		videoconvert ! \
		fpsdisplaysink video-sink=glimagesink
	fi
else
	echo "Unsupported action"
fi
