#!/usr/bin/env bash

HOSTNAMECTL="$(which hostnamectl)"
END_CONFIG="/etc/netplan/01-netcfg.yaml"

generateAndApply() {
    netplan generate
    netplan apply
}

getInternetInfo() {
    local INTERNET_INFO
    INTERNET_INFO=$(ip r | grep default)
    printf "%s" "$(echo "$INTERNET_INFO" | cut -f$1 -d' ')"
}

#static information
NAMESERVERS="192.168.1.249"
NETWORK_MANAGER="networkd"

# information that varies
GATEWAY="$(getInternetInfo 3)"
DEVICE_NAME="$(getInternetInfo 5)"
METHOD="$(getInternetInfo 7)"
PREFIX="$(ip r | grep kernel | cut -f1 -d' ' | cut -f2 -d'/')"
IP="$(ip r | grep kernel | grep "$DEVICE_NAME" | cut -f9 -d' ')"

createStaticYAML() {
    local YAML="network:\n"
    YAML+="    version: 2\n"
    YAML+="    renderer: $NETWORK_MANAGER\n"
    YAML+="    ethernets:\n"
    YAML+="        $DEVICE_NAME:\n"
    YAML+="            dhcp4: no\n"
    YAML+="            addresses: [$IP/$PREFIX]\n"
    YAML+="            gateway4: $GATEWAY\n"
    YAML+="            nameservers:\n"
    YAML+="                addresses: [$NAMESERVERS]"
    printf "%s" "$YAML"
}

clearConfigs() {
    [ -f "$END_CONFIG" ] && rm "$END_CONFIG"
}

setYAML() {
    echo -e "$(createStaticYAML)" > "$END_CONFIG"
}

function valid_ip() { # validates ip and return 0 if valid and 1 if not
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local OIFS=$IFS
        IFS='.'
        ip=("${ip}")
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
    printf "\nThis script needs root.  Attempting to elevate.\n\n" >&2
    exec sudo bash "$0" "$@"
}
printf "\nFirst run... Starting template customizer script."
#sleep 2
clear

case "$METHOD" in
    "dhcp")
        printf "Current network interface [%s] IP [%s] is assigned by DHCP.\n
        Change this? ([y]/n)" \
            "$DEVICE_NAME" "$(hostname -I | cut -d ' ' -f 1)"
        RESPONSE=$(get_yn)
        case $RESPONSE in
            n)
                printf "\nIP address unchanged.\n"
                VIP="UNCHANGED [$(hostname -I | cut -d ' ' -f 1)]"
                ;;
            y)
                while true; do
                    printf "\nEnter IP in xxx.xxx.xxx.xxx (IPV4) format: "
                    read -r -n16
                    if valid_ip "$REPLY"; then
                        VIP=$REPLY
                        break
                    else
                        printf "\nInvalid IP.  Please reenter.\n"
                    fi
                done
                ;;
        esac
        ;;
    "static")
        printf "IP address already statically assigned, so it will not be changed.\n"
        ;;
    *)
        printf "Unexpected IP assignment type! [%s]  Exiting now.\n" "$METHOD"
        exit 1
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
        if ! [[ "$VIP" =~ ^UNCHANGED ]]; then
            clearConfigs
            setYAML
            createStaticYAML
            generateAndApply
            printf "\nNetplan config created.\n"
        else
            printf "\nIP address unchanged.\n"
        fi
        if ! [[ "$VHOST" =~ ^UNCHANGED ]]; then
            $HOSTNAMECTL set-hostname "$VHOST"
            printf "\nHostname set.  Reboot now? "
            RESPONSE=$(get_yn)
            if [[ $RESPONSE == "y" ]]; then
                reboot
            fi
        else
            printf "\nHostname unchanged.\n"
        fi
        ;;
    *)
        printf "\nOkay.  Exiting.\n"
        ;;
esac
printf "Script terninating.\n"
exit 0