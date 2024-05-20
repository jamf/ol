# Requests Apple MDM device managaement unenroll command for all devices assigned to a specified
# user, or a list of users. Could be used when a userid is disabled in a directory, or when a batch 
# of students is graduating and taking their devices with them. 

# This only unenrolls the devices from Jamf. There's no API for disowning in Apple Business/School Manager. 

# Accepts a string (the username)...
#   powershell -File "Path\to\ThisScript.ps1" -Users "chen@my.org"
# Or an array of usernames...
#   powershell -File "Path\to\ThisScript.ps1" -Users "jose@my.org", "jamal@my.org", "aisha@my.org"

# In these examples, we've used UPN-format usernames, but the format you'll send needs to match 
# the usernames on assigned devices in Jamf Pro, which might be a different format, such as 
# short or long name, like jjones or jamal.jones. 

# TO-DO:
# More error handling around the API calls, handle http responses gracefully
# Option to read the usernames from a text/csv file?
# Better speed with Sessions on invoke-restmethod to re-use keep-alive connections?
# Safer to send auth as -token <secure-string> instead of hashtable? 
# Extension attribute to note the date unenrolled and an advanced search to list batch devices

# API Privilege Requirements: 
#  - Read User (to look up users and get a list of their devices)
#  - Permission to send the desired MDM commands. 
#    For example, if you want to wipe both iOS and macOS devices: 
#    - Send Computer Remote Wipe Command
#    - Send Mobile Device Remote Wipe Command

# (!) WARNING: -------------------------------------------------------
# Automation of commands like remote wipe deserves extensive testing. 
# Think hard about the supply chain that supplies the username inputs. 
# Is there a human in your process to act as a sanity check? 
# --------------------------------------------------------------------


