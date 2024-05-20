# Given a list of users, finds their mobile devices and places them into a Jamf Pro static group. 
# This might be useful for creating a test group to test something new, or a group
#  that needs a specialized app or restriction set, or to decommission devices for 
#  a group that is leaving the organization. 
# 
# The new static group will be named to indicate it was created by this script and will include 
# the current date time. You can rename the group in Jamf Pro, like, "Graduating Sept 2024" or 
# "Outlook Test Group".
# 
# Accepts a string (the username)...
#   powershell -File "Path\to\ThisScript.ps1" -Users "p.chen@my.org"
# Or an array of usernames...
#   powershell -File "Path\to\ThisScript.ps1" -Users "jose@my.org", "jamal@my.org", "aisha@my.org"
# 
# In the above examples, we've used UPN-format usernames, but the format you'll send needs to match 
# the usernames on assigned devices in Jamf Pro, which might be a different format, such as 
# short or long name, like jjones or jamal.jones. 
# 
# You can also provide a path to a text file with one username per line...
#   powershell -File "Path\to\ThisScript.ps1" -UserListFilePath "C:\Users\ssmith\Desktop\Class of 2028.txt"

# API Privilege Requirements: 
# - Create Static Mobile Device Groups
# - Read Users


# param (
#   [ValidateNotNullOrEmpty()]$Users = $(throw "This script requires a -Users parameter.")
# )


$Users = 'jorge.ramirez@my.org'

# param (
#     [Parameter(Mandatory = $true, ParameterSetName = 'UserList')][string[]]$Users
# )
# ,
# [Parameter(Mandatory = $true, ParameterSetName = 'FilePath')][string]$UserListFilePath


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

    $userMobileDeviceIDs = Get-DeviceIDs $userDetails.user.links.mobile_devices
    Write-Log_Debug "userMobileDeviceIDs: $userMobileDeviceIDs"
    Write-Log_Debug "[end] Get-JamfDeviceIDsForUser"
    return , $userMobileDeviceIDs  # Return arrays as output
  } else {
    Write-Log_Warning "User '$UserToQuery' not found."
    Write-Log_Debug "[end] Get-JamfDeviceIDsForUser"
    return $null
  }
}

function New-StaticGroup() {
  param(
    [Parameter(Mandatory=$true)][int]$deviceIDs
  )

  myFunctionName = & { $MyInvocation.MyCommand.Name }
  Write-Log_Info "[${myFunctionName}] START"
  $timeStamp = Get-Date -Format "yyyy-MM-dd HH-mm:ss"
  $groupName = "Created via script ${timeStamp}"

  Write-Log_Info "[${myFunctionName}] Creating a ${deviceType} static group called ${staticGroupName}"    
  # Construct the post data object
  $payload = @{
    "groupName" = $groupName
    "assignments" = @()
  }
  foreach ($deviceId in $deviceIDs) {
    # Add each mobileDeviceId to the 'assignments' array
    $assignment = @{
      "mobileDeviceId" = $deviceId.ToString()
      "selected" = $true
    }
    $payload.assignments += $assignment
  }
  Write-Log_Debug "payload: $($payload | ConvertTo-Json)"
  $apiEndpoint = "/api/v1/mobile-device-groups/static-groups"
  Write-Log_Debug "Sending request to apiEndpoint: ${apiEndpoint}"

  # --header 'accept: application/json' \
  # --header 'content-type: application/json' \

  $responseData, $httpStatus = Invoke-JamfApiCall -method "POST" -endpoint $apiEndpoint -data $payload
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
$logLevel = "Debug"
$logLevel = $logLevel
. "$PSScriptRoot/logging.ps1"
. "$PSScriptRoot/auth_user.ps1"

Write-Log_Info "[script] START"

# Check if the input is a string, if so, convert it to an array with a single item
if (-not $Users -is [System.Array]) {
  $Users = @($Users)
}

Write-Log_Info "[step] Looping throught the list of users"
$allUserMobileIDs = @()

foreach ($userToQuery in $Users) {
  Write-Log_Info "[user] Getting device IDs for user `"${userToQuery}`""
  $userMobileDeviceIDs = $null
  $userMobileDeviceIDs = Get-JamfDeviceIDsForUser -UserToQuery "$userToQuery"  # -ErrorAction Stop
  if (-not ($userComputerIDs -or $userMobileDeviceIDs)) {
    # Both the computer and mobile lists are null
    Write-Log_Warning "[user] This user has no devices enrolled. Was that expected?"
  } else {
    if ($null -ne $userComputerIDs) {
      Write-Log_Info "[user] Computer ID(s): $userComputerIDs"
      $allUserComputerIDs += @($userComputerIDs)
    } else {
      Write-Log_Debug "[user] No computer IDs found for this user."
    }
    if ($null -ne $userMobileDeviceIDs) {
      Write-Log_Info "[user] Mobile Device ID(s): $userMobileDeviceIDs"
      $allUserMobileIDs += @($userMobileDeviceIDs)
    } else {
      Write-Log_Debug "[user] No mobile device IDs were found for this user."
    }
  }
}


Write-Log_Info "[script] END`n"





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