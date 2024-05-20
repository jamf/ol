# Setup for authenticating Jamf Pro API calls

# TO-DO:
# More error handling around the API calls, handle http responses gracefully

# Prepare Jamf Pro

# API auth bearer tokens from Jamf Pro can gain their permissions from a Jamf Pro API Client

# Setup a User or API Client with the permissions needed to support the API endpoints you will call. 
# Go to "Settings > System > API Roles and Clients"

# Permission requirements: 
# https://developer.jamf.com/jamf-pro/docs/classic-api-minimum-required-privileges-and-endpoint-mapping

# Avoid hard-coding secrets in a script. 
# This script gets them from env vars but could be adapted to use a secret store like Azure secrets vault. 
#   - $env:JAMF_URL
#   - $env:JAMF_CLIENT_ID
#   - $env:JAMF_CLIENT_SECRET


function Import-Secrets {
  param ()

  Write-Log_Debug "[Import-Secrets] START"

  $jamfUrl = $env:JAMF_URL
  $clientID = $env:JAMF_CLIENT_ID
  $clientSecret = $env:JAMF_CLIENT_SECRET 

  if ([string]::IsNullOrWhiteSpace($jamfUrl) -or
      [string]::IsNullOrWhiteSpace($clientID) -or
      [string]::IsNullOrWhiteSpace($clientSecret)) {
      Write-Error "One or more of the API authentication environment variables is not set."
      return
  }
  Write-Log_Debug "[Import-Secrets][out] clientID: $($clientID.Substring(0, [Math]::Min($clientID.Length, 10)))..."
  Write-Log_Debug "[Import-Secrets][out] clientSecret: $($clientSecret.Substring(0, [Math]::Min($clientSecret.Length, 10)))..."
  Write-Log_Debug "[Import-Secrets] END"
  return $jamfUrl, $clientID, $clientSecret
}