param (
  [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Users
)


function Get-JamfDeviceIDsForUser {
  param (
    [string]$UserToQuery
  )

  Write-Log_Debug "[start] Get-JamfDeviceIDsForUser"
  # Sub-function to extract device IDs
  function Get-DeviceIDs($deviceList) {
    $deviceIDs = @()
    if ($deviceList -is [System.Array]) {
      foreach ($device in $deviceList) {
          $deviceIDs += $device.id
      }
    } else {
      $deviceIDs += $deviceList.id
    }
    return $deviceIDs
  }
  # API endpoint to get user details by name
  Write-Log_Debug "[step] Calling Jamf Pro API to get user details"
  $encodedUserToQuery = [System.Web.HttpUtility]::UrlEncode($UserToQuery)

  $apiEndpoint = "/JSSResource/users/name/${encodedUserToQuery}"
  Write-Log_Debug "[info] apiEndpoint: ${apiEndpoint}"

  # try {
  #   # Make the API request to retrieve user details
  #   # $userDetails = Invoke-RestMethod -Uri $apiEndpoint -Headers $JamfApiHeaders -Method Get -StatusCodeVariable responseCode
  #   $userDetails = Invoke-JamfApiCall -endpoint $apiEndpoint -ErrorAction Stop
  # } catch {
  #   # to-do need some selectivity here. 404 we can just log. 401 would need to terminate. 
  #   Write-Warning "An error occurred while fetching user details: $_"
  #   exit 1  # Terminate the script with an exit code indicating an error
  # }

  $userDetails, $httpStatus = Invoke-JamfApiCall -endpoint $apiEndpoint
  Write-Log_Debug "`$httpStatus: ${httpStatus}"
  # Check for errors
  if ($httpStatus -eq 200) {  # Check for successful status code (200 OK)
    # Check if the response is null or the content is null/empty
    if ($null -eq $userDetails) {
      Write-Log_Error "Response object is null."
      exit 1
    }
  } else {
    Write-Log_Debug "Non-successful status code: ${httpStatus} - ${userDetails}"
    # to-do: should log 404s and move on. 
    exit 1
  }

  # Check if user was found
  if ($userDetails -and $userDetails.user -and $userDetails.user.links) {

    # remove some un-needed data. This serves no functional purpose, just doing it so we don't log the extras. 
    $propertiesToRemove_user = @("ldap_server", "extension_attributes", "sites", "user_groups", "full_name", "email", "email_address", "phone_number", "position")
    $propertiesToRemove_user | ForEach-Object { $userDetails.user.PSObject.Properties.Remove($_) }
    $propertiesToRemove_links = @("peripherals", "vpp_assignments", "sites", "total_vpp_code_count")
    $propertiesToRemove_links | ForEach-Object { $userDetails.user.links.PSObject.Properties.Remove($_) }
    Write-Log_Debug "`$userDetails:"
    Write-Log_Debug ($userDetails | ConvertTo-Json -Depth 3 -ErrorAction SilentlyContinue)

    # Process the user's devices
    Write-Log_Debug "Extracting computer and mobile device IDs from the user details"

    $computerIDs = Get-DeviceIDs $userDetails.user.links.computers
    $mobileDeviceIDs = Get-DeviceIDs $userDetails.user.links.mobile_devices
    Write-Log_Debug "computerIDs: $computerIDs"
    Write-Log_Debug "mobileDeviceIDs: $mobileDeviceIDs"
    Write-Log_Debug "[end] Get-JamfDeviceIDsForUser"
    return ,$computerIDs, $mobileDeviceIDs  # Return arrays as output
  } else {
    Write-Log_Warning "User '$UserToQuery' not found."
    Write-Log_Debug "[end] Get-JamfDeviceIDsForUser"
    return $null
  }
}

function Send-MdmCommand() {
  param(
    [Parameter(Mandatory=$true)][ValidateSet("computer", "mobile")][string]$deviceType,
    [Parameter(Mandatory=$true)][int]$deviceId,
    [Parameter(Mandatory=$true)][ValidateSet("wipe")][string]$command
  )
  Write-Log_Info "[Send-MdmCommand] START"
  Write-Log_Info "[Send-MdmCommand] Sending ${command} MDM Command to ${deviceType} ID ${deviceId}"

  switch ($deviceType) {
    "computer" {
      switch ($command) {
        "wipe" {
          $apiEndpoint = "/JSSResource/computercommands/command/unmanageDevice/id/${deviceId}"
        }
        Default {Write-Log_Error "[Send-MdmCommand] Unsupported command"}
      }    
    }
    "mobile" {
      switch ($command) {
        "wipe" {
          $apiEndpoint = "/JSSResource/mobiledevicecommands/command/unmanageDevice/id/${deviceId}"
        }
        Default {Write-Log_Error "[Send-MdmCommand] Unsupported command"}
      }    
    }
    Default {Write-Log_Error "[Send-MdmCommand] invalid device type"}
  }    
  Write-Log_Debug "Sending request to apiEndpoint: ${apiEndpoint}"
  #   Uncomment the Invoke-RestMethod once you've tested everything else to see the actual wipe commands go out. 
  #   You could test with another less destructive command as well, like remote lock, for example. 
  # $mdmCommandResponse = Invoke-RestMethod -Uri $apiEndpoint -Headers $JamfApiHeaders -Method Post -StatusCodeVariable httpStatus
  $responseData, $httpStatus = Invoke-JamfApiCall -method "POST" -endpoint $apiEndpoint
  $responseText = $responseData.InnerXml
  Write-Log_Info "responseData: ${responseText} (${httpStatus})"
  Write-Log_Debug "[Send-MdmCommand] END"
}

# ####################################################################
# ##                        END FUNCTIONS 
# ####################################################################
 

# ####################################################################
# ##                            MAIN 
# ####################################################################
$ErrorActionPreference = "Stop"
$DebugPreference = "Continue"
$WarningPreference = 'Continue'
$InformationPreference = 'Continue'

# Dot-source some useful functions...
. "$PSScriptRoot/logging.ps1"
. "$PSScriptRoot/auth_client.ps1"

Write-Log_Info "[unenroll_user_devices_clientauth] START`n"

# Check if the input is a string, if so, convert it to an array with a single item
if (-not $Users -is [System.Array]) {
  $Users = @($Users)
}

Write-Log_Info "[step] Looping throught the list of users"
foreach ($userToQuery in $Users) {
  Write-Log_Info "[user] Getting device IDs for user `"${userToQuery}`""
  $computerIDs, $mobileDeviceIDs = $null
  $computerIDs, $mobileDeviceIDs = Get-JamfDeviceIDsForUser -UserToQuery "$userToQuery"  # -ErrorAction Stop
  if (-not ($computerIDs -or $mobileDeviceIDs)) {
    # Both the computer and mobile lists are null
    Write-Log_Warning "[user] This user has no devices enrolled. Was that expected?"
  } else {
    if ($null -ne $computerIDs) {
      Write-Log_Info "[user] Computer ID(s): $computerIDs"
      foreach ($computerID in $computerIDs) {
        Send-MdmCommand -deviceType "computer" -deviceId $computerID -command "wipe"
      }
    } else {
      Write-Log_Debug "[user] No computer IDs found for this user."
    }
    if ($null -ne $mobileDeviceIDs) {
      Write-Log_Info "[user] Mobile Device ID(s): $mobileDeviceIDs"
      foreach ($mobileID in $mobileDeviceIDs) {
        Send-MdmCommand -deviceType "mobile" -deviceId $mobileID -command "wipe"
      }
    } else {
      Write-Log_Debug "[user] No mobile device IDs were found for this user."
    }
  }
}

Write-Log_Info "[unenroll_user_devices_clientauth] END`n"




# Copyright 2023, Jamf Software, LLC. 
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