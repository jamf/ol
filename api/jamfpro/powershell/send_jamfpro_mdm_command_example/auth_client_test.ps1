. ./auth_client.ps1

# Script was not dot-sourced by another script. Run some tests. 
Write-Log_Debug "[auth_client] Running __Main__"
. "./Logging.ps1"

Write-Log_Info "[TEST] See if we can make an API call"
$response = Invoke-JamfApiCall -method GET -endpoint "/api/v1/jamf-pro-version"
if ($response.version.StartsWith("11.")) {
  Write-Host "[ok] The 'version' attribute starts with '11.'"
} else {
  Write-Host "[fail] The 'version' attribute does not start with '11.'"
}
# $jamfUrl, $clientId, $clientSecret = Import-Secrets -ErrorAction Stop

function Test-ErrorExpected {
  param (
    [Parameter(Mandatory=$true)][string]$expectedErrorString
  )
  try {
    Invoke-JamfApiCall -method GET -endpoint "/api/v1/jamf-pro-version"
    Write-Error "[Fail] The expected error did not occur. Ending the script."
    # exit 0  # Exit the script with a success code (0)
  } catch {
    if ($_.Exception.Message.Contains($expectedErrorString)) {
      Write-Host "[OK] Error is as expected: $($_.Exception.Message)"
    } else {
      throw "[Fail] Unexpected error occurred. $($_.Exception.Message)"
    }
  }  
}

Write-Log_Info "[TEST] Test error handling for a malformed JSS base URL"
$jamfUrl_Correct = $jamfUrl
$jamfUrl = $jamfUrl_Correct.Substring(1)  # removes the h from http://
Test-ErrorExpected -expectedErrorString "The 'ttps' scheme is not supported."
$jamfUrl = $jamfUrl_Correct

Write-Log_Info "[TEST] Test error handling for a bad hostname"
$jamfUrl = $jamfUrl_Correct.Substring(0, ($jamfUrl_Correct.Length - 4)) # strip off the ".com"
Test-ErrorExpected -expectedErrorString "nodename nor servname provided, or not known"
$jamfUrl = $jamfUrl_Correct  # put the url back the way it was before we messed with it. 

Write-Log_Info "[TEST] Bad CLIENT_ID"
$clientID_correct = $clientID
$clientID = "badclient"
# JSON will be {"error": "invalid_client"}
Test-ErrorExpected -expectedErrorString "Response status code does not indicate success: 401"
$clientID = $clientID_correct # put it back the way it was

Write-Log_Info "[TEST] Bad CLIENT_SECRET"
$clientSecret_correct = $clientSecret
$clientSecret = "badsecret"
Test-ErrorExpected -expectedErrorString "Response status code does not indicate success: 401"
$clientSecret = $clientSecret_correct  # put it back the way it was

Write-Log_Info "[TEST] Auth token doesn't seem to have expired but it has."
Write-Log_Info "Should get a 401, then refresh the token, then succeed on re-attempt."
$token = $null
Write-Debug $token
$response = Invoke-JamfApiCall -method GET -endpoint "/api/v1/jamf-pro-version"
if ($response.version.StartsWith("11.")) {
  Write-Host "[ok] The 'version' attribute starts with '11.'"
} else {
  Write-Host "[fail] The 'version' attribute does not start with '11.'"
}

Write-Log_Info "[TEST] Auth token has expired"
Write-Log_Info "Should refresh before the API call is attempted"
$expires = Get-Date
Write-Debug $expires
$response = Invoke-JamfApiCall -method GET -endpoint "/api/v1/jamf-pro-version"
if ($response.version.StartsWith("11.")) {
  Write-Host "[ok] The 'version' attribute starts with '11.'"
} else {
  Write-Host "[fail] The 'version' attribute does not start with '11.'"
}




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
