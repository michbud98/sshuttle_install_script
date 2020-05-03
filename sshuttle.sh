#!/bin/bash

config="/home/sshuttle/sshuttle.conf"
log="/home/sshuttle/sshuttle.log"

getPID() {
    ps -ef | grep "/usr/bin/python3 /usr/bin/sshuttle" | egrep -v 'grep|firewall' | awk {'print $2'} 
}

status() {
    PID=$(getPID)

    if [[ -n ${PID} ]]
    then
        echo "sshuttle is running.."
    else
        echo "sshuttle is not running"
    fi
}

start() {
    while read -r line
    do        
        if [[ -n $line ]] && [[ "${line}" != \#* ]]
        then
            rhost=$(echo $line | awk -F',' '{printf "%s", $1}' | tr -d "'")
            network=$(echo $line | awk -F',' '{printf "%s", $2}' | tr -d "'")

            if [[ -n $rhost ]]
            then
                echo "starting sshuttle over ${rhost} for network: ${network}"
                nohup sshuttle -vvNH -r $rhost $network > ${log} 2>&1 &
                #nohup sshuttle -r $rhost $network 2>&1 &
	        fi
        fi

    done < $config 
    echo "sshuttle running"
}


stop() {
    PID=$(getPID)

    if [[ -n ${PID} ]]
    then
        kill -9 $PID
        echo "sshuttle stopped.."
    fi
}

restart() {
    stop
    start
}

case $1 in
  start|stop|status|restart) "$1" ;;
esac

exit 0 
