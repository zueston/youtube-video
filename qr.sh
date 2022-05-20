#!/bin/bash

port=81
videoHome=/usr/share/nginx/html
json=$videoHome/channels.json

yum install -y qrencode jq

nic=$(/sbin/ifconfig | grep flags | egrep '^eth|^ens' | head -n 1 | cut -d':' -f1)

#ip=$(/sbin/ifconfig $nic | grep "broadcast" | awk '{print $2}')
ip=$(curl http://ipecho.net/plain)

cd /root/youtube-video

ts=$(date "+%m%d%H%m")

while read line ; do
	title=$(echo $line | cut -d',' -f1 | sed 's/"/ /g')
	folder=$(echo $line | cut -d',' -f3)
	url="http://$ip:$port/$folder/?t=$ts"
	path=$videoHome/$folder/qr.png
	qrencode -o $path -s8 $url
	echo $url
done < channels.csv

cat channels.csv | grep -v "^$"	\
	| jq --slurp --raw-input --raw-output \
	'split("\n") | .[0:-1] | map(split(",")) | map({"name": .[2], "desc": .[0]})'	\
	> $json

