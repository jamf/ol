# Script to pull down the output of a pre-created Jamf Pro Advanced Search as XML,
# then output it as text or csv file saved to disk. 
# ol/jamf 2018-09-10

# In this example, we have already created a mobile device advanced search
# called "ManagedDeviceActiveSyncIDs" and added the following display fields:

# Serial_Number
# Exchange Device ID
# DistinguishedName_LDAP_attribute
# targetAddress_LDAP_attribute

# The first two fields are built-in values, and the second two are mobile device extension attributes

# Security:
# - Do not use a Jamf API account with any write permissions -- this is just an export so you only need read access.
# - Do not save a plaintext password in an insecure place. You could update this script to prompt for passwords like this...
#   $pass_Secure = Read-host "Please enter the password for `"$user`"." -AsSecureString
#   $pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass_Secure))
#   ...or if you aren't running interactive, you can read the password in from an environment variable. 


# Settings...

$ErrorActionPreference = "Stop"

# Near the end of this script, there are some extension attribute fields 
# that we extract from the report by name. Since these are not standard Jamf
# Pro field names, you'll need to remove them, or change them to attribute 
# names that exist in your Jamf Pro and you've included in your advanced search. 
# - Exchange_Device_ID
# - DistinguishedName_LDAP_attribute
# - targetAddress_LDAP_attribute

$printDebugInfo = $false   # $true or $false

# Settings for connection to JSS and pulling reports: 
# You can pull just one report from one server or export data from multiple
# reports/servers and the script will concatenate them for output. 
# Set the user, password, and Jamf Pro URL(s) to reflect your requirements... 


#This example shows how we would export a report for a single server...
$user = 'api_read_only_service_account'
$pass = 'password'
$URL  = 'https://j.jamf.club:8443'
$Rprt = 'ManagedDeviceActiveSyncIDs'

#
# code...
#

function Write-Debug {
  param (
    [string]$msg
  )
  if ($printDebugInfo) {
    Write-Host $msg
  }
}

Write-Debug "[info] Reading Security Protocol before setting to TLS 12: "
$tlsVersion = [System.Net.ServicePointManager]::SecurityProtocol
if ( $tlsVersion -eq 'Tls12') {
  Write-Debug -msg 'TLS 1.2 is already available' 
}else{
  Write-Host "TLS is $tlsVersion -- Setting v1.2..."
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Write-Host -NoNewline "[info] Reading Security Protocol after setting to TLS 12: "
  [System.Net.ServicePointManager]::SecurityProtocol
}

$reportLines_obj = @()    # Any report lines will be accumulated in this object...
Write-Host "[step] Retrieving data from server"
$LookupURL = "${URL}/JSSResource/advancedmobiledevicesearches/name/${Rprt}"

Write-Host "> Connecting to ${LookupURL}"
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)

try {
  $response = Invoke-RestMethod -URI "${LookupURL}" -Credential $credential -Method Get -Headers @{"accept"="application/xml"}
  Write-Host "[status] OK"
} catch {
  $_.Exception | Format-List -Force
  # Write-Host "[Error] an error occurred."
  # Write-Host "$error[0]"

  # Dig into the exception to get the Response details.
  # (the double _ on value__ is intentional.)
  Write-Host "[Error]HTTP Status Code:" $_.Exception.Response.StatusCode.value__
  Write-Host "[Error]HTTP Status Description:" $_.Exception.Response.StatusDescription
  # If you want to show the html-formatted error message returned by the API, you could do this...
  # (Invoke-WebRequest -URI "${LookupURL}" -Credential $credential -UseBasicParsing).Content
  exit
}

# Write-Debug "--"
# Write-Debug "[debug] Raw API Query Response:"
# Write-Debug $response.OuterXml
# Write-Debug "--"
# return

Write-Host "Converting API response to PS XML object"
try {
    $xml = ([xml]($response)).advanced_mobile_device_search.mobile_devices
    Write-Host "[status] OK"
  } catch {
    # Discovering the full type name of an exception
    Write-Host "[Error]" $_.Exception.gettype().fullName
    Write-Host "[Error]" $_.Exception.message
    return
}

Write-Debug "[debug] The device node XML:"
Write-Debug '--'
Write-Debug $xml.OuterXml
Write-Debug '--'
Write-Debug $xml2.OuterXml
Write-Debug '--'

Write-Host "Extracting data from XML"
$nodes = $xml.ChildNodes
foreach ($node in $nodes) {
  $ActiveSyncID = $node.Exchange_Device_ID
  if ( $ActiveSyncID ) {
    $DN = $node.DistinguishedName_LDAP_attribute
    $targetAddr = $node.targetAddress_LDAP_attribute
    $serialNumber = $node.Serial_Number
    $reportLine_obj = [pscustomobject] [ordered] @{ActiveSyncID=$ActiveSyncID;DN=$DN;targetAddr=$targetAddr;serialNumber=$serialNumber}
    $reportLines_obj += $reportLine_obj  # Concatenate with accumulator object. 
  }
}

# ...Export to Excel/CSV:
$TargetDir = "$HOME/Desktop"
Set-Location "$TargetDir"
$dateTimeStamp = Get-Date -Format "yyyyMMdd_HHmm"
$TargetFilePath = "${TargetDir}/${Rprt} - Jamf Pro Report - Exported ${dateTimeStamp}.csv" 
$reportLines_obj | Export-Csv -Path "$TargetFilePath"
Write-Host ""
# Write-Host "Results saved to"(Get-Location | Select-Object -ExpandProperty 'Path')
Write-Host "Results saved to $TargetDir"

# You can write the results to screen too if you want... 
# Write-Host ""
# $reportLines_obj | Out-GridView


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