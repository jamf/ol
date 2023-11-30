#!/bin/bash

environment='sandbox.readonly'; 
debugMode=True
verboseCurl=False
resetLogFile=True
logFilePath="${BASH_SOURCE[0]}.log"


# For most applications, this is way too much. A curl one-liner is all you need
# to get data from the Jamf Pro API. But But this example demonstrates some
# techniques for more complex operations. On the other hand, if you're going to
# get this complicated, consider python, etc. 

# Demonstrates: 
# - Named function parameters
# - Variable scope in bash
# - Calling functions and assigning output to a variable
# - Returning multiple values from functions (albeit in global vars)
# - Options to log to file or stdout
# - Use of curl timeouts
# - How to handle session cookies
# - Returning http status for API calls
# - Getting API credentials from keychain
# - Handles Jamf Pro API auth for you, i.e., fetches auth tokens as needed
# - Refreshing auth tokens as they near expiration/Clearing them when done.
# - Error messages relevant to the Jamf Pro API
# - Demonstrate how to parse out data elements
# - Convert child object data (e.g. lists of computer IDs) to iterable arrays
# - Extract data from json via XPath. (Consider using jq instead.)

# Tip, (not used here...) you can register top level script so we can terminate it from 
# functions called via x=$(func) 
# trap "exit 1" TERM
# export TOP_PID=$$
# Now you can use "kill -s TERM $TOP_PID;" in function code. 

# ############################## FUNCTIONS ##############################
# ############## LOGGING FUNCTIONS...
writeMessage() { echo "$@"; }
writeMessageToFile() { 
    local callInfo="[line:${BASH_LINENO[1]}]"
    echo "[$(date '+%Y/%m/%d %T')]" "$@" "${callInfo}" >> "${logFilePath}"; 
}
writeMessageToFileAndStdout() { writeMessage "$@"; writeMessageToFile "$@"; }
writeBlankLineToFile() { echo "" >> "${logFilePath}"; }
logerror() { writeMessage "[ERROR] [!] " "$@"; writeMessageToFile "[ERROR] [!]" "$@";  }
debug() { [[ $debugMode == True ]] && { writeMessage "[debug]" "$@"; writeMessageToFile "[debug]" "$@"; } }
debugToFile() { [[ $debugMode == True ]] && writeMessageToFile "[debug]" "$@"; }

logHttpStatus() {
#   debug "logHttpStatus httpStatus : ${httpStatus}"
  case "${httpStatus}" in
    000) logerror "000	CURL error. HTTPS URI? Bad URL? TLS Issue? Network down?";;
    200) debugToFile "200	success"; echo "ok";;
    201) debugToFile "201	Create or update success"; echo "ok";;
    400) logerror "400	Bad request. Verify your XML/JSON?";;
    401) logerror "401	Authentication failed.";;
    403) logerror "403	Privileges issue.";;
    404) logerror "404	Resource not found. Typo in the API path? Object exists?";;
    405) logerror "405	Wrong request method (E.g., Did you GET when you meant to POST?)";;
    409) logerror "409	Conflict. See the error response for details.";;
    500) logerror "500	Internal server error. Check the Jamf Pro logs.";;
    502) logerror "502	Bad Gateway. This is usually a timeout issue.";;
    *)   logerror "[error-logHttpStatus] (${httpStatus}) There was an unexpected error calling the api.";;
  esac
}

