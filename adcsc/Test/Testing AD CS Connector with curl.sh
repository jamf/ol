#!/bin/bash

# Purpose: Test ADCS Connector setup.
# 2018-05 / ol

# ==========================================================================
# Purpose: 
# 
# The AD CS Connector is used to retrieve certificates for Jamf Pro.
# Before configuring Jamf Pro, we may need to test network connectivity to
# ensure that communications will flow properly and make sure our computer or
# service account has permissions to get certs from AD CS. It may be easier 
# to test this from this script since running a full enrollment workflow to
# trigger certificate requests in Jamf Pro takes a bit of time. 
# 
# Requires:
# 1) macOS bash (or linux, but I haven't tested so your results may vary)
# 2) openssl
# 2) curl
# 
# Procedure:
# 
# After installing the AD CS Connector, you will have saved three items: 
# - client-cert.pfx
# - adcs-proxy-ca.cer
# - The pfx/p12 password that was written to your PowerShell terminal.
# 
# Put the two cert files in a folder alongside this script and assign the 
# password for client-cert.pfx to the "clientPfxPassword" variable below. 
# 
# There are two curl commands that we will be sending to the Connector.
# The first call is to tell it that it should ask AD CS to sign a
# certificate. AD CS will create the signature and save it in it's database. 
# The second curl command will ask AD CS to retrieve the signature from the 
# keystore. 
# ==========================================================================


# ==========================================================================
# [!] This is for lab-ing things out. Like if you're testing
#     against a production CA, don't go copying your ADCS 
#     Connector Client key and password all over the place
#     willy-nilly. Guard it like a very important password. 
# 
#     Re-do the install once you have things tested so you
#     get a new client cert. 
# ==========================================================================

# TO-DO:
# Split CONNECTOR_HOSTPORT, 
# test dns resolution for correct hostname, 
# ping server (but only warn if you can't), 
# test curl to hostport.


# ==========================================================================
# SETTINGS: 
# ==========================================================================

# What's the hostname of your issuing or stand-alone CA server? 
# (Just the FQDN host name, no https/ports or anything like that...)
ADCS_CA_hostname="adcs.my.org"

# What's the instance name of the CA? You can run certsrv if you're not sure what it is. 
# The instance name will be listed right under "Certificate Authority (Local)"
ADCS_CA_InstanceName="My Issuing CA"

# What template do you want to use? 
# If using an enterprise CA, fill this in. 
# If using a standalone CA, leave it blank.
# The AD CS template can determine things like the how long until the 
#  cert expires, certificate purpose (OIDs), etc. 
ADCS_CA_template="JamfADCSConnector"   # On an enterprise CA
# ADCS_CA_template=""       # On a standalone CA, there is no template

# Folder where you put the server nd client certs from the ADCS Connector install. 
# (relative to this script's path). 
authenticationCertSubFolder='auth_certs'
serverCertFileName='server-cert.cer'
clientCertFileName='client-cert.pfx'

# The passphrase for the private key file ("client-cert.pfx") that we will use to identify 
# ourselves to the AD CS Connector. You get this from the connector's PowerShell installer 
# script's output)
clientPfxPassword='crypticpassword'

# The "fqdn:port" of the AD CS Connector host running IIS 
# (Don't include https:// or a trailing "/"). 
# You only need to includ a :port at the end if you're not using 443
# E.g. : "adcs_connector.my.org" or "adcs_connector.my.org:8443" 

CONNECTOR_HOSTPORT="adcs_connector_host.my.org:8443"

# INFORMATION FOR THE CSR... 
# What do you want as the subject for our cert? It can be anything you want... 
# Don't include the /CN= part... just supply a simple string
# E.g., "username@my.org"
subject="mycomputername-or-myusername"

# When we have a new keypair created and signed by the CA, we'll export it to a p12 
# locked with a password. You wouldn't put a password in a script or pass it on the
# command line in real life, of course. Put the password you want to use here...
passwordForTheNewIdentityFile='pwd'


# Do you want to see the full contents of all the openssl commands? 
debug=false