function Update-Token {
  param ()
  # These vars are set at the script level
  # param (
  #   [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$jamfUrl,
  #   [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$clientId,
  #   [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$clientSecret,
  #   [Microsoft.PowerShell.Commands.WebRequestSession]$session = (New-Object Microsoft.PowerShell.Commands.WebRequestSession)
  # )

  # There are a lot of methods for managing jwt expiration, including watching the 
  # expiration time, but these can lead to race conditions with short-lived jwt's 
  # in long-running scripts. In this example, we just update the token whenever we get 
  # a 401 back from an API call. This may or may not be the most efficient, but it's 
  # pretty simple and reliable. 

  Write-Log_Debug "[Update-Token] START"  

  $encodedClientId = [System.Web.HttpUtility]::UrlEncode($clientId)
  $encodedClientSecret = [System.Web.HttpUtility]::UrlEncode($clientSecret)

  # $formData = @{
  #   "grant_type" = "client_credentials"
  #   "client_id" = ${clientId}
  #   "client_secret" = ${clientSecret}
  # }

  $body = "grant_type=client_credentials&client_id=${encodedClientId}&client_secret=${encodedClientSecret}"
  # Write-Log_Debug "body $body"
  # -Body "grant_type=client_credentials&client_id=${clientId}&client_secret=$clientSecret" `
  # -Form $formData `

  $headers = @{
    "Content-Type" = "application/x-www-form-urlencoded"
  }

  $response = Invoke-RestMethod `
  -Uri "${jamfUrl}/api/oauth/token" `
  -Method Post `
  -Headers $headers `
  -Body $body `
  -WebSession $script:session `
  -UserAgent "auth_client.ps1/1.0 (Powershell script)" `
  -StatusCodeVariable httpStatus

  # Write-Log_Debug $httpStatus
  # Write-Log_Debug $response

  if ($httpStatus -ne 200) {
    Write-Log_Error "HTTP Status: ${httpStatus}"
    Write-Log_Debug "[Update-Token] ABEND"  
    return
  } else {
    $tokenString = $response.access_token
    $script:token = ConvertTo-SecureString -String $tokenString -AsPlainText -Force

    $timeNow = Get-Date
    $expiresInSeconds = $response.expires_in
    $script:expires = $timeNow.AddSeconds($expiresInSeconds)
    
    if (-not $token -or -not $expires) {
      Write-Log_Error "Could not parse a token from oAuth token request. (${status}) $response"
      Write-Log_Debug "[Update-Token] ABEND"  
      return
    }
    Write-Log_Debug "[Update-Token] (out) token: $($tokenString.Substring(0, [Math]::Min($token.Length, 20)))..."
    Write-Log_Debug "[Update-Token] Token scope: $($response.scope)"
    Write-Log_Debug "[Update-Token] (out) expires: ${expires} ($expiresInSeconds seconds from now)"
    Write-Log_Debug "[Update-Token] END"  
  }
}


function Invoke-JamfApiCall {
  param (
    [ValidateSet("GET", "POST", "PATCH")][string]$method = "GET",
    [string]$endpoint,
    [PSCustomObject]$data = $null
  )

  Write-Log_Debug "[Invoke-JamfApiCall] START"

  if (-not $jamfUrl -or -not $clientId -or -not $clientSecret) {
    # Get secrets needed to get an auth token from Jamf Pro API
    Write-Log_Debug "[Invoke-JamfApiCall] Calling Import-Secrets"
    $script:jamfUrl, $script:clientId, $script:clientSecret = Import-Secrets -ErrorAction Stop
  }

  $url = "${jamfUrl}${endpoint}"

  function Update-MyToken {
    param ()
    Write-Log_Debug "[Invoke-JamfApiCall][Update-MyToken] START"
    Update-Token -jamfUrl $jamfUrl -clientId $clientId -clientSecret "${clientSecret}"    
    Write-Log_Debug "[Invoke-JamfApiCall][Update-MyToken] END"
  }

  if ($null -eq $token) {
    # Get an auth token
    Write-Log_Debug "[Invoke-JamfApiCall] No auth token. Calling Update-MyToken"
    Update-MyToken -ErrorAction Stop
  }

  if ((Get-Date) -gt $expires.AddSeconds(10)) {
    # If the current time is beyond the token expiration (plus some padding)...
    Write-Log_Debug "[Invoke-JamfApiCall] Expired/expiring auth token. Calling Update-MyToken"
    Update-MyToken -ErrorAction Stop
  }

  function Invoke-Invoke_RestMethod {
    param (
      [ValidateSet("GET", "POST", "PATCH")][string]$method = "GET",
      [string]$url,
      [PSCustomObject]$data = $null
    )

    Write-Log_Debug "[Invoke-JamfApiCall][Invoke-Invoke_RestMethod] START"
    Write-Log_Debug "[Invoke-JamfApiCall][Invoke-Invoke_RestMethod] Invoke-RestMethod: ${method} ${url}"
    $headers = @{
      "Accept" = "application/json"
    }
    $response = Invoke-RestMethod `
    -Uri $url `
    -Headers $headers `
    -Method $method `
    -StatusCodeVariable httpStatus `
    -Authentication Bearer `
    -Token $token `
    -SessionVariable $script:session`
    -WebSession $session `
    -UserAgent $userAgent `
    -ErrorAction Stop

    Write-Log_Debug "[Invoke-JamfApiCall][Invoke-Invoke_RestMethod] HTTP StatusCode: ${httpStatus}"
    Write-Log_Debug "[Invoke-JamfApiCall][Invoke-Invoke_RestMethod] END"
    return $response, $httpStatus
  }

  Write-Log_Debug "[Invoke-JamfApiCall] Calling Invoke-Invoke_RestMethod"
  $response, $httpStatus = Invoke-Invoke_RestMethod -method $method -url $url
  # Write-Log_Debug "HTTP Response: ${response}"
  Write-Log_Debug "HTTP StatusCode: ${httpStatus}"

  # Check if the response is 401 Unauthorized
  if ($httpStatus -eq 401) {
      # Maybe the token was just on the verge of expiring when we checked. Refresh and try again. 
      Write-Log_Debug "[Invoke-JamfApiCall] Invoke-Invoke_RestMethod returned a 401 Unauthorized"
      Update-MyToken -ErrorAction Stop
      # Retry the API call with the new headers
      $response, $httpStatus = Invoke-Invoke_RestMethod -url $url
      if ($httpStatus -eq 401) {
          Write-Error "Second attempt with refreshed headers also returned 401 Unauthorized. Exiting script."
          Exit 1
      }
      return $retryResponse, $httpStatus
  }

  Write-Log_Debug "[Invoke-JamfApiCall] END"
  return $response, $httpStatus
}


$userAgent = "auth_client.1.0 (Powershell Script)"
[System.Security.SecureString] $token = $null
[datetime] $expires = [DateTime]::MinValue
[string] $jamfUrl = $null
[string] $clientID = $null
[string] $clientSecret = $null


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
