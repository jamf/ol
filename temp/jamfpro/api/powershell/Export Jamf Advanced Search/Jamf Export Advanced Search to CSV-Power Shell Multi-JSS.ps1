# Script to pull down the output of a pre-created Jamf Pro Advanced Search as XML,
# then output it as text or csv file saved to disk. 
# ol/jamf 2018-09-10

# Security:
# - Do not use a Jamf API account with any write permissions -- this is just an export so you only need read access.
# - Do not save a plaintext password in an insecure place.
# - You could update this script to prompt for passwords like this...
#   $pass_Secure = Read-host "Please enter the password for `"$user`"." -AsSecureString
#   $pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass_Secure))
#   Or you can read the password in from an environment variable. 


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

#This example shows how we would add multiple servers/report to a single export...
#[string[]] $user_a = 'user','user2'   
#[string[]] $pass_a = 'pass','pass2'   
#[string[]] $URL_a  = 'https://my.jamfcloud.com','https://my2.jamfcloud.com'
#[string[]] $Rprt_a = 'ManagedDeviceActiveSyncIDs','ManagedDeviceActiveSyncIDs'

#This example shows how we would export a report for a single server...
[string[]] $user_a = 'api'
[string[]] $pass_a = 'a good password'
[string[]] $URL_a  = 'https://my.jamfcloud.com'
[string[]] $Rprt_a = 'ManagedDeviceActiveSyncIDs'

# Some reports, like a list of every enrolled device, might be too much to export. 
# So you might add a criteria like "Show me everything that's enrolled in the last week"
#  and merge it into a master list that you already have. 
$mergeWithMasterFile=$true

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
for ($i=0; $i -lt $user_a.length; $i++) {
  Write-Host "[step] Retrieving data from server/report number $i"
  $user = $user_a[$i]
  $pass = $pass_a[$i]
  $URL  = $URL_a[$i]
  $Rprt = $Rprt_a[$i]
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
      #$reportLine_obj = new-object psobject -prop @{ActiveSyncID=$ActiveSyncID;DN=$DN;targetAddr=$targetAddr;serialNumber=$serialNumber}
      $reportLine_obj = [pscustomobject] [ordered] @{ActiveSyncID=$ActiveSyncID;DN=$DN;targetAddr=$targetAddr;serialNumber=$serialNumber}
      $reportLines_obj += $reportLine_obj  # Concatenate with accumulator object. 
    }
  }
}  # for ($i=0; $i -lt $user_a.length; $i++)

# ...Export to Excel/CSV:
$TargetDir = "$HOME/Desktop"
Set-Location "$TargetDir"
$dateTimeStamp = Get-Date -Format "yyyyMMdd_HHmm"
$TargetFilePath = "${TargetDir}/${Rprt} - Jamf Pro Report - Exported ${dateTimeStamp}.csv" 
$reportLines_obj | Export-Csv -Path "$TargetFilePath"
Write-Host ""
# Write-Host "Results saved to"(Get-Location | Select-Object -ExpandProperty 'Path')
Write-Host "Results saved to $TargetDir"

# You can write results to screen if you want... 
# Write-Host ""
# $reportLines_obj | Out-GridView

if ($mergeWithMasterFile) {
  $masterFile = "${TargetDir}/JamfDevices.csv"
  $masterLines = Import-Csv "$masterFile"

  # ForEach ($masterLine in $masterLines) {
  #   If (-not ($reportLines_obj.ContainsKey($Matches[0]))) {
  #     $reportLines_obj
  #     $Users.Add($Matches[0],$Line)
  #   }
  # }

  # Pre-pend the newly enrolled devices to the master device list. 
  $reportLines_obj += $masterLines  
  # This list may include duplicates if the master was created a short time ago. 
  # So we will need to filter these out. 
  # We will match serial number and discard all but the first instance.  
  $matches = Compare-Object -referenceobject $array3 -differenceobject $masterlist -excludedifferent -includeequal | Select-Object -expand inputobject

  $reportLines_obj = $reportLines_obj | sort serialNumber -Ascending

  $reportLines_obj | Group-Object | ForEach-Object{$_.group | Select-Object -First 1}
  $reportLines_obj | Set-Content $file

  #Get-ChildItem -Path C:\Test -File | Sort-Object -Property Length
  #reportLines_obj | Sort-Object -Property serialNumber

  Rename-Item "$masterFile" "${masterFile}_Old_${dateTimeStamp}.csv"
  $reportLines_obj | Export-Csv -Path "$masterFile"

}
