#!/bin/bash

if [ "$#" -le 1 ]; then
    echo "You need to provide at least two TLDs from which I should download the certificates."
    exit 1
fi

domainList=("$@")

# Wait forever until you're back online
while ! ping -c1 8.8.8.8 &>/dev/null
        do echo "Ping Fail - `date`"
done

OPENSSL_BIN=$(which openssl)

function generateJson() {
    responseCount=0
    fingerprintList=""
    for var in "${domainList[@]}"; do
        if ping -c1 -W1 ${var} &> /dev/null
        then
            let "responseCount=responseCount+1"
            ${OPENSSL_BIN} s_client -servername ${var} -connect ${var}:443 2>&1 </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >/tmp/certificate.pem
            detected_fingerprint=$(openssl x509 -noout -in /tmp/certificate.pem -fingerprint -sha256 | cut -d "=" -f2)
            fingerprintList="${fingerprintList}"", \"${var}\": \"${detected_fingerprint}\""
        fi
    done

    if [[ responseCount -le 1 ]]; then
        echo "ERROR: Unable to connect to at least 2 domains. Exiting."
        exit 2
    fi
    echo "{ "$(echo ${fingerprintList} | sed -r 's/^.{2}//')" }" > /u1/www/websites/verges.io/htdocs/certificate-fingerprints.json
}

function finish {
  rm -rf /tmp/certificate.pem
}
trap finish EXIT

function main() {
    generateJson
}

main