#  END OF SETTINGS...


# =================================================================================
# =================================================================================

# CODE...

myexit () {
  echo
  echo '======================================================'
  echo "Script ended on error."
  echo '======================================================'
  echo '======================================================'
  echo
  echo
  exit 1
}

echo "Starting test of ADCSC"

pathToMe="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

CONNECTOR_URL="https://${CONNECTOR_HOSTPORT}"

CONNECTOR_HOSTPORT_space=$( echo "$CONNECTOR_HOSTPORT" | tr ":" " " )
# echo "CONNECTOR_HOSTPORT_space : $CONNECTOR_HOSTPORT_space"
CONNECTOR_HOST=$( echo "$CONNECTOR_HOSTPORT_space" | awk '{print $1}' )
CONNECTOR_PORT=$( echo "$CONNECTOR_HOSTPORT_space" | awk '{print $2}' )
if [[ -z ${CONNECTOR_PORT} ]]; then
  CONNECTOR_PORT='443'
fi

echo "Your settings: "
echo " Requested subject    : \"/CN=${subject}\""
echo " ADCS_CA_hostname     : \"$ADCS_CA_hostname\""
echo " ADCS_CA_InstanceName : \"$ADCS_CA_InstanceName\""
echo " ADCS_CA_template     : \"$ADCS_CA_template\""
echo " clientCertFileName   : \"$clientCertFileName\""
echo " clientPfxPassword    : \"$clientPfxPassword\""
echo " serverCertFileName   : \"${serverCertFileName}\""
echo " CONNECTOR_URL        : \"$CONNECTOR_URL\""
echo " CONNECTOR_HOST       : \"$CONNECTOR_HOST\""
echo " CONNECTOR_PORT       : \"$CONNECTOR_PORT\""
echo
echo " Path to this script : "
echo " >${pathToMe}"
serverCertPath_supplied="${pathToMe}/${authenticationCertSubFolder}/${serverCertFileName}"
echo " serverCertPath_supplied : "
echo " >${serverCertPath_supplied}"
echo '======================================================'
echo '[step] Testing paths...'


iisCertsDir=$(dirname "${serverCertPath_supplied}")
if [[ -d $iisCertsDir ]]; then
  echo "[ok] folder for IIS server and client certs was found:"
  echo " -> ${iisCertsDir}" 
else
  echo "[error] folder for IIS server and client certs was not found. ${iisCertsDir}" 
  myexit
fi

if test -f "$serverCertPath_supplied"; then
	echo "[ok] I found the server cert file."
else
	echo "[error] Could not find the server cert file. ${serverCertPath_supplied}"
	myexit
fi


echo '[step] Testing connectivity to the Connector host'
( cat < /dev/null > /dev/tcp/${CONNECTOR_HOST}/${CONNECTOR_PORT} 2>&1 ) & pid=$!
( sleep 3 && kill -HUP $pid ) 2>/dev/null & watcher=$!
if wait $pid 2>/dev/null; then
  pkill -HUP -P $watcher
  wait $watcher
  # -- command finished (we have connection) --
	echo "[ok] I'm able to connect to ${CONNECTOR_HOSTPORT}"
else
  # -- command failed (no connection) --
	echo "[error] Could not connect to ${CONNECTOR_HOSTPORT}"
	myexit
fi


echo '[step] Checking the cert on the Connector host'
# When the connector exports IIS's TLS cert's public key for upload into the JSS setup 
# page, it's a CER/DER format, but the curl commands we'll be using require a .PEM, so 
# we'll need to convert. Alternately, we could just ask IIS for it's cert, or just use 
# "--insecure" curl for testing.
iisCertInfo=$( echo | openssl s_client -showcerts -servername "$CONNECTOR_HOST" -connect "${CONNECTOR_HOST}:${CONNECTOR_PORT}" 2>/dev/null )
if [[ -z iisCertInfo ]]; then
	echo "[error] Could not start TLS with the connector host."
	myexit
else
  iisCertInfoSubject=$( echo "$iisCertInfo" | openssl x509 -noout -subject )
  iisCertInfoSubject=${iisCertInfoSubject##*=}
  iisCertInfoSerial=$( echo "$iisCertInfo" | openssl x509 -noout -serial )
  iisCertInfoSerial=${iisCertInfoSerial#*=}
  iisCertInfoFingerprint=$( echo "$iisCertInfo" | openssl x509 -noout -fingerprint )
  iisCertInfoFingerprint=${iisCertInfoFingerprint#*=}
  echo "[info] Connector TLS cert with subject : \"$iisCertInfoSubject\""
  echo "[info] Connector TLS cert with serial  : \"$iisCertInfoSerial\""
  echo "[info] Connector TLS cert fingerprint  : \"$iisCertInfoFingerprint\""
fi

# Now get the server cert from the certs folder and make sure it matches what's the server is sending.
suppliedSvrCert_Subject=$( openssl x509 -inform der -in "$serverCertPath_supplied" -noout -subject )
suppliedSvrCert_Subject=${suppliedSvrCert_Subject##*=}
suppliedSvrCert_Serial=$( openssl x509 -inform der -in "$serverCertPath_supplied" -noout -serial )
suppliedSvrCert_Serial=${suppliedSvrCert_Serial#*=}
suppliedSvrCert_Fingerprint=$( openssl x509 -inform der -in "$serverCertPath_supplied" -noout -fingerprint )
suppliedSvrCert_Fingerprint=${suppliedSvrCert_Fingerprint#*=}
echo "[info] Supplied server cert subject    : \"$suppliedSvrCert_Subject\""
echo "[info] Supplied server cert serial     : \"$suppliedSvrCert_Serial\""
echo "[info] Supplied server cert fingerpnt  : \"$suppliedSvrCert_Fingerprint\""

if [[ "$suppliedSvrCert_Serial" == "$iisCertInfoSerial" ]]; then
  echo "[OK] The serial number of the Connector server's cert matches the one you provided."
else
	echo "[error] The serial number of the Connector server's cert does not match the one you provided."
	myexit
fi

echo "[step] Verifying the client identity file"
clientCertPath_supplied="${pathToMe}/${authenticationCertSubFolder}/${clientCertFileName}"
if [[ -f "$clientCertPath_supplied" ]]; then
  echo "[OK] File is present"
else
  echo "[error] File not found:"
  echo ">${clientCertPath_supplied}"
fi


if echo "$clientPfxPassword" | openssl pkcs12 -in "$clientCertPath_supplied" -passin "stdin" -noout 2>/dev/null; then
  echo "[OK] File verified"
else
  echo "[error] Could not verify the client identity file. Are you sure you supplied the correct password?"
  open "${pathToMe}/${authenticationCertSubFolder}"
  myexit
fi


echo '======================================================'
echo '[step] Making a work/output folder...'

subjNoDots=$(echo "$subject" | tr "." "_" )
timeStamp=$(date +"%Y-%m-%d_%H-%M-%S")
testFolder="${pathToMe}/ADCSC-${subjNoDots} ${timeStamp}" 

echo "Folder where I'll save the keypair I'm about to request:"
echo " \"${testFolder}\""

# Make a folder to save the new identity keypair we're creating...
mkdir "${testFolder}"
open "${testFolder}"
echo '======================================================'



# We will use the supplied server cert to let curl trust the connection to the server. 
# Alternately, we could just run --insecure or just retrieve the cert from the server.
# openssl s_client -showcerts -connect "${CONNECTOR_HOSTPORT}" </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "${serverCertChainPath}"
# echo
# echo "Server cert retrieved from Connector and saved to \"${serverCertChainPath}\""

serverCertPath_converted="${testFolder}/_server-cert.pem"
echo "A .pem version of the server cert will be saved to  : $serverCertPath_converted"

# Convert .cer to .pem...
openssl x509 -inform der -in "$serverCertPath_supplied" -out "$serverCertPath_converted"

if test -f "$serverCertPath_converted"; then
	echo "[ok] Server cert file converted to .pem."
else
	echo "[error] Error converting the server cert file."
	myexit
fi

if [ "$debug" = true ] ; then
  echo "[debug] THE SERVER TLS CERT IN .PEM FORMAT :"
  cat  "${serverCertPath_converted}"
  echo
fi

echo '======================================================'
# When the connector installer exports the client identity, it's in .pfx format. 
# But openssl wants that to have a .p12 extension. 
echo '[step] Copying the client cert from .pfx to .p12'
echo "[info] Path of the supplied client identity .pfx: "
echo ">${clientCertPath_supplied}"
clientCertPath_converted="${testFolder}/_client-cert.p12"
echo "A .p12-named copy of the client cert will be saved to:"
echo ">${clientCertPath_converted}"
cp "$clientCertPath_supplied" "$clientCertPath_converted"
if test -f "$clientCertPath_converted"; then
	echo "[ok] Client cert was copied to .p12"
else
	echo "[error] Problem copying the client cert file."
	myexit
fi
echo '======================================================'

if [ "$debug" = true ] ; then
  echo "[debug] CLIENT IDENTITY INFORMATION :"
  echo "[info] Reading from ${clientCertPath_converted}"
  echo
fi

# echo '[TEST]'
# echo "openssl pkcs12 -info -in \"${clientCertPath_converted}\" -password \"pass:${clientPfxPassword}\""
# openssl pkcs12 -in mypfx.pfx -noout

if [ "$debug" = true ] ; then
  echo "openssl pkcs12 -info -in \"${clientCertPath_converted}\" -password \"pass:${clientPfxPassword}\"" # 2>/dev/null
  openssl pkcs12 -info -in "${clientCertPath_converted}" -password "pass:${clientPfxPassword}" # 2>/dev/null
  passwordTestRetCode=$?
  # echo "Client Identity Read Result : " $passwordTestRetCode
  if [[ $passwordTestRetCode -eq 1 ]]; then
    echo "[error] I couldn't read the client certificate. Did you give me the right password?"
    myexit
  fi
  echo '======================================================'
fi


# openssl pkcs12 -info -in "${clientCertPath_converted}" -password "pass:nChKHZTy20"


echo '[step] Creating a key and CSR for the new identity...'
# Make a path where we'll save the private key we generate with openssl. 
# Then we can create a CSR based on that and ask ADCSC to get the CA to sign the CSR.
keyPath="${testFolder}/_${subjNoDots}.key"

# Generate a CSR and save it in a var...
csr=$( openssl \
  req \
  -new \
  -newkey rsa:2048 \
  -nodes \
  -keyout "${keyPath}" \
  -subj "/CN=${subject}" 2>/dev/null )


if [[ -z $csr ]]; then
	echo "[error] could not create CSR. Check your request values. Did you provide a subject?"
	myexit
else
  echo "[ok] Created CSR"
fi


# We're just sticking the csr into a variable, but if you wanted to save the csr to disk
# for troubleshooting, you could define a path...
#  csrPath="${DIR}/${subjNoDots}.csr"
# And then add a -out on the end of the openssl call...
#  -out "${csrPath}" \
# Then you could read it back in with...
#  csr=$(cat "$csrPath" )

if [ "$debug" = true ] ; then
  echo '======================================================'
  echo "[debug] We created the following CSR: "
  echo "${csr}"
  echo '======================================================'
  echo
fi

# Strip off the header and footer lines from the CSR. We don't want those, just the csr part... 
csr=$(echo "$csr" | sed '1d;$d' )

if [ "$debug" = true ] ; then
  echo
  echo
  echo '======================================================'
  echo "[debug] CSR after stripping off the header and footer lines..."
  echo "${csr}"
  echo '======================================================'
  echo
  echo
fi


# Compose a JSON message we'll be sending to the ADCS Connector as a request to create a cert...
echo '[step] Preparing a request json body to send to the connector.'
read -r -d '' requestJson <<EOF
	{ "pkcs10": "$csr",
		"template": "${ADCS_CA_template}",
		"config": {
			"dc": "${ADCS_CA_hostname}",
			"ca": "${ADCS_CA_InstanceName}" }
}
EOF



# If you are debugging and want to save the request json to disk you can...
#jsonPayloadFilePath="${testFolder}/requestBody.json"
#echo "$requestJson" > "$jsonPayloadFilePath"
# If you wanted to feed json in from the file, you could use @ in your curl --data 
#--data "@${jsonPayloadFilePath}" \

if [ "$debug" = true ] ; then
  echo '======================================================'
  echo "[debug] Request API body to send to the Connector will be:"
  echo "${requestJson}"
  echo '======================================================'
  echo
  echo
fi

# Now we can use curl to submit a signing request to the connector...
echo '[step] Sending the request to the connector via curl...'
echo "[info] URL : $CONNECTOR_URL/api/v1/certificate/request"
requestResponse=$( curl \
  --cert "${clientCertPath_converted}:${clientPfxPassword}" \
	--cert-type "P12" \
  --http1.1 \
  --header "Content-Type: application/json" \
  --write-out $'\n%{http_code}' \
  --request POST  \
  --data "${requestJson}" \
  --show-error \
  --silent \
	--cacert "${serverCertPath_converted}" \
	--insecure \
	--dump-header /tmp/headers.txt \
  $CONNECTOR_URL/api/v1/certificate/request )


if [[ -z $requestResponse ]]; then
  echo "[error] No response body received from the Connector."
  myexit
fi

HTTP_Status=$( echo "$requestResponse" | tail -1)
requestResponse=$( echo "$requestResponse" | sed \$d )

echo "[debug] HTTP_Status : $HTTP_Status"

# Strip carriage returns from the response since they'll be in CR NL line endings which look double-spaced on mac/linux...
requestResponse="${requestResponse//$'\r'/}"

if [[ $HTTP_Status = "200" ]]; then
  echo '[OK] Response received.'
elif [[ $HTTP_Status = "201" ]]; then
  echo '[OK] Response received.'
elif [[ $HTTP_Status = "400" ]]; then
  echo "[error] Invalid request."
elif [[ $HTTP_Status = "403" ]]; then
  echo "[error] Access denied. Did you use the right client cert?"
elif [[ $HTTP_Status = "500" ]]; then
  echo "[error] Server error."
elif [[ $HTTP_Status = "503" ]]; then
  echo "[error] HTTP Error 503. \"The service is unavailable.\""
  echo "[error] This can happen for a few reasons, including that the user on your certificate to user mapping in IIS config is wrong."
else
  echo "[error] Server did not respond correctly. "
fi

if [[ $HTTP_Status != "2"* ]]; then
  echo "Printing some diagnostic details..."
  echo
  #   echo "These are the response headers"
  #   cat /tmp/headers.txt | sed 's/\r$//g' | tr -s '\n' | grep .
  echo "The server's http response was:"
  echo "$requestResponse" | sed -e 's/<[^>]*>//g' | sed '/^[[:space:]]*$/d' | sed '/<!--/,/-->/d'
  echo 
  echo "If the error was related to auth, on the Connector server, navigate to..."
  echo ">IIS Manager"
  echo ">Sites"
  echo ">Proxy"
  echo ">Configuration Editor"
  echo ">system.webServer/security/authentication/iisClientCertificateMappingAuthentication"
  echo
  echo "The cert on the one-to-one mapping should be "
  echo "$clientPfxPassword" | openssl pkcs12 -in "${clientCertPath_supplied}" -passin "stdin" -clcerts -nokeys 2>/dev/null | sed -n '/^-----BEGIN CERTIFICATE-----$/,$p'
  myexit
fi


# If curl connects and authenticates, it will return something like this: 

# This example is from a standalone CA with explicit admin approval required. 
# {
#   "request-status": {
#     "status": "CR_DISP_UNDER_SUBMISSION",
#     "message": "Request taken under submission"
#   },
#   "request-id": 90
# }

# Here's an example response from a server with an auto-issue policy...
# {
#   "request-status":{
#  	 "status":"CR_DISP_ISSUED",
#  	 "message":"Certificate issued"
#   },
#   "request-id":95
# }

# CA not set up properly...
# {
#   "request-status": {
#     "status": "CR_DISP_DENIED",
#     "message": "Request denied"
#   },
#   "x509": null
# }
# I've seen this when the ca admin rejects the request or the CA itself 
# denies the request based on policy.

# In certsrv denied requests, I once saw...
# "The revocation function was unable to check revocation because the revocation server was offline."
# I stop/started the CA service by right-clicking the ca name in certsrv. That fixed it. If not...
#  https://blogs.technet.microsoft.com/nexthop/2012/12/17/updated-creating-a-certificate-revocation-list-distribution-point-for-your-internal-certification-authority/
# Another example of something that could be wrong... 
#  https://www.ultimatewindowssecurity.com/securitylog/encyclopedia/event.aspx?eventID=4888

# Bad ADCS/IIS install might return...
# <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN""http://www.w3.org/TR/html4/strict.dtd">
# <HTML><HEAD><TITLE>Service Unavailable</TITLE>
#  <META HTTP-EQUIV="Content-Type" Content="text/html; charset=us-ascii"></HEAD>
#  <BODY><h2>Service Unavailable</h2>
#   <hr><p>HTTP Error 503. The service is unavailable.</p>
#  </BODY>
# </HTML>


# =============
# {"request-status":{"status":"INTERNAL_ERROR","message":"System.Runtime.InteropServices.COMException - CCertRequest::Submit: The permissions on this certification authority do not allow the current user to enroll for certificates. 0x80094011 (-2146877423 CERTSRV_E_ENROLL_DENIED)"},"request-id":0}
# [error] The CA denied our came back with a status of "CERTSRV_E_ENROLL_DENIED." 
# 
# "CERTSRV_E_ENROLL_DENIED" is the key finding there. 
# 
# The error typically indicates that ADCSC does not have enroll permission in CA properties.
# Fix: Go into certsrv on the CA, right-click the CA instance > security tab > Make sure the request (ADCSC Server) has Allow on "Request Permissions"
# =============


 
echo
echo "CONNECTOR SIGNING REQUEST RESPONSE: "
echo "$requestResponse"
echo


# Denied by Policy Module  0x80094800
# The request was for a certificate template that is not supported by the Certificate Services policy.
# Did you use the display name instead of the template name?


if [[ -z "$requestResponse" ]]; then
  echo "[error] Request Response is empty. I'm giving up."
  myexit
fi

if [[ "$requestResponse" == *"INTERNAL_ERROR"* ]]; then
  if [[ "$requestResponse" == *"CERTSRV_E_ENROLL_DENIED"* ]]; then
    # {"request-status":{"status":"INTERNAL_ERROR","message":"System.Runtime.InteropServices.COMException - CCertRequest::Submit: 
    #   The permissions on this certification authority do not allow the current user to enroll for certificates. 0x80094011 (-2146877423 CERTSRV_E_ENROLL_DENIED)"},"request-id":0}
    echo "[error] The CA denied our came back with a status of \"CERTSRV_E_ENROLL_DENIED.\" " 
    echo "Find your request in \"certsrv>failed requests\" to see why."
    echo "The error typically indicates that ADCSC does not have enroll permission in CA properties."  
    myexit
  fi
fi

if [[ "$requestResponse" == *"CR_DISP_DENIED"* ]]; then
  # {"request-status":{"status":"CR_DISP_DENIED","message":"Request denied"},"x509":null}
  echo "[error] The Connector denied our request with a status of \"CR_DISP_DENIED.\" " 
  echo "Find your request in \"certsrv>failed requests\" to see why."
  echo "E.g., did you give the Connector permissions in your CA?"
  echo "If you use an enterprise CA, did you specify the correct template?"
  echo "If you're using a template, does ADCSC have the enroll permission on it?"  
  myexit
fi


echo '[step] Parsing response to get the request ID for use in retrieving the signature...'
requestID=$( echo "$requestResponse" | sed -E 's|.*"request-id":([0-9]+)}|\1|' )
if [[ -z $requestID ]]; then
  echo "[error] The response did not include a request ID. I'm giving up."
  myexit
fi
if [[ "$requestID" =~ ^[0-9]+$ ]] ; then
  echo "Request ID: $requestID"
else
  echo "[error] I couldn't parse the request ID from the json response. I'm giving up."
  echo "\$requestID = \"$requestID\""
  myexit
fi
echo


# Now that we have a requestID, we can redeem that to get the actual cert from the CA. 

# Create json for the retrieval request...
echo '[step] Preparing a signature retrieval json body to send to the connector.'
read -r -d '' retrievalJSON <<EOF
{ "request-id": ${requestID},
	"config": {
		"dc": "${ADCS_CA_hostname}",
		"ca": "${ADCS_CA_InstanceName}" }
}
EOF

echo "$retrievalJSON"
echo

# Submit the retrieval request
echo "[step] Sending the retrieval command to the connector via curl..."
echo "URL: $CONNECTOR_URL/api/v1/certificate/retrieve"

retrievalResponse=$( curl \
  --cert "${clientCertPath_converted}:${clientPfxPassword}" \
	--cert-type "P12" \
  --http1.1 \
  --header "Content-Type: application/json" \
  --request POST  \
  --data "$retrievalJSON" \
  --show-error \
  --silent \
	--cacert "${serverCertPath_converted}" \
	--insecure \
  "$CONNECTOR_URL/api/v1/certificate/retrieve" )


echo
echo "SIGNATURE RETRIEVAL REQUEST RESPONSE:"
echo $retrievalResponse
echo 
# The returned signature will look something like this...
# {
#   "request-status": {
#     "status": "CR_DISP_ISSUED",
#     "message": "Certificate issued"
#   },
#   "x509": "MIIDrTCCApWgAwIBAgITOQAAAGSFKa9cUkKauQAAAAAAZDANBgkqhkiG9w0BAQsF\r\nADA5MRQwEgYKCZImiZPyLGQBGRYEY2x1YjEUMBIGCgmSJomT8ixkARkWBGphbWYx\r\nCzAJBgNVBAMTAkNBMB4XDTE5MDcwMjIwMDMyNVoXDTIwMDcwMjIwMTMyNVowFzEV\r\nMBMGA1UEAxMMd3d3LmphbWYuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB\r\nCgKCAQEAv9VydAldW1vpH1g2N2YupMULrtmhNkUxxaxgB+oKLSpXDw4mS8CY0MHx\r\n04KB/qr9qlLAvJxM/jrYwERzK8aUCriKxLZ/XNPPv3sn8Cjq9Qatlf1aelXrSA72\r\n1XI/QALuNj1jVx9fDlsRfspMV/52R/8KET8PT1pC0IbGxzNyVVL26dirasTx/78i\r\nGW4RBgRpCCBMhT7wm/YR08aw7uwL3bIbPGOYOLSjG/o6rfP98pvBU2lifmEp33oN\r\nJw9WRh0cmUmMcH4T9sT3C9xtSk2RwlV3Mc44T78oBX4Mh8Dv5LczaAMsDTCJC/6Y\r\nzAg+2CO8pcFvWx2R5cSpD0ITod1AaQIDAQABo4HPMIHMMB0GA1UdDgQWBBSnU8EY\r\nNsmwbQqbE6ShpPvMCFQ8XzAfBgNVHSMEGDAWgBTBLReeD31V01LFAOZaLZkIYzVA\r\nHTA4BgNVHR8EMTAvMC2gK6AphidmaWxlOi8vLy9tcy5qYW1mLmNsdWIvQ2VydEVu\r\ncm9sbC9DQS5jcmwwUAYIKwYBBQUHAQEERDBCMEAGCCsGAQUFBzAChjRmaWxlOi8v\r\nLy9tcy5qYW1mLmNsdWIvQ2VydEVucm9sbC9tcy5qYW1mLmNsdWJfQ0EuY3J0MA0G\r\nCSqGSIb3DQEBCwUAA4IBAQA4Bi6EsnoBSkPvutq4yUTrrcRpnik3Iz8FExCrJc4T\r\naFf100m3oVDO/mjHph5D9K6QMsQ/mZtamgsQwh5V5HNTeRe52n+zpnbPLwkHMq5W\r\nFj190NA3iviMz4gS46kNqV1Q7VbipNCg4gdJtixnv08J8kmzBTOnWpl7xczQMVpF\r\n+6gUhjJvYTvN8z1gg5KYS2vVzy/HjtarIK88no4qqWhEkxQoEBdCIY1pO9TeCLwG\r\n8IalQ1/dktURZSQZd7pPt2UeW8GQradCyeQvlBsgdzWG6EiPCctDrWH/epYhSv0n\r\neNGaM4cjQHFXVs2D7pzxK5SYb0Gb6FR3CMQpZhKFgp3r\r\n"
# }


echo "[step] Removing carriage return from JSON"
retrievalResponse=${retrievalResponse//\\\r/}
if [ "$debug" = true ] ; then
  echo
  echo "SIGNATURE RETRIEVAL REQUEST RESPONSE AFTER REMOVING NEWLINE/CARRIAGE RETURN:"
  echo "$retrievalResponse"
  echo 
fi

echo '[step] Parse out the x.509 crt from the connector response...'
# If python installed, do it like this...
# crt=$( echo "$retrievalResponse" | python -c "import sys, json; print json.load(sys.stdin)['x509']" )
crt=$( echo "$retrievalResponse" | sed -E 's|.*"x509":"(.*)"}|\1|' )


if [ "$debug" = true ] ; then
  echo '[debug] The crt portion of the response was:'
  echo "\"$crt\""
  echo
fi

if [[ -z $crt ]]; then
  echo "[error] Couldn't parse a certificate signature from the retrieval response. I'm giving up."
  echo '======================================================'
  exit
fi

if [[ $crt == "None" ]]; then
  echo "[error] The retrieval response's certificate signature field was empty. I'm giving up."
  echo '======================================================'
  exit
fi


# Convert the \n's in the json to actual newlines
# crt=$( echo "$crt" | sed 's/\\n/\'$'\n/g' )
crt=$( echo "$crt" | sed 's/\\n/\
/g' )


# Add header/footer...
crt="-----BEGIN CERTIFICATE-----
${crt}
-----END CERTIFICATE-----"

if [ "$debug" = true ] ; then
  echo
  echo '======================================================'
  echo "Finished CRT signature for our CSR :"
  echo "$crt"
  echo '======================================================'
  echo
fi

crtPath="${testFolder}/${subjNoDots}.crt"
# Save to disk since it has to be supplied to openssl in a file...
echo "$crt" > "$crtPath"

if [ "$debug" = true ] ; then
  echo '======================================================'
  echo "[step] Testing the crt key signing file: "
  openssl x509 -text -noout -in "${crtPath}"
  echo '======================================================'
fi
echo

echo "[step] Combining the signature cert and the private key into a p12." 
identPath="${testFolder}/${subjNoDots}.p12"
makeP12_response=$( openssl pkcs12 \
       -inkey "$keyPath" \
       -in "$crtPath" \
       -export \
       -password "pass:${passwordForTheNewIdentityFile}" \
       -out "$identPath" 2>&1 )


if [[ "$makeP12_response" == *"error"* ]]; then
  echo "There was an openssl error response : "
  echo "${makeP12_response}"
  myexit
else
  echo "openssl response : ${makeP12_response}"
  echo OK
fi

echo
echo "[done] The completed identity is in: ${identPath}"
echo "[note] You'd need to add in the trust chain from your CA if you need a full trust-chain identity file."
echo "[info] The password for the .p12 is : \"${passwordForTheNewIdentityFile}\" "

echo
echo '===END==='
echo

open "${testFolder}"

exit 0

# Pssst... if that worked, good for you. But you've already copied your 
# private key and password too many places. Go re-install your Connector
# to get a new client identity generated and upload it to Jamf Pro directly.
