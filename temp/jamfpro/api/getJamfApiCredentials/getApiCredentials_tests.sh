#!/bin/bash

assert_eq() {
  [[ "$#" -ne 4 ]] && { echo "assert_eq:parameter error"; exit 98; }
  [[ "$1" != "$2" ]] && { echo "line$4:$3: \"$1\" !=  \"$2\""; exit 99; }
}

undo() {
  unset apiSrvr
  unset apiUser
  unset apiPass
  echo
}

environment='test_auditor'
method='hardCoded'
source "getJamfInfo.sh" --environment "${environment}" --method "${method}"
echo "Result: apiSrvr:\"${apiSrvr}\", apiUser:\"${apiUser}\", apiPass:\"${apiPass}\""
assert_eq "http://test.my.org:8443" "${apiSrvr}" "bad apiSrvr" $LINENO
assert_eq "testaudituser" "${apiUser}" "bad apiUser" $LINENO
assert_eq "testauditpass" "${apiPass}" "bad apiPass" $LINENO
undo

environment='production_auditor'
method='hardCoded'
source "getJamfInfo.sh" --environment "${environment}" --method "${method}"
echo "Result: apiSrvr:\"${apiSrvr}\", apiUser:\"${apiUser}\", apiPass:\"${apiPass}\""
assert_eq "http://prod.jamfcloud.com" "$apiSrvr" "bad apiSrvr" $LINENO
assert_eq "prodaudituser" "$apiUser" "bad apiUser" $LINENO
assert_eq "prodauditpass" "$apiPass" "bad apiPass" $LINENO
undo

environment='production_auditor'
method='envVars'
declare "jamfinfo_${environment}_apiSrvr"="http://prod.jamfcloud.com"
declare "jamfinfo_${environment}_apiUser"="prodaudituser"
declare "jamfinfo_${environment}_apiPass"="prodauditpass"
source "getJamfInfo.sh" --environment "${environment}" --method "${method}"
echo "Result: apiSrvr:\"${apiSrvr}\", apiUser:\"${apiUser}\", apiPass:\"${apiPass}\""
assert_eq "http://prod.jamfcloud.com" "$apiSrvr" "bad apiSrvr" $LINENO
assert_eq "prodaudituser" "$apiUser" "bad apiUser" $LINENO
assert_eq "prodauditpass" "$apiPass" "bad apiPass" $LINENO
undo

export "jamfinfo_production_auditor_apiSrvr"="http://prod.jamfcloud.com"
export "jamfinfo_production_auditor_apiUser"="prodaudituser"
export "jamfinfo_production_auditor_apiPass"="prodauditpass"
environment='production_auditor'
method='envVars'
# declare "jamfinfo_${environment}_apiSrvr"="http://prod.jamfcloud.com"
# declare "jamfinfo_${environment}_apiUser"="prodaudituser"
# declare "jamfinfo_${environment}_apiPass"="prodauditpass"
source "getJamfInfo.sh" --environment "${environment}" --method "${method}"
echo "Result: apiSrvr:\"${apiSrvr}\", apiUser:\"${apiUser}\", apiPass:\"${apiPass}\""
assert_eq "http://prod.jamfcloud.com" "$apiSrvr" "bad apiSrvr" $LINENO
assert_eq "prodaudituser" "$apiUser" "bad apiUser" $LINENO
assert_eq "prodauditpass" "$apiPass" "bad apiPass" $LINENO
undo

prefPath="${HOME}/Library/Preferences/com.jamfinfo.${environment}.plist"
defaults write "${prefPath}" apiSrvr "http://prod.jamfcloud.com"
defaults write "${prefPath}" apiUser "prodaudituser"
defaults write "${prefPath}" apiPass "prodauditpass"
environment='production_auditor'
method='prefFile'
source "getJamfInfo.sh" --environment "${environment}" --method "${method}"
echo "Result: apiSrvr:\"${apiSrvr}\", apiUser:\"${apiUser}\", apiPass:\"${apiPass}\""
assert_eq "http://prod.jamfcloud.com" "$apiSrvr" "bad apiSrvr" $LINENO
assert_eq "prodaudituser" "$apiUser" "bad apiUser" $LINENO
assert_eq "prodauditpass" "$apiPass" "bad apiPass" $LINENO
rm "${prefPath}"
undo

environment='production_auditor'
method='keychain'
prefix="jamfinfo_${environment}_"
security add-generic-password -s "${prefix}_apiSrvr" -a ${USER} -w "http://prod.jamfcloud.com" 2>/dev/null
security add-generic-password -s "${prefix}_apiUser" -a ${USER} -w "prodaudituser" 2>/dev/null
security add-generic-password -s "${prefix}_apiPass" -a ${USER} -w "prodauditpass" 2>/dev/null
source "getJamfInfo.sh" --environment "${environment}" --method "${method}"
echo "Result: apiSrvr:\"${apiSrvr}\", apiUser:\"${apiUser}\", apiPass:\"${apiPass}\""
assert_eq "http://prod.jamfcloud.com" "$apiSrvr" "bad apiSrvr" $LINENO
assert_eq "prodaudituser" "$apiUser" "bad apiUser" $LINENO
assert_eq "prodauditpass" "$apiPass" "bad apiPass" $LINENO
undo
security delete-generic-password -s "${prefix}_apiSrvr" -a ${USER} 2>/dev/null
security delete-generic-password -s "${prefix}_apiUser" -a ${USER} 2>/dev/null
security delete-generic-password -s "${prefix}_apiPass" -a ${USER} 2>/dev/null


echo 'Done: Tests completed'
exit 0
