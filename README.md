# connection-integrity
Sitting at Tegel Airport in Berlin I recently discovered that the SSL certificates are intercepted. 
I use these two scripts now to verify the integrity of my internet connection whenever I connect to a WiFi. For public ones you should use a VPN for all destinations anyways, but I thought this might come in handy also in other situations.

I run Ubuntu 18.04 w/ LightDM and Cinnamon Desktop.

## check-certificates-mitm.sh
Run this locally on your Linux machine. It will fetch a fresh list of fingerprints and check whether they match local results.

## create-certs-fingerprints-json.sh
The script I run each hour on my server. It creates a JSON file containing the fingerprints used for the verification. You can also run this on your *trusted* server and adjust the domains as you wish.
`check-certificates-mitm.sh` initially uses https://verges.io/certificate-fingerprints.json.