# ############## CURL/API FUNCTIONS...
callJamfProAPI() {
  # PARAMETERS:
  # --endpoint : the api endpoint (required)
  # --request  : GET | PUT | POST | DELETE | PATCH (default=GET)
  # --data     : Post/Put/Patch can send data to Jamf Pro
  # --timeout  : How long to connect? (Increase for low networks) (default=5)
  # --maxtime  : How long to wait for a response before giving up. (Increase for call that return a lot of data) (default=20)
  # 
  # EXAMPLES: 
  # Get a classic API endpoint...
  #   callJamfProAPI --endpoint "/JSSResource/..." 
  # Get a Jamf Pro API endpoint...
  #   callJamfProAPI --endpoint "/api/__"
  # Post data to a classic API endpoint...
  #   callJamfProAPI --endpoint "/JSSResource/__" \
  #     --request "POST" \
  #     --data "<xml></xml>"
  # Give the API more time to respond...
  #   callJamfProAPI --endpoint "/JSSResource/thatWillRunLong" \
  #     --timeout 10 \
  #     --maxtime 120  # Take up to 2 minutes...

  debugToFile "[start] callJamfProAPI $*"

  # SETUP...
  # Ingest the arguments. 
  # First, setup default values
  request=${request:-GET}  # If no request method provided, do a GET
  timeout=${timeout:-5}  # If no connection timeout given, go with 5 seconds
  maxtime=${maxtime:-20} # If no total time given, go with 20 seconds
  # (endpoint and data have no default value. Endpoint is required) 

  # Next, assign the values to a variable with the same name as their parameter label. 
  while [ $# -gt 0 ]; do  # Read parameters
    if [[ $1 == *"--"* ]]; then
      param="${1/--/}"
      declare "$param"="$2"
    fi
    shift
  done

  [[ -z ${endpoint} ]] && { echo '[error] No API endpoint provided'; exit 1; }
  
  debugToFile "callJamfProAPI starting Parameters:"
  debugToFile "  endpoint: ${endpoint}"
  debugToFile "  request: ${request}"
  debugToFile "  data: ${data}"
  debugToFile "  timeout: ${timeout}"
  debugToFile "  maxtime: ${maxtime}"

  getSecrets() {
    debugToFile "[start] callJamfProAPI.getSecrets"
    if [[ -n ${apiSrvr} || -n ${apiUser} || -n ${apiPass} ]]; then
      debugToFile "[ok] We already have secret values"
    else
      debugToFile "Retrieving API Server and API user/password"
      local prefix="jamfinfo_${environment}"
      # Keychain method for retrieving credentials. Use these commands to create entries or enter in Keychain Access.app
      # security add-generic-password -s "${prefix}_apiSrvr" -a "${USER}" -w "http://prod.jamfcloud.com" 2>/dev/null
      # security add-generic-password -s "${prefix}_apiUser" -a "${USER}" -w "api_readonly" 2>/dev/null
      # security add-generic-password -s "${prefix}_apiPass" -a "${USER}" -w "api_readonly_password" 2>/dev/null
      apiSrvr=$(security find-generic-password -s "${prefix}_apiSrvr" -a "${USER}" -w 2>/dev/null)
      apiUser=$(security find-generic-password -s "${prefix}_apiUser" -a "${USER}" -w 2>/dev/null)
      apiPass=$(security find-generic-password -s "${prefix}_apiPass" -a "${USER}" -w 2>/dev/null)
      [[ -z ${apiSrvr} || -z ${apiUser} || -z ${apiPass} ]] && { echo "[error] Could not read secrets"; exit 1; }
      debugToFile "[ok] We now have secret values"
    fi
    debugToFile "[end] callJamfProAPI.getSecrets"
  }
  getSecrets
  [[ -z ${apiSrvr} || -z ${apiUser} || -z ${apiPass} ]] && exit 1

  getJamfProVersion() {
    debugToFile "[start] callJamfProAPI.getJamfProVersion"
    # Asumes script operates on only one Jamf Pro or Jamf Pros of the same version
    myJamfProVersion="$1"
    if [[ -n "$myJamfProVersion" ]]; then
      debugToFile "[ok] myJamfProVersion is already known ($myJamfProVersion)"
      printf %s "$myJamfProVersion"  # already know the version. Spit it back. 
    else
      debugToFile "[step] Requesting Jamf version from Jamf Pro..."
      versionString=$(/usr/bin/curl --silent "${apiSrvr}/JSSCheckConnection")  # TODO -- switch this to call callJamfProAPI instead of curl?
      debugToFile "String returned by Jamf Pro: ${versionString}"
      [[ "$versionString" =~ (.+)\.(.+)\.(.+)-(.+) ]] && printf %02d%02d "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
      [[ -z "$versionString" ]] && { echo '[error] Could not get Jamf Pro version'; exit 1; }
      debugToFile "[end] getJamfProVersion"
    fi
    debugToFile "[end] callJamfProAPI.getJamfProVersion"
  }
  jamfProVersion=$(getJamfProVersion "$jamfProVersion")
  [[ -z "$jamfProVersion" ]] && exit 1

  getAuthToken() {
    debugToFile "[start] callJamfProAPI.getAuthToken"

    updateTokenVars() {
      debugToFile "[start] callJamfProAPI.getAuthToken.updateTokenVars"
      # Sub-function Write getToken JSON response items to vars for use in bearer auth in curl headers
      # Pass in the response to your Jamf Pro token request to this function
      local tokenJson
      local bearerToken
      tokenJson="$1"
      bearerToken=$(printf "%s" "${tokenJson}" | /usr/bin/plutil -extract "token" raw -o - -)
      # bearerToken=$( /usr/bin/awk -F \" '{ print $4 }' <<< "$bearerTokenFull" | head -n 2 | tail -n 1 )
      authHeader="Authorization: Bearer $bearerToken"
      debugToFile "authHeader: \"${authHeader:0:40}...\""
      # Now record the expiration so we know when to renew the token
      expiresZuluTime=$(printf "%s" "${tokenJson}" | /usr/bin/plutil -extract "expires" raw -o - -)  # 2020-09-09T02:17:10.878Z
      authHeaderExpires=$(/bin/date -jf "%Y-%m-%dT%H:%M:%S" "${expiresZuluTime%.*}" "+%s")  # 1579261308 (seconds)  "%Y-%m-%dT%H:%M:%S"
      authHeaderExpires="$((authHeaderExpires-60))" # Subtract a minute
      debugToFile "authHeaderExpires (epoch seconds): \"${authHeaderExpires}\""
      debugToFile "[end] callJamfProAPI.getAuthToken.updateTokenVars"
    }

    # These endpoints use bearer token auth (/JSSResource in 10.35 and above)
    debugToFile "Token-auth API endpoint requested"
    # Do we already have an auth token?
    if [[ -n ${authHeader} ]]; then
      debugToFile "We already have an auth token."
      # Has it expired?
      if [[ ${bearerToken_expires} -ge $(/bin/date "+%s") ]]; then
        debugToFile "The token has expired. Unsetting so a new one will be generated"
        unset authHeader
        unset bearerToken_expires
      else
        debugToFile "Token has not yet expired."
      fi
    fi
    # Request auth token if none exists
    debugToFile "Re-checking if there is a calculated auth header"
    if [[ -z ${authHeader} ]]; then
      debugToFile "No auth token found. Requesting new"
      debugToFile "Sending a token request to ${apiSrvr}/api/v1/auth/token..."
      json=$(/usr/bin/curl --silent --request "POST" --user "${apiUser}:${apiPass}" "${apiSrvr}/api/v1/auth/token")  # TODO -- switch this to call callJamfProAPI instead of curl
      updateTokenVars "$json"
    fi
    # Refresh token if expiring soon
    if [[ -n ${bearerToken_expires} && "$endpoint" != *"/auth/keep-alive" ]]; then  # if there is an expiration
      debugToFile "Checking auth token expiration"
      timeNowSeconds=$(/bin/date "+%s")
      timeNowSeconds=$(( timeNowSeconds-120 ))
      if [[ ${bearerToken_expires} -ge ${timeNowSeconds} ]]; then
        json=$(callJamfProAPI "/api/v1/auth/keep-alive" 'POST')
        updateTokenVars "$json"
      fi
    fi
    debugToFile "[end] callJamfProAPI.getAuthToken"
  }
  getAuthToken
  [[ -z "${authHeader}" || -z "${authHeaderExpires}" ]] && exit 1

  getCookie() {
    debugToFile "[start] callJamfProAPI.getCookie"
    if [[ "$endpoint" == *"/auth/token" ]]; then
      debugToFile "Capturing APBALANCEID cookie"
      # < set-cookie: AWSALB=5QLEa8p...+5MA1EMIE; Expires=Sat, 05 Feb 2022 13:53:48 GMT; Path=/
      # < set-cookie: AWSALBCORS=5QLEa8p...+5MA1EMIE; Expires=Sat, 05 Feb 2022 13:53:48 GMT; Path=/; SameSite=None; Secure
      # < set-cookie: APBALANCEID=aws.use1-std-ellison9-tc-99; path=/;HttpOnly;Secure;
      # TODO - call curl via callJamfProAPI
      cookies=$(/usr/bin/curl --silent --output /dev/null --cookie-jar - "${url}")
      # cookies=$(echo "${cookies}" | sed '/^# /d')  # Take out the comments for brevity (not actually needed)
      debugToFile "Cookies: ${cookies}"
      # cookies=$(echo "${cookies}" | tr -d '\n')
    fi
    debugToFile "[start] callJamfProAPI.getCookie"
  }
  # TODO - if stickiness cookie not in $cookies, capture cookies. Then the above is not needed. 
  # TODO - Cookie is different on premium cloud

  # Setup... construct url and basic auth values. Get an auth token.
  local url
  url="${apiSrvr}${endpoint}"
  
  # Construct curl aurguments
  local -a curlCmdArgs
  curlCmdArgs+=('--silent' '--show-error')
  curlCmdArgs+=('--connect-timeout' "${timeout}")
  curlCmdArgs+=('--max-time' "${maxtime}")
  curlCmdArgs+=('--request' "${request}")  # get, post, put, delete, patch, etc.
  [[ $verboseCurl == True ]] && curlCmdArgs+=('--verbose')  # Want verbose?
  [[ -n $data ]] && curlCmdArgs+=('--data' "${data}")  # Got any data?
  curlCmdArgs+=('--write-out' '\n%{http_code}')  # Get the http code with curl responses

  debugToFile "**** Setting up for authentication ****"
  if [[ "$endpoint" == "/api"* ]]; then
    curlCmdArgs+=('--header' 'Accept: application/json')
    debugToFile "Call is to a /api Jamf Pro API endpoint"
    if [[ "$endpoint" == *"/auth/token" ]]; then
      debugToFile "Call is to /auth/token endpoint. Using \"--user\" auth"
      curlCmdArgs+=('--user' "${apiUser}:${apiPass}")
    elif [[ "$endpoint" != *"/auth/token" ]]; then
      debugToFile "Call is to a /api endpoint other than /auth/token. Adding a bearer token auth header."
      curlCmdArgs+=('--header' "${authHeader}")
    fi
  elif [[ "$endpoint" == "/JSSResource"* ]]; then
    debugToFile "Call is to a /jssresource Clasic API endpoint"
    curlCmdArgs+=('--header' 'Accept: text/xml')  # could use the json option
    if [[ "$jamfProVersion" -ge 1035 ]]; then
      debugToFile "Jamf Pro version is >= 10.35 so we will add a bearer token auth header."
      curlCmdArgs+=('--header' "${authHeader}")
    else
      debugToFile "Jamf Pro version is < 10.35 so we will use \"--user\" auth"
      curlCmdArgs+=('--user' "${apiUser}:${apiPass}")
    fi
  else
    debugToFile "Call is not to \"/api\" or \"/JSSResource\" so no auth is needed."
  fi

  curlCmdArgs+=('--url' "${url}")  # the --url param label is optional

  # Call curl
  local curlResponse
  if [[ -z $cookies || " ${curlCmdArgs[*]} " =~ " --user " ]]; then
    debugToFile "/usr/bin/curl ${curlCmdArgs[*]}"
    curlResponse=$(/usr/bin/curl "${curlCmdArgs[@]}")
  else  # We haz cookies
    debugToFile "Running curl: echo \"${cookies}\" | /usr/bin/curl ${curlCmdArgs[*]}"
    curlResponse=$(echo "${cookies}" | /usr/bin/curl  "${curlCmdArgs[@]}")
    # debugToFile "Running curl: echo \"${cookies}\" | ${curlCmd} --write-out $'\n%{http_code}' --cookie - \"${url}\""
    # curlResponse=$(echo "${cookies}" | $curlCmd --write-out $'\n%{http_code}' --cookie - )
  fi

  # --write-out $'\n%{http_code}' told curl to add a status line at the end
  httpStatus=$( echo "$curlResponse" | tail -1)
  apiResponse=$( echo "$curlResponse" | sed \$d )
  debugToFile "===================================="
  debugToFile "apiResponse: (${httpStatus}) ${apiResponse}"
  debugToFile "===================================="
  debugToFile "[end] callJamfProAPI"
}

checkApiException() {
  expectedHttpStatus="$1"
  logHttpStatus
  if [[ ${httpStatus} -ne ${expectedHttpStatus} ]]; then
    logError "HTTP Status check problem: ${expectedHttpStatus} (expected), ${httpStatus} (actual)"
    logError "${apiResponse}"
  fi
}

getXmlPath() {
  local myXml
  local myXpath
  myXml=$1
  myXpath=$2
  if [[ $debugMode == True ]]; then
    echo "${myXml}" | /usr/bin/xpath -e "$myXpath"
  else
    echo "${myXml}" | /usr/bin/xpath -e "$myXpath" 2> /dev/null
  fi  
}

getXmlValue() {
  local myXml
  local myXpath
  myXml=$1
  myXpath=$2
  myXpath="${myXpath}/text()"
  getXmlPath "${myXml}" "$myXpath"
}

getXmlValues() {
  local myXml
  local myXpath
  myXml=$1
  myXpath=$2

  # Creates an array of values
  # E.g., "<app>MS Word</app>\n<app>MS Excel</app>\n<app>MS Outlook</app>"
  # Becomes ("MS Word" "MS Excel" "MS Outlook")

  local elementID
  local openingTag
  local closingTag
  elementID="${myXpath##*\/}"  # what's the last item in the xpath?
  openingTag="<${elementID}>"
  closingTag="</${elementID}>"
  # echo "elementID: $elementID"
  # echo "openingTag: $openingTag"
  # echo "closingTag: $closingTag"

  myXml=$(getXmlPath "${myXml}" "$myXpath")  # get the items we want
  # That gets us <id>1</id>\n<id>2</id>\n<id>3</id>...
  myXml=${myXml//$'\n'/}  # Remove any newlines
  # That gets us <id>1</id><id>2</id><id>3</id>...
  myXml=${myXml//$openingTag/}  # Remove the opening tags
  # That gets us 1</id>2</id>3</id>...

  # Checkup... If $myXml does not end in $closingTag, something is wrong. 
  [[ "${myXml}" != *"${closingTag}" ]] && { echo "Error in splitting xml. ${closingTag} needed at the end"; exit 1; }

	# Now convert to an array, splitting values on the </id> tags
  # This works well as long as the closing tag does not appear anywhere in the data values themselves. 
  xmlItemArray=()
  while [[ "$myXml" == *"${closingTag}" ]]; do
    xmlItemArray+=( "${myXml%%"$closingTag"*}" )
    myXml=${myXml#*"$closingTag"}
  done
}


# ############################## SETUP ##############################
debug "[start] Script running in debug mode."
debug "pwd : $(pwd)"
debug "logFilePath : ${logFilePath}"
echo

[[ $resetLogFile == True ]] && echo '' > "${logFilePath}"


# ############################## YOUR SCIPT ##############################
# API EXAMPLES...


echo "Example 1. Getting Jamf Pro Version"
callJamfProAPI --endpoint "/JSSCheckConnection"
echo "API call status is $(checkApiException 200)"  # returns "ok" or an error message
writeMessageToFileAndStdout "The Jamf Pro version is \"${apiResponse}\"$'n"
# writeBlankLineToFile; echo ''


echo "Example 2. How many computers are there?"
callJamfProAPI --endpoint "/JSSResource/computers"
echo "API call status is $(checkApiException 200)"
computerCount=$(getXmlValue "${apiResponse}" '/computers/size')  # <computers><size>118
echo "There are ${computerCount} computers in Jamf Pro"
writeBlankLineToFile; echo ''


echo "Example 3. Getting a list of all computer IDs"
# Re-using ${apiResponse} from example 2...
idList=$(getXmlValue "${apiResponse}" '//computers/computer/id')
echo "$idList"
while IFS= read -r id; do
  echo "${id}"
done <<< "${idList}"
writeBlankLineToFile; echo ''


echo "Example 4. Getting a list of all computer Names, array method"
# The above works fine for things like IDs, but if the data could contain 
# bash IFS delimiters like spaces and newlines, parse the data to an array.
# (Reusing $apiResponse from example 2, but parsing it differently than example 3.)
getXmlValues "${apiResponse}" '//computers/computer/name'
# getXmlValues puts its answers in $xmlItemArray
for item in "${xmlItemArray[@]}"; do
  echo "$item"
done
writeBlankLineToFile; echo ''


echo "Example 5. Handling pagination..."
# The Jamf Pro API introduces the concept of pagination. That's a big help
# for admins with a lot of data. The Classic API could time-out if asked to 
# get 100s of thousands of records. Bash variables can hold a huge amount of 
# data, so callJamfProAPI could just concatenate everything into one big
# json, but the bigger the json gets, the longer it takes to parse. So 
# maybe better to process things a page at a time...  
# When you need to fetch a lot of data, you can split the results up into chunks
# by including something like &page=0&page-size=100. Page is the zero-based page 
# number and page-size is the number of records you want per page. A page size of
# 100 is a reasonable starting point, but if you find you can get more reliably, 
# get more. The fewer trips to the API you take, the faster your script will run.
# Some requests require a lot less effort on the server side than others. 

# Send the first query as page=0, process the results, then get page 1, and so on. 
# There are a few ways to know you've hit the end... 
# 1. Every page will include the total record count so you can count the items as
#    you process them and when you reach the total, you know there's no point in 
#    asking for another page. Or do some math based on the page-size and figure 
#    out how many pages it's going to take to get everything. 
# 2. If a page has fewer than "page-size" records, it's the last page. 
# 3. Keep requesting pages until you get a page with no results. 

# Example curl...
# curl -X GET \
# "https://you.jamfcloud.com/api/v1/computers-inventory?section=GENERAL&section=HARDWARE&page=0&page-size=100&sort=id%3Aasc&filter=general.reportDate%3E%3D%222017-11-27T16%3A59%3A26.084Z%22" \
# -H "accept: application/json" \
# -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.ey...

# {
#   "totalCount": 118,
#   "results": [
#     {
#       "id": "1",
#       "udid": "70FDEE4A-EE25-56EC-B020-6DC2B677BDDC",
#       "general": {
#         "name": "xmlname",
#         "lastIpAddress": "38.126.164.226",
#         "lastReportedIp": "10.15.24.202",
#         "jamfBinaryVersion": "10.0.0-t1508873342",
#         "platform": "Mac",
 
# "results" is the top-level list of computers. Record count is also a top-level. 
 
# If you loop, eventually you will call a page and get a response with nothing in it...
# {
#   "totalCount": 118,
#   "results": []
# }

# Parsing json in bash is a little ridiculous (use jq/python/etc.), but you can 
# if you have to be portable. 

pageSize=10
  # Build an endpoint. This way is maybe more readable than a one-liner. 
# (page-size is smaller than customary... just using that as an example.)
endpoint=""
endpoint=$endpoint"/api/v1/computers-inventory"
endpoint=$endpoint"?section=GENERAL"
endpoint=$endpoint"&page-size=${pageSize}"
endpoint=$endpoint"&sort=id%3Aasc'"
# We'll be appending the "&page=x" to that as we loop through the pages

# Now we need to read data out of the JSON, but we don't know how many pages will be needed. 
nextPage=0
lastPage=999  # We don't yet know what the last page will be. This is a placeholder...
until [[ $nextPage -gt $lastPage ]]; do
  thisPage=$nextPage       # Just for clarity when we echo it or use it in the API call...
  ((nextPage=nextPage+1))  # Next time through the loop we'll be getting nextPage

  echo
  echo "Fetch computers from Jamf Pro - retrieving page $thisPage"
  callJamfProAPI --endpoint "${endpoint}&page=${thisPage}"
  echo "API call status is $(checkApiException 200)"

  if [ $thisPage -eq 0 ]; then  # we have some math to do first time through...
    echo '======================================================================'
    echo "This is our first page, so we'll see how many devices we have and figure out the total pages."
    totalCount=$(/usr/bin/plutil -extract "totalCount" raw -o - - <<< "${apiResponse}")
    echo "You have $totalCount computers"
    # back to CS101... 81 devices/10 per page would take 9 pages. 1-8 would have 10 computers, page 9 would have 1. 
    # ...but page reference are zero-based so the last page index is "8". (0..8 is 9 pages)
    (( lastPage=((totalCount+pageSize-1)/pageSize)-1 ))
    echo "With a page size of ${pageSize}, that's means we'll load pages 0 through ${lastPage}."
    echo '======================================================================'
  fi

  # Here you would process the computers contained in the current page. 
  echo "Processing devices on page $thisPage"
  echo

  # Again, in the real world you wouldn't use plutil, you'd use 
  # something that does json. But it makes for a simpler example
  # since it comes pre-installed. 
  
  echo "Replacing null values with strings..."

  # plutil chokes on null values in json, so convert to empty strings
  # too slow...  apiResponse=${apiResponse//: null/: \"\"}
  apiResponse=$(echo "$apiResponse" | sed 's|: null|: ""|g')

  # Example of converting json to plist in xml format... 
  echo "Converting json to xml..."
  plist=$(echo "$apiResponse" | /usr/bin/plutil -convert xml1 -o - -- -)

  # Example of using xpath to get data from a plist, which is a form of XML in it's xml1 expression.
  echo "Counting records in this page..."
  pageRecordCount=$(echo "$plist"  | xpath -e "count(/plist/dict/array[preceding-sibling::key='results']/dict)" 2>/dev/null)
  echo "This page has $pageRecordCount computer(s)."

  # But suppose you wanted to get a list of all the computer names. 
  # | xpath -e "/plist/dict/array[preceding-sibling::key='results']/dict/dict[preceding-sibling::key='general']/string[preceding-sibling::key='name']"
  # Even if you can work all that out, it's nearly incomprehensible. 
  
  # Here is a _much_ easier way to do it using plistbuddy... 
  # plist array elements are zero-based so we start at 0
  for (( i = 0; i < pageRecordCount; i++ )); do
    echo "Processing page $thisPage : computer $i of $pageRecordCount"    
    # Example of using plistbuddy to read plist data items, in this case, computer names...
    /usr/libexec/PlistBuddy -c "print :results:$i:general:name" /dev/stdin <<< "$plist"
  done
    
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