#!/bin/bash

sudo cp 98_BadLuefter.pm /opt/fhem/FHEM/
sudo chown fhem:dialout /opt/fhem/FHEM/98_BadLuefter.pm

expect << EOF
spawn telnet -4 localhost 7072
send "\r"
expect -re ".*>"
send "reload 98_BadLuefter\r"
expect -re ".*>"
send "exit\r"
EOF

