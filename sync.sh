#!/bin/bash
# author: gfw-breaker

switch=$1
csv=videos.txt

server_port=80
index_page=index.html
nginx_dir=/usr/share/nginx/html
cwd=/root/youtube-video

ts=$(date "+%m%d%H%m")

# get IP
nic=$(/sbin/ifconfig | grep flags | egrep '^eth|^ens' | head -n 1 | cut -d':' -f1)
#ip=$(/sbin/ifconfig $nic | grep "broadcast" | awk '{print $2}')
ip=$(curl http://ipecho.net/plain)


cd $cwd
git pull

# data_server=
source config

# page
#ts=$(date '+%m%d%H')

if [ "$data_server" == "" ]; then
	data_server=$ip
fi

while read line; do
	folder=$(echo $line | cut -d'|' -f1)
	id=$(echo $line | cut -d'|' -f2)
	title=$(echo $line | cut -d'|' -f3)
	
	video_dir=$nginx_dir/$folder
	mkdir -p $video_dir; cd $video_dir
	vname=_$id
	if [ -f $vname.mp4 ]; then
		#echo "$vname.mp4 exists"
		echo -n
	else
		#youtube-dl --cookies /root/cookies.txt -o "_%(id)s.%(ext)s" -f 18 -- $id
		/usr/local/bin/yt-dlp --compat-options all --cookies /root/cookies.txt -o "_%(id)s.%(ext)s" -f 18 -- $id
		if [ -f $vname.mp4 ]; then
			size=$(ls -l $vname.mp4  | awk '{print $5}')
			if [ $size -lt  150000000 ]; then
				/opt/kaltura/ffmpeg-4.0.2/bin/ffmpeg -nostdin -i $vname.mp4 -b:a 64K -vn $vname.mp3 #2> /dev/null
			fi
		fi
	fi

	if [ -f $vname.jpg ]; then
		#echo "$vname.jpg exists"
		echo -n
	else
		if [ "$switch" == "" ]; then
			#wget https://img.youtube.com/vi/$id/hqdefault.jpg -O $vname.jpg
			wget https://i3.ytimg.com/vi/$id/maxresdefault.jpg -O $vname.jpg
		fi
	fi

	sed -e "s/#vname#/$vname/g" -e "s/#channel#/$folder/g" -e "s/#title#/$title/g" \
		-e "s/#serverip#/$ip/g" -e "s/#dataserverip#/$data_server/g" \
		-e "s/#hlsport#/$hls_port/g" -e "s/#dlport#/$dl_port/g" \
		 /root/youtube-video/template/player.html > $video_dir/$vname.html 

	grep -- $id list.txt > /dev/null 2>&1
	
	if [ $? -eq 0 ]; then
		#echo 'ok'	
		echo -n
	else
		touch list.txt
		cat list.txt > tmp
		echo "$id|$title" > list.txt	
		cat tmp >> list.txt
	fi
	cat list.txt | sed 's/|/,/g' | jq --slurp --raw-input --raw-output	\
		'split("\n") | .[0:-1] | map(split(",")) | map({"id": .[0], "title": .[1]})'	\
		> index.json
done < $csv


while read line; do
	folder=$(echo $line | cut -d'|' -f1)
	url=$(echo $line | cut -d'|' -f2)
	
	video_dir=$nginx_dir/$folder
	mkdir -p $video_dir; cd $video_dir

	iname=index.jpg
	if [ -f $iname ]; then
		echo "$folder/$iname exists"
	else
		wget $url -O $iname
	fi
done < $cwd/icons.txt


channels=$(cat /root/youtube-video/channels.csv | awk -F',' '{ print $3}')

for folder in $channels; do
	video_dir=$nginx_dir/$folder

	cd $video_dir

	oldItems=$(sed -n '101,$p' list.txt | cut -d'|' -f1)
	for old in $oldItems; do
		echo "deleting : _$old.mp4"
		rm _$old.mp4
		rm _$old.mp3
		rm _$old.jpg
		rm _$old.html
	done

	sed -i '101,$d' list.txt

	title=$(cat $cwd/channels.csv | grep ",$folder," | cut -d',' -f1)
	sed -e "s/#serverip#/$ip/g" -e "s/#title#/$title/g" $cwd/template/latest.html > index.html 
	sed -e "s/#serverip#/$ip/g" -e "s/#title#/$title/g" $cwd/template/list.html > list.html 
done


# generate qr
/root/youtube-video/qr.sh
cp -r $cwd/template/hw $nginx_dir
cp -r $cwd/template/guide.html $nginx_dir

sed -e "s/#serverip#/$ip/g" $cwd/template/youtube.html > $nginx_dir/youtube.html
sed -e "s/#serverip#/$ip/g" $cwd/template/radio.html > $nginx_dir/radio.html

# tv
regions="cnlive900:中国台 aplive200:亚太台 live900:美东台 eulive600:欧州台"
for kv in $regions; do
	code=$(echo $kv | cut -d':' -f1)
	region=$(echo $kv | cut -d':' -f2)
	sed -e "s/#serverip#/$ip/g" -e "s/#code#/$code/g" -e "s/#region#/$region/g"	\
		-e "s/#dataserverip#/$data_server/g" $cwd/template/tv.html > $nginx_dir/tv_$code.html
done
cp $nginx_dir/tv_cnlive900.html $nginx_dir/index.html

# radio
regions="soh-live:中国广播台 bayvoice:湾区生活台 SYDNEY:澳洲台 SF969:粤语台"
for kv in $regions; do
	code=$(echo $kv | cut -d':' -f1)
	region=$(echo $kv | cut -d':' -f2)
	sed -e "s/#serverip#/$ip/g" -e "s/#code#/$code/g" -e "s/#region#/$region/g"	\
		$cwd/template/radio.html > $nginx_dir/$code.html
done
cp $nginx_dir/soh-live.html $nginx_dir/radio.html


