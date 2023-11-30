# jamfinfo

Get secrets out of your API scripts.

See the functional tests script for examples of how to use each method, hard-coded, environment variables, prefs file, keychain, prompt the user, and "all of the above until you find someting ("scan"). 


Here are some examples of how you use it. Pick the method you like and add the lines for that method to your api script anywhere before you make your first curl. Then you can use ${apiSrvr}, ${apiUser}, and ${apiPass} in your script. 

```
# PREP: 
# Add your values to the getjamfinfo.sh script, then in you script...
method='hardCoded'
environment='test_auditor'
source "getJamfInfo.sh" --environment "${environment}" --method "${method}"


# PREP: 
# Create env vars in your shell (e.g., in ~/.profile)
#  export "jamfinfo_production_auditor_apiSrvr"="http://prod.jamfcloud.com"
#  export "jamfinfo_production_auditor_apiUser"="prodaudituser"
#  export "jamfinfo_production_auditor_apiPass"="prodauditpass"
# Then in you script...
environment='production_auditor'
method='envVars'
source "getJamfInfo.sh" --environment "${environment}" --method "${method}"


# PREP: 
# prefPath="${HOME}/Library/Preferences/com.jamfinfo.production_auditor.plist"
# defaults write "${prefPath}" apiSrvr "http://prod.jamfcloud.com"
# defaults write "${prefPath}" apiUser "prodaudituser"
# defaults write "${prefPath}" apiPass "prodauditpass"
method='prefFile'
environment='production_auditor'
source "getJamfInfo.sh" --environment "${environment}" --method "${method}"

# PREP: 
# Add secrets by hand in KeyChain Access or via command line... 
# prefix="jamfinfo_ production_auditor_"
# security add-generic-password -s "${prefix}_apiSrvr" -a ${USER} -w "http://prod.jamfcloud.com" 2>/dev/null
# security add-generic-password -s "${prefix}_apiUser" -a ${USER} -w "prodaudituser" 2>/dev/null
# security add-generic-password -s "${prefix}_apiPass" -a ${USER} -w "prodauditpass" 2>/dev/null
method='keychain'
environment='production_auditor'
source "getJamfInfo.sh" --environment "${environment}" --method "${method}"


# PREP: 
# None needed
method='prompt'
environment='production_auditor'
source "getJamfInfo.sh" --environment "${environment}" --method "${method}"

```

You can also use the "scan" method which looks for the secrets as hard-coded, environment vars, prefs file, and keychain. If it doesn't find them, it will prompts you for them. 