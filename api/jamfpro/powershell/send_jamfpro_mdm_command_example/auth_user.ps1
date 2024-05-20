# Setup for authenticating Jamf Pro API calls

# TO-DO:
# More error handling around the API calls, handle http responses gracefully

# Prepare Jamf Pro

# API auth bearer tokens from Jamf Pro gain their permissions from one of two objects... 
# - A Jamf Pro User
# - A Jamf Pro API Client

# This script supports either method. 

# Setup a User or API Client with the permissions needed to support the API endpoints you will call. 
# - For User auth, Go to "Settings > System > Users"
# - For Client Credentials (Application Auth), Go to "Settings > System > API Roles and Clients"

# Permission requirements: 
# https://developer.jamf.com/jamf-pro/docs/classic-api-minimum-required-privileges-and-endpoint-mapping

# Avoid hard-coding secrets in a script. 
# This script gets them from env vars but could be adapted to use a secret store like Azure secrets vault. 
#   For User auth:
#   - $env:JAMF_URL
#   - $env:JAMF_USER
#   - $env:JAMF_PASS 
#   For Client auth:
#   - $env:JAMF_URL
#   - $env:JAMF_CLIENT_ID
#   - $env:JAMF_CLIENT_SECRET


function Get-JamfCredentials_user {
  param ()

  # Read jamf pro api connection info from env vars. 
  # Errors if somethign is not set in env.
  # Returns: Nothing
  # Sets Script-scope vars: 
  #   $credential for use with basic auth, e.g., "-Credential $credential"
  #   $jamfBaseUrl, e.g., $endpoint = "${jamfBaseUrl}/api/version"

  [string] $script:jamfBaseUrl = $env:JAMF_URL
  [string] $apiUser = $env:JAMF_USER
  [string] $apiPass = $env:JAMF_PASS 
  # Write-Log_Debug "$jamfBaseUrl - $apiUser - $apiPass"

  # Make sure the vars have values
  if ([string]::IsNullOrWhiteSpace($jamfBaseUrl) -or
    [string]::IsNullOrWhiteSpace($apiUser) -or
    [string]::IsNullOrWhiteSpace($apiPass)) {
    Write-Error "One or more of the API authentication environment variables is not set."
    exit 1
  }

  $securePassword = ConvertTo-SecureString $apiPass -AsPlainText -Force
  $script:credential = New-Object System.Management.Automation.PSCredential ($apiUser, $securePassword)

  # Less secure, says Microsoft, but you can also make the header yourself...
  $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $apiUser, $apiPass)))
  $script:basicAuthHeaders = @{
    "Authorization" = "Basic $base64AuthInfo"
  }
}


function Test-JamfAuthToken {
  param ()

  # Generate script-scoped $token and $expires vars if they do not yet exist of if the token has expired. 
  # There are lots of approaches to this. We're just going to keep track of the expiration and regenerate 
  # tokens when they near expiration. Other methods might make frequent calls like 
  #   $authTokenData = Invoke-RestMethod -Uri "$jamfBaseUrl/api/v1/auth/keep-alive" -Method Post
  # which is probably more secure and efficient, but maybe too many race conditions for the kinds of API 
  # work we're doing. 
  Write-Log_Debug "START"

  if ($token) {
    Write-Log_Debug "[in] expiration: ${expires}"
    Write-Log_Debug "[in] Time now  : $(Get-Date)"
    # Is the token still going to be good 30 seconds from now? 
    $expired = $expires -le $(Get-Date).AddSeconds(-30)
  } else {
    Write-Log_Debug "Auth token does not yet exist"
    $expired = $true
  }
  Write-Log_Debug "`$expired: $expired"

  if (-not $expired) {
    Write-Log_Debug "[ok] The existing auth header bearer token is still live."
  } else {
    Write-Log_Debug 'Getting new Jamf auth token... '
    if (-not $jamfBaseUrl) {
      # Get secrets needed to get an auth token from Jamf Pro API
      Write-Log_Debug "[Invoke-JamfApiCall] Calling Import-Secrets"
      Get-JamfCredentials_user -ErrorAction Stop
    }

    # $authTokenData = Invoke-RestMethod `
    # -Uri "${jamfBaseUrl}/api/v1/auth/token" `
    # -Headers $basicAuthHeaders `
    # -Method Post `
    # -StatusCodeVariable token_http_code

    # Write-Host "jamfBaseUrl: ${jamfBaseUrl}"
    $tokenEndpoint = "${jamfBaseUrl}/api/v1/auth/token"
    # Write-Host "tokenEndpoint: ${tokenEndpoint}"
    # Write-Host "credential: ${credential}"

    $authTokenData = Invoke-RestMethod `
    -Uri $tokenEndpoint `
    -Authentication Basic `
    -Credential $credential `
    -Method Post `
    -StatusCodeVariable token_http_code

    Write-Debug "token_http_code: ${token_http_code}"
    # Write-Debug "authTokenData: ${authTokenData}"

    Write-Log_Debug "We have updated token information to add to the headers on our jamf API calls"
    $tokenString = $authTokenData.token
    $script:token = ConvertTo-SecureString -String $tokenString -AsPlainText -Force
    $script:expires = (Get-Date "$($authTokenData.expires)").ToLocalTime()
  }

  Write-Log_Debug "[out] token: $($tokenString.Substring(0, [Math]::Min($tokenString.Length, 20)))..."
  Write-Log_Debug "[out] expiration: $expires"
  Write-Log_Debug "END"
}


function Invoke-JamfApiCall {
  param (
    [ValidateSet("GET", "POST", "PATCH")][string]$method = "GET",
    [string]$endpoint,
    [PSCustomObject]$data = $null
  )

  Write-Log_Debug "START"
  Test-JamfAuthToken
  $url = "${jamfBaseUrl}${endpoint}"
  Write-Log_Debug "Calling Invoke-RestMethod: ${method} ${url}"
  $headers = @{
    "Accept" = "application/json"
  }

    # -WebSession $session `
    function Invoke-Invoke-RestMethod {
    $mymyResponse = Invoke-RestMethod `
    -Uri $url `
    -Headers $headers `
    -Method $method `
    -StatusCodeVariable mymyHttpStatus `
    -Authentication Bearer `
    -Token $token `
    -SessionVariable $script:session`
    -UserAgent $userAgent `
    -ErrorAction Stop
    return $mymyHttpStatus, $mymyResponse
  }

  $myHttpStatus, $myResponse = Invoke-Invoke-RestMethod
  Write-Log_Debug "HTTP StatusCode: ${httpStatus}"

  # Check if the response is 401 Unauthorized
  if ($httpStatus -eq 401) {
      # Maybe the token was just on the verge of expiring when we checked. Refresh and try one more time.
      Write-Log_Debug "[Invoke-JamfApiCall] Invoke-Invoke_RestMethod returned a 401 Unauthorized"
      Test-JamfAuthToken
      $myHttpStatus, $myResponse = Invoke-Invoke-RestMethod
      if ($httpStatus -eq 401) {
          Write-Error "Second attempt with refreshed headers also returned 401 Unauthorized. Exiting script."
          Exit 1
      }
      return $myHttpStatus, $myResponse
  }
  Write-Log_Debug "[Invoke-JamfApiCall] END"
  return $myHttpStatus, $myResponse
}

$userAgent = "auth_user.1.0 (Powershell Script)"
[System.Security.SecureString] $token = $null
[datetime] $expires = [DateTime]::MinValue

# invalidateToken() {
# 	responseCode=$(curl -w "%{http_code}" -H "Authorization: Bearer ${access_token}" $url/api/v1/auth/invalidate-token -X POST -s -o /dev/null)
# 	if [[ ${responseCode} == 204 ]]
# 	then
# 		echo "Token successfully invalidated"
# 		access_token=""
# 		token_expiration_epoch="0"
# 	elif [[ ${responseCode} == 401 ]]
# 	then
# 		echo "Token already invalid"
# 	else
# 		echo "An unknown error occurred invalidating the token"
# 	fi
# }

# invalidateToken
# curl -H "Authorization: Bearer $access_token" $url/api/v1/jamf-pro-version -X GET

# Jamf-developed portions are Copyright 2023, Jamf Software, LLC. 
# Jamf customers are free to adapt this to their own needs. 

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
