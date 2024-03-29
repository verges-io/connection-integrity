#!/bin/bash

declare leaseIdFile="/tmp/dhcp4_lease_${DHCP4_EXPIRY}"

function getLightdmUser() {
    xorg_pid=$(pidof -s /usr/sbin/lightdm)
    test -n "$xorg_pid" || exit 1
    dm_pid=$(ps -eo pid,ppid,args | \
    awk -v xorg_pid=$xorg_pid '$1 == xorg_pid {print $2}')
    pid_list="$(ps -eo pid,ppid,cmd | \
    awk -v dm_pid=$dm_pid '$2 == dm_pid {if (matchnr == 0) '\
'{ printf "%s%d ","$2 == ",$1; matchnr++;} '\
'else printf "%s%d ","|| $2 == ",$1;}')"
    ps -eo pid,ppid,user,cmd | awk "$pid_list"'{print $3}'
}

function exitWhenExists() {
    if pidof -o %PPID -x "check-certificates-mitm.sh" >/dev/null; then
        echo "check-certificates-mitm.sh is already running"
        exit 1
    fi
}

function checkDomainCertsFingerprints() {
    if [[ -z ${DEVICE_IFACE} ]]; then
        DEVICE_IFACE="<UNSPECIFIED>"
    fi

    errorCount=0
    for key in "${!FINGERPRINTS[@]}"; do
        ${OPENSSL_BIN} s_client -servername ${key} -connect ${key}:443 2>&1 </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >/tmp/certificate.pem

        detected_fingerprint=$(openssl x509 -noout -in /tmp/certificate.pem -fingerprint -sha256 | cut -d "=" -f2)
        if [[ "${detected_fingerprint}" != "${FINGERPRINTS[$key]}" ]]; then
            echo "Fingerprints for ${key} do not match! :("
            let "errorCount=errorCount+1"
        fi
    done

    if [[ ${errorCount} -eq 0 ]]; then
        if [[ ${USER} == ${user} ]]; then
            ${ZENITY_BIN} --notification --window-icon="face-cool" --text="Integrity of the connection via interface '${DEVICE_IFACE}' was verified\nThe fingerprints used to check SSL certificates are all valid."
        else
            su ${user} -c "${ZENITY_BIN} --notification --window-icon=\"face-cool\" --text=\"Integrity of the connection via interface '${DEVICE_IFACE}' was verified\nThe fingerprints used to check SSL certificates are all valid.\""
        fi
    else
        ${ZENITY_BIN} --warning --width=400 --window-icon="dialog-error" --text="ALERT!

At least one of the certificates checked via the device called '${DEVICE_IFACE}' has a different fingerprint! You might be subject to a MITM attack!\nConsider using a full VPN to protect your privacy!"# --display=:0
    fi
}

function checkIfUpLink() {
    if [[ ! -e /etc/network/if-up.d/check-certificates-mitm ]]; then
        SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
        ${ZENITY_BIN} --warning --width=400 --window-icon="dialog-warning" --text="
This check is *not* automatically run when you connect to the internet.
If you want to check the integrity of your connection whenever you go online, make sure you run this command before you go online the next time:

sudo ln -s ${SCRIPTPATH}/check-certificates-mitm.sh /etc/network/if-up.d/check-certificates-mitm" --display=:0
    fi
}

function preventRunningTwice() {
    if [[ "${ADDRFAM}" == "inet6" ]] && [[ -f ${leaseIdFile} ]]; then
        exit 0
    fi
}

function finish {
    rm -f /tmp/certificate.pem /tmp/certificate-fingerprints.json || true 2>&1 >/dev/null
    if [[ "${ADDRFAM}" == "inet6" ]]; then
        rm /tmp/dhcp4_lease_* || true 2>&1 >/dev/null
    fi

}
trap finish EXIT

exitWhenExists
preventRunningTwice

user=$(getLightdmUser)
# HINT: If you are not using LightDM you can either hard code your user or extend this script :)
#declare user=dennisw

# Wait forever until you're back online
while ! ping -c1 8.8.8.8 &>/dev/null
        do echo "Ping Fail - `date`"
done

export DISPLAY=:0
export XAUTHORITY=/home/${user}/.Xauthority

if ! type "zenity" > /dev/null; then
    echo "ERROR: Please install zenity"
    exit 1
fi

OPENSSL_BIN=$(which openssl)
ZENITY_BIN=$(which zenity)

# My webserver fetches the SHA256 certificate fingerprints from linkedin.com, grc.com and de.wikipedia.org. See create-certs-fingerprints-json.sh 
curl -s https://verges.io/certificate-fingerprints.json --output /tmp/certificate-fingerprints.json

declare -A FINGERPRINTS
while read line || [[ -n $line ]]; do
    key=`echo $line | cut -s -d'=' -f1`
    if [ -n "$key" ]; then
        value=`echo $line | cut -d'=' -f2-`
        FINGERPRINTS["$key"]="$value"
    fi
done < <(jq -r "to_entries|map(\"\(.key)=\(.value)\")|.[]" /tmp/certificate-fingerprints.json)

function main() {
    if [[ "${ADDRFAM}" == "inet" ]]; then
        touch ${leaseIdFile}
    fi

    checkDomainCertsFingerprints
    checkIfUpLink
}

main
