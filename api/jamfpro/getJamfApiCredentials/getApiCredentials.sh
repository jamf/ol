#!/bin/bash

# Call this from Jamf Pro API scripts to populate $apiSrvr, $apiUser, $apiPass

# USAGE EXAMPLES:
# method="envVars" | "hardCoded" | "prefFile" | "keychain" | "prompt" | "scan"
# environment="whatever" (E.g., "prod-auditor", "dev-write-computers")
# #   ("scan" means "try every method until you get passwords")
# source "${HOME}/.getJamfInfo.sh" --environment "${environment}" --method "${method}"

# See getJamfInfo_tests.sh for more examples and how to set things up.

# CREDITS:
# https://derflounder.wordpress.com/2022/01/05/updated-script-for-obtaining-checking-and-renewing-bearer-tokens-for-the-classic-and-jamf-pro-apis
# https://scriptingosx.com/2021/04/get-password-from-keychain-in-shell-scripts/

allPopulated(){
  [[ ! -z ${apiSrvr} || ! -z ${apiUser} || ! -z ${apiPass} ]]
}

envVars() {
  varname="jamfinfo_${environment}_apiSrvr"; apiSrvr="${!varname}"
  varname="jamfinfo_${environment}_apiUser"; apiUser="${!varname}"
  varname="jamfinfo_${environment}_apiPass"; apiPass="${!varname}"
}

hardCoded() {
  case ${environment} in
    production_auditor)
      apiSrvr="http://prod.jamfcloud.com"
      apiUser="prodaudituser"
      apiPass="prodauditpass"
      ;;
    test_auditor)
      apiSrvr="http://test.my.org:8443"
      apiUser="testaudituser"
      apiPass="testauditpass"
      ;;
    *)
      echo "[getJamfInfo] No hardcoded credentials found for environment \"${environment}\""
      ;;
  esac
}

prefFile() {
  # Read values from ~/Library/Preferences/com.jamfinfo.${environment}.plist
  # To create the file, run the following commands after replacing ${environment} with a value:
  # defaults write $HOME/Library/Preferences/com.jamfinfo.${environment} apiSrvr https://my.jamfcloud.com
  # defaults write $HOME/Library/Preferences/com.jamfinfo.${environment} apiUser API_account_username_goes_here
  # defaults write $HOME/Library/Preferences/com.jamfinfo.${environment} apiPass API_account_password_goes_here
  if [[ -f "$HOME/Library/Preferences/com.jamfinfo.${environment}.plist" ]]; then
    apiSrvr=$(defaults read $HOME/Library/Preferences/com.jamfinfo.${environment} apiSrvr)
    apiUser=$(defaults read $HOME/Library/Preferences/com.jamfinfo.${environment} apiUser)
    apiPass=$(defaults read $HOME/Library/Preferences/com.jamfinfo.${environment} apiPass)
  fi
}

keychain() {
  prefix="jamfinfo_${environment}_"
  apiSrvr=$(security find-generic-password -s "${prefix}_apiSrvr" -a "${USER}" -w 2>/dev/null)
  apiUser=$(security find-generic-password -s "${prefix}_apiUser" -a "${USER}" -w 2>/dev/null)
  apiPass=$(security find-generic-password -s "${prefix}_apiPass" -a "${USER}" -w 2>/dev/null)
}

prompt() {
  [[ -z "$apiSrvr" ]] && read -p "Please enter your Jamf Pro server URL : " apiSrvr
  [[ -z "$apiUser" ]] && read -p "Please enter your Jamf Pro user account : " apiUser
  [[ -z "$apiPass" ]] && read -p "Please enter the password for the $apiUser account: " -s apiPass
}

# #################################### SETUP
method=${method:-scan}  # If no method provided, try everything
while [ $# -gt 0 ]; do  # Read parameters
   if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare $param="$2"
   fi
  shift
done
echo "[getJamfInfo] environment: $environment, method: $method"
[[ -z ${environment} ]] && { echo '[getJamfInfo] Error (No environment provided)'; exit 1; }
[[ $method == 'scan' ]] && method='hardCoded envVars prefFile keychain prompt'

# #################################### SCRIPT 
for theMethod in $method; do
  echo "[getJamfInfo] Looking up info via ${theMethod}"
  eval $theMethod
  apiSrvr=${apiSrvr%%/}  # Remove the trailing slash from the Jamf Pro URL if needed.
  [[ allPopulated ]] && return
  if [[ $method != 'scan' ]]; then
    echo '[getJamfInfo] Error - ${method} values not found'
    exit 1
  fi
done

# Copyright notice - © 2023 JAMF Software, LLC.

# THE SOFTWARE IS PROVIDED "AS-IS," WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT. IN NO EVENT SHALL JAMF SOFTWARE, LLC OR ANY OF ITS
# AFFILIATES BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OF OR OTHER DEALINGS IN THE
# SOFTWARE, INCLUDING BUT NOT LIMITED TO DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, CONSEQUENTIAL OR PUNITIVE DAMAGES AND OTHER DAMAGES SUCH AS
# LOSS OF USE, PROFITS, SAVINGS, TIME OR DATA, BUSINESS INTERRUPTION, OR
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES.