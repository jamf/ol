#!/bin/bash

# SETUP...

# Be safe... create a READ-ONLY JSS user for your reporting scripts. 

# Your Jamf Pro API credentials will be read from a .netrc file that looks like this... 

# % cat ~/.netrc 
# machine my.jamfcloud.com
# login myApiUser
# password myApiPassword

# You could hard-code them here by replacing the --netrc line in getNewBearerToken()
# with --user 'myApiUser:myApiPassword', but the netrc file is safer. 


# ================================================================================
# Settings...

JSS_URL="https://my.jamfcloud.com"
# Set TEST_MODE to true to process only the first 10 devices (for faster test runs)
TEST_MODE=true
# Set DEBUG_LOGGING to true for verbose logging
DEBUG_LOGGING=true


# ================================================================================
# Logging function
debug() {
    if [ "$DEBUG_LOGGING" = true ]; then
        echo "$1"
    fi
}


# ================================================================================
# Functions to authenticate and manage Jamf Pro API bearer tokens
parseBearerToken() {
    # Parse out the token and expiration
    TOKEN=$(echo "$RESPONSE" | jq -r '.token')
    TOKEN_EXPIRATION_ISO=$(echo "$RESPONSE" | jq -r '.expires')
    # Log enough of the token so we can tell what's up, but not the whole thing. 
    TOKEN_TRUNCATED=${TOKEN:0:30}
    debug "BearerToken: TOKEN is now ${TOKEN_TRUNCATED}..."
    # Next, parse out the token expiration
    # macOS's data command doesn't support parsing of zulu and millisecond dates so remove them
    TOKEN_EXPIRATION_TRUNCATED=${TOKEN_EXPIRATION_ISO:0:19}
    # Convert the date (now without milliseconds) to epoch time
    TOKEN_EXPIRATION_EPOCH=$(date -jf "%Y-%m-%dT%H:%M:%S" "${TOKEN_EXPIRATION_TRUNCATED}" +"%s")
    debug "BearerToken: Expiration is now \"${TOKEN_EXPIRATION_EPOCH}\" (${TOKEN_EXPIRATION_TRUNCATED})"
}

getNewBearerToken() {
    TOKEN=""
    TOKEN_EXPIRATION_EPOCH=""
    debug "BearerToken: Requesting a new bearer token"
    local ENDPOINT="${JSS_URL}/api/v1/auth/token"
    local RESPONSE=$(curl \
                        --silent \
                        --show-error \
                        --netrc \
                        --header "Content-Type: application/json" \
                        --request "POST" \
                        --url "${ENDPOINT}")
    parseBearerToken
    debug ""
}

checkBearerToken() {
    # Do the TOKEN and TOKEN_EXPIRATION_EPOCH variables exist and have values? 
    if [ -n "${TOKEN+x}" ] && [ -n "$TOKEN" ] && [ -n "${TOKEN_EXPIRATION_EPOCH+x}" ] && [ -n "$TOKEN_EXPIRATION_EPOCH" ]; then
        debug "BearerToken: We already have a token"
        # Is the token expired? 
        # NOW_EPOCH=$(date -j -f "%Y-%m-%dT%T" "$(date -u +"%Y-%m-%dT%T")" +"%s")
        NOW_EPOCH=$(date -u +"%s")
        debug "NOW_EPOCH:                            ${NOW_EPOCH}"
        debug "TOKEN_EXPIRATION_EPOCH:               ${TOKEN_EXPIRATION_EPOCH}"
        if [[ ${TOKEN_EXPIRATION_EPOCH} -gt ${NOW_EPOCH} ]]; then
            debug "BearerToken: Token has not yet expired"
            FIVE_MINUTES_BEFORE_EXPIRATION_EPOCH=$((TOKEN_EXPIRATION_EPOCH - 300))
            debug "FIVE_MINUTES_BEFORE_EXPIRATION_EPOCH: ${FIVE_MINUTES_BEFORE_EXPIRATION_EPOCH}"
            if [[ ${FIVE_MINUTES_BEFORE_EXPIRATION_EPOCH} -le ${NOW_EPOCH} ]]; then
                debug "BearerToken: The token will expire in the next 5 minutes. Renewing..."
                local ENDPOINT="${JSS_URL}/api/v1/auth/keep-alive"
                local RESPONSE=$(curl  \
                              --silent \
                              --show-error \
                              --header "Authorization: Bearer ${TOKEN}" \
                              --header "Content-Type: application/json" \
                              --url "${ENDPOINT}" \
                              --request 'POST')
                parseBearerToken
                return
            else
                debug "BearerToken: We have a token and it's good for at least another 5 minutes"
                return
            fi
        else
            debug "BearerToken: We have a token but it's expired"
        fi
    else
        debug "BearerToken: We do not yet have a token"
    fi
    # If we got this far we need a new token
    getNewBearerToken
}

invalidateToken() {
    local ENDPOINT="${JSS_URL}/api/v1/auth/invalidate-token"
    curl -H "Authorization: Bearer ${TOKEN}" -X POST -sS -o /dev/null "${ENDPOINT}"
}

# The contents of this if block are only for demonstrating how the token checks work.
# Don't include this in a real script...
if [ "$TEST_MODE" = true ]; then
    echo "Starting Script"

    echo "Test: Getting a fresh bearer token"
    checkBearerToken
    [[ -z ${TOKEN} || -z ${TOKEN_EXPIRATION_EPOCH} ]] && { echo "Failed to get an auth token. Check your url and credentials?"; exit; }
    echo

    echo "Test: Check the token -- we just got it, so it should check out fine"
    checkBearerToken
    [[ -z ${TOKEN} || -z ${TOKEN_EXPIRATION_EPOCH} ]] && { echo "Failed to get an auth token. Check your url and credentials?"; exit; }
    echo

    echo "Test: Pretend Token expires a minute from now (Should renew)"
    NOW_EPOCH=$(date -u +"%s")
    TOKEN_EXPIRATION_EPOCH=$(( NOW_EPOCH + 60 ))
    checkBearerToken
    [[ -z ${TOKEN} || -z ${TOKEN_EXPIRATION_EPOCH} ]] && { echo "Failed to get an auth token. Check your url and credentials?"; exit; }
    echo

    echo "Test: Pretend Token expired a minute ago. (New token needed)"
    NOW_EPOCH=$(date -u +"%s")
    TOKEN_EXPIRATION_EPOCH=$(( NOW_EPOCH - 60 ))
    checkBearerToken
    [[ -z ${TOKEN} || -z ${TOKEN_EXPIRATION_EPOCH} ]] && { echo "Failed to get an auth token. Check your url and credentials?"; exit; }
    echo

    echo "Invalidating token"
    invalidateToken
    echo "Done."
    echo
fi


# ================================================================================
# Function to get the list of mobile device IDs
get_device_ids() {
    local DEVICES_ENDPOINT="${JSS_URL}/JSSResource/mobiledevices"
    DEVICES_RESPONSE=$(curl -sS -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/json" "${DEVICES_ENDPOINT}")
    if [ "$TEST_MODE" = true ]; then
        DEVICE_IDS=$(echo "$DEVICES_RESPONSE" | jq -r '.mobile_devices[] | .id' | head -n 10)
    else
        DEVICE_IDS=$(echo "$DEVICES_RESPONSE" | jq -r '.mobile_devices[] | .id')
    fi
}

# Function to get the site for each device ID
get_sites_for_devices() {
    echo "Count & Site Name"
    echo "================="
    echo "$DEVICE_IDS" | while read -r DEVICE_ID; do
        # We call checkBearerToken inside the loop because it could run long enough to
        #  expire a token if there are tens of thousands of devices.
        # Note the use of " > /dev/null" so that the token logging doesn't get piped 
        #  into the stdout of this function 
        checkBearerToken > /dev/null
        DEVICE_RESPONSE=$(curl -s -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/json" "${JSS_URL}/JSSResource/mobiledevices/id/${DEVICE_ID}")
        SITE_NAME=$(echo "$DEVICE_RESPONSE" | jq -r '.mobile_device.general.site.name')
        echo "${SITE_NAME}"
    done | sort | uniq -c
}


# ================================================================================
# Main execution
getNewBearerToken
if [[ -n "$TOKEN" ]]; then
    START_TIME=$(date +%s.%N) 
    get_device_ids
    get_sites_for_devices
    invalidateToken    
    END_TIME=$(date +%s.%N)
    DURATION=$(echo "$END_TIME - $START_TIME" | bc)
    echo "Script ran for: ${DURATION} seconds"
else
    echo "Failed to authenticate. Check your credentials?"
fi

# Example Output:
# Count & Site Name
# =================
#    2 Education
#    8 None
