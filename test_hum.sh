#!/bin/bash

#setreading HM_633ADB_Climate humidity 62

function sendHum(){
    hum=$1
expect << EOF
spawn telnet -4 localhost 7072
send "\r"
expect -re ".*>"
send "setreading HM_633ADB_Climate humidity $hum\r"
expect -re ".*>"
send "exit\r"
expect eof
EOF
}

for h in {60..75}
do
    echo "$h"
    sendHum $h
    sleep 5
done

