#!/bin/bash

if [ "$#" -le 1 ]; then
    echo "You need to provide at least two TLDs from which I should download the certificates."
    exit 1
fi

domainList=("$@")
declare -a tmpFiles
declare todayLog="/tmp/certcheck-$(date +"%Y-%m-%d")"

OPENSSL_BIN=$(which openssl)

function storeErrornum() {
    [[ -f ${todayLog} ]] && currentErrorNum=$(cat ${todayLog}) || currentErrorNum=0
    newErrorNum="$((${currentErrorNum}+1))"
    echo ${newErrorNum} > ${todayLog}
}

function sendErrorStats() {
    yesterdayLog="/tmp/certcheck-$(date +"%Y-%m-%d" -d "yesterday")"
    if [[ ! -f ${todayLog} ]] && [[ -f ${yesterdayLog} ]]; then
        echo 0 > ${todayLog}
        local errorNum=$(cat ${yesterdayLog})
        echo "Errors happened during certificate updates: ${errorNum}"
        rm ${yesterdayLog}
    fi
}

function generateJson() {
    responseCount=0
    fingerprintList=""
    for var in "${domainList[@]}"; do
        if ping -c1 -W1 ${var} &> /dev/null
        then
            tmpFile=$(mktemp)
            tmpFiles+=(${tmpFile})
            let "responseCount=responseCount+1"
            ${OPENSSL_BIN} s_client -servername ${var} -connect ${var}:443 </dev/null 2>/dev/null | openssl x509 -outform PEM >${tmpFile}
            if [[ "$?" -ne 0 ]]; then
                storeErrornum
            fi

            detected_fingerprint=$(openssl x509 -noout -in ${tmpFile} -fingerprint -sha256 | cut -d "=" -f2)
            fingerprintList="${fingerprintList}"", \"${var}\": \"${detected_fingerprint}\""
        fi
    done

    if [[ responseCount -le 1 ]]; then
        storeErrornum
        exit 2
    fi
    echo "{ "$(echo ${fingerprintList} | sed -r 's/^.{2}//')" }" > /u1/www/websites/verges.io/htdocs/certificate-fingerprints.json
}

function finish {
    for rmFile in "${tmpFiles[@]}"; do
        [[ -f ${rmFile} ]] && rm -rf ${rmFile}
    done
}
trap finish EXIT

function main() {
    sendErrorStats
    generateJson
}

# Wait forever until you're back online
if ! ping -c1 8.8.8.8 &>/dev/null; then
    storeErrornum
fi

main
