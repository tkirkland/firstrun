#!/usr/bin/env bash

HOSTNAMECTL="$(which hostnamectl)"

function valid_ip() { # validates ip and return 0 if valid and 1 if not
        local ip=$1
        local stat=1

        if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                OIFS=$IFS
                IFS='.'
                ip=($ip)
                IFS=$OIFS
                [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
                stat=$?
        fi
        return $stat
}

function get_yn() { # gets Y or N keypress, enter alone assumes Y
        while true; do
                read -r -s -n1
                case "$REPLY" in
                        [Yy] | "")
                                echo " Yes" >&2
                                echo "y"
                                break
                                ;;
                        [Nn])
                                echo " No" >&2
                                echo "n"
                                break
                                ;;
                        *) ;;
                esac
        done
}

[ "$UID" -eq 0 ] || {
        printf "\nThe script need to be run as root." >&2
        printf "\nAttempting to elevate script.\n"
        exec sudo bash "$0" "$@"
}
printf "\nFirst run... Starting template customizer script."
#sleep 2
clear

printf "Current network IP [%s] is assigned by DHCP.  Change this? ([y]/n)" "$(hostname -I | cut -d ' ' -f 1)"
RESPONSE=$(get_yn)
case $RESPONSE in
        n)
                printf "\nIP address unchanged.\n"
                VIP="UNCHANGED [$(hostname -I | cut -d ' ' -f 1)]"
                ;;
        y)
                IP=1
                until [ $IP = 0 ]; do
                        printf "\nEnter IP in xxx.xxx.xxx.xxx (IPV4) format: "
                        read -r -n16
                        if valid_ip "$REPLY"; then
                                VIP=$REPLY
                                IP=0
                        else
                                printf "\nInvalid IP.  Please reenter.\n"
                        fi
                done
                ;;
esac

printf "\nThe local machine hostname is [%s].  Change this? ([y]/n)" "$(hostname)"
RESPONSE=$(get_yn)
case $RESPONSE in
        n)
                printf "\nHostname unchanged.\n"
                VHOST="UNCHANGED [$(hostname)]"
                ;;
        y)
                while true; do
                        printf "\nPlease enter the desired hostname (20 char max): "
                        read -r -n20
                        if [[ "$REPLY" =~ ^[0-9A-Za-z][0-9A-Za-z-]*$ ]]; then
                                printf "\nOkay.  Hostname will be set to: %s" "$REPLY"
                                VHOST="$REPLY"
                                break
                        else
                                printf "\nInvalid hostname [%s]! Please reenter.\n" "$REPLY"
                        fi
                done
                ;;
esac

printf "\nLast chance!  Verify the following:\n\n       Hostname: %s\n       Host IP : %s\n" "$VHOST" "$VIP"
printf "\nApply these changes? "

RESPONSE=$(get_yn)
case "$RESPONSE" in
        y)
                if ! [[ $VHOST =~ "^\[UNCHANGED\]" ]]; then
                        set-hostname
                        printf "\nHostname set.\n"
                fi
                if ! [[ $VIP =~ "^\[UNCHANGED\]" ]]; then
                        printf "\nNetplan config updated.\n"
                fi
                ;;
        *)
                printf "\nOkay.  Exiting.\n"
                ;;

esac
