#!/bin/bash

docker stop java-applet-container 2>/dev/null && docker rm java-applet-container

if [ $? -eq 0 ]; then
	image=$(docker image ls | grep java-applet-vnc | awk '{print $3}')
	[ -n "$image" ] && docker rmi $image
fi

docker build --platform linux/amd64 -t java-applet-vnc . && docker run --platform linux/amd64 -p 5901:5901 --name java-applet-container java-applet-vnc
