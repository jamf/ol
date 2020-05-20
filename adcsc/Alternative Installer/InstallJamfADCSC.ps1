# Script to install Jamf Active Directory Certificate Services Connector ("ADCSC")

param (
  [switch]$Debug                        = [switch]::Present,
  [switch]$help                         = $false,
  [switch]$preCheckOnly                 = $false,
  [string]$appPoolName                  = "JamfADCSC",
  [string]$siteName                     = "JamfADCSC",
  [string]$archivePath                  = "$PSScriptRoot\adcs.zip",
  [string]$installPath                  = "$env:systemdrive\inetpub\wwwroot\${siteName}",
  [string]$siteBind_HostName            = "",
  [string]$siteBind_Port                = 8444,  
  [string]$CertificatesFolder           = "$PSScriptRoot\certs",
     [int]$selfSignedCertValidityYears  = 10,
     [int]$defaultPasswordLength        = 10,
  [string]$Server_SuppliedIdentFileName = "",
  [string]$Server_SuppliedIdentFilePass = "",
  [string[]]$Server_FQDNs               = @('adcscloadbalancer.jamf.com','srv-jamf-adcsc1.jamf.corp','srv-jamf-adcsc1.jamf.corp'),
  [switch]$Server_ExportGeneratedIdent  = [switch]::Present,
  [string]$Client_CertSubject           = 'JamfProServer',
  [string]$Client_SuppliedIdentFileName = "",
  [string]$Client_SuppliedIdentFilePass = "",
  [ValidateSet("AppPoolIdent","DomainUser")][string]$AppPoolIdent_Type    = "AppPoolIdent",
  [string]$AppPoolIdent_User            = "",
  [string]$AppPoolIdent_Pass            = "",
  [ValidateSet("DomainUser","LocalUser")][string]$Client_MapCertToUser_Type = "LocalUser",   
  [string]$Client_MapCertToUser_Name    = "",
  [string]$Client_MapCertToUser_Pass    = "" 
)

Function Write-LogDebug{
  Param([parameter(Position=0)]$MessageString)
  if ($Debug) {
      #If string starts with [OK], color it green...
      if ($MessageString.StartsWith('[OK]')) {
          Write-Host "[debug][OK]" -NoNewline -ForegroundColor Green
          $MessageString = $MessageString.TrimStart("[OK]")
      }
      if ($MessageString.StartsWith('[step]')) {
        Write-Host "[debug][step]" -NoNewline  -ForegroundColor Yellow
        $MessageString = $MessageString.TrimStart("[step]")
      }
      if ($MessageString.StartsWith('[substep]')) {
          Write-Host "[debug][substep]" -NoNewline
          $MessageString = $MessageString.TrimStart("[substep]")
      }
      if ($MessageString.StartsWith('[info]')) {
          Write-Host "[debug][info]" -NoNewline
          $MessageString = $MessageString.TrimStart("[info]")
      }
      #Write the string
      Write-Host $MessageString -ForegroundColor Gray
  }       
}
Function Write-LogSection{
  Param([parameter(Position=0)]$MessageString)
  Write-Host "$(get-date -f yyyy'-'MM'-'dd' 'HH':'mm':'ss) $MessageString" -ForegroundColor Black -BackgroundColor Green
}
Function Write-LogError{
  Param([parameter(Position=0)]$MessageString)
  Write-Host "[error]" -NoNewline -BackgroundColor Red
  Write-Host " $MessageString I'm giving up."
  Write-Host $MyInvocation.ScriptName '[Line' $MyInvocation.ScriptLineNumber']'
  exit
}

Function Write-Log{
  Param([parameter(Position=0)]$MessageString)
  if ($MessageString.StartsWith('[note]')) {
    # Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, Gray, DarkGray,
    # Blue, Green, Cyan, Red, Magenta, Yellow, White
    Write-Host "$MessageString" -BackgroundColor Cyan -ForegroundColor Black
  } elseif ($MessageString.StartsWith('[step]')) {
    Write-Host "$MessageString" -ForegroundColor Yellow
  } else {
    Write-Host $MessageString
  }
}

# ==========================================================================================

Function Test-Environment {
  Write-LogDebug "@START Test-Environment"

  Write-LogDebug "[step] Testing environment."
  Write-LogDebug "[substep] Am I running on Windows or PowerShell Core?"
 
  if ($Env:OS -eq "Windows_NT"){
    Write-LogDebug "[OK] Running on Windows."
  } else {
    Write-Log "[warn] Not running on Windows... skipping environment check"
    return
  }
  Write-LogDebug "[substep] Checking for minimum Windows version..."
  If([System.Version] (Get-WmiObject -class Win32_OperatingSystem).Version -lt [System.Version]"10.0.14393" -or -not (Get-WmiObject -class Win32_OperatingSystem).Name.Contains("Server")) {
    Write-LogError "The minimum Supported OS version is Windows Server 2016. "
  } else {
    Write-LogDebug "[OK] Supported OS version found."
  }

  Write-LogDebug "[substep] Checking that we're running as admin..."
  #Require-s -RunAsAdministrator
  $user = [Security.Principal.WindowsIdentity]::GetCurrent();
  #(New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
  if ( -Not (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) ) {
    Write-LogError("You'll need to run this script as Administrator.")
  } else {
    Write-LogDebug "[OK] Running as admin."
  }

  # If archive path is specified, check if it's a .zip file.
  if (Test-Path -Path $archivePath -PathType leaf -Include *.zip) {
    Write-LogDebug "[OK] A ZIP file exists at $archivePath"      
  } else {
    Write-LogError "ZIP archive not found at $archivePath. "
  }
  
  Test-Parameters

  if($preCheckOnly) {
    Write-LogSection "[end] Finished test run"
    exit
  }
  Write-LogDebug "@END Test-Environment"
}

Function Test-Parameters {
  Write-LogDebug "@START Test-Parameters"
  if ([string]::IsNullOrEmpty($appPoolName)){
    Write-LogError "appPoolName requires a value"
  }
  if ([string]::IsNullOrEmpty($siteName)){
    Write-LogError "siteName requires a value"
  }
  if ( $AppPoolIdent_Type -eq "DomainUser" ) {
    Write-LogDebug "[info] Using a service account for app pool"
    if($AppPoolIdent_User.Length -eq 0 -AND $AppPoolIdent_Pass.Length -eq 0) {
      Write-LogError "You need to provide values for AppPoolIdent_User and AppPoolIdent_Pass"
    }
    if($AppPoolIdent_User.Length -eq 0) {
      Write-LogError "Client_UseSuppliedCert is true but no identity file name was supplied in -AppPoolIdent_User"
    }
    if($AppPoolIdent_Pass.Length -eq 0) {
      Write-LogError "You need to provide a value for -AppPoolIdent_Pass so I can open the $AppPoolIdent_User user."
    }
  }

  Write-LogDebug "[substep] Checking Server certiticate parameters."
  if($Server_SuppliedIdentFileName) {
    if ( ! $Server_SuppliedIdentFilePass) {
      Write-LogError "-Server_SuppliedIdentFileName was provided, but not the password to read it.."
    }
  } else {
    Write-LogDebug "[info] -Server_SuppliedIdentFileName was not provided. We will create a new server identity."
    # They have not specified a server cert path so we will be making one for them.
    # Did they supply hostnames for the cert subject? 
    if($Server_FQDNs.Length -eq 0) {
      Write-LogError "-Server_SuppliedIdentFileName was not supplied and -Server_FQDNs is empty."
    } else {
      foreach ( $fqdn in $Server_FQDNs ) {
        if($fqdn.Length -eq 0) {
          Write-LogError "-Server_FQDNs cannot contain an empty element."
        }
      }
    }
  }
  Write-LogDebug "[OK] Server certiticate parameters appear valid."

  Write-LogDebug "[substep] Checking client certiticate parameters."
  if($Client_SuppliedIdentFileName.Length -eq 0) {
    Write-LogDebug "[info] No -Client_SuppliedIdentFileName was provided. We will create a new client identity."
    # They have not specified a server cert path so we will be making one for them.
    # Did they supply hostnames for the cert subject? 
    if($Client_CertSubject.Length -eq 0) {
      Write-LogError "-Client_SuppliedIdentFileName was not supplied and -Client_CertSubject is empty."
    }
  } else {
    if($Client_SuppliedIdentFilePass.Length -eq 0) {
      $Client_SuppliedIdentFileName
      $Client_SuppliedIdentFilePass
      Write-LogError "-Client_SuppliedIdentFileName was provided, but not the password to read it.."
    }
  }
  if( $Server_SuppliedIdentFileName -and ($Server_ExportGeneratedIdent.IsPresent)) {
    Write-Log "[warn] Ignoring -Server_ExportGeneratedIdent because a server identity was supplied."
  }
  Write-LogDebug "[OK] Client certiticate parameters appear valid."
}

Function Set-UserVars {
  # if the application pool is running as the local AppPool identity (default) then 
  #  ADCSC will authenticate to ADCS as the ADCSC machine and the machine will need
  #  permissions on the template used. 
  # If the application pool identity is running as a domain user, then the domain 
  #  user will need permissions to the template in ADCS. 
  # The client certificate can map to a local user on ADCSC or as a domain user.
  Param(
    [ValidateSet("AppPoolIdent","DomainUser")][string]$AppPoolIdent_Type,
    [string]$AppPoolIdent_User,
    [string]$AppPoolIdent_Pass,
    [ValidateSet("DomainUser","LocalUser")][string]$Client_MapCertToUser_Type,
    [string]$Client_MapCertToUser_Name,
    [string]$Client_MapCertToUser_Pass
  )
  Write-LogDebug "@Start Set-UserVars"
  Write-LogDebug "[step] Calcualating user vars."

  Write-LogDebug "[substep] Calculating ApplicationPoolIdentity user. (Who will the ADCSC `"Run-as`"?)"
  switch ($AppPoolIdent_Type) {
    "AppPoolIdent" {
      # If we're using appPoolIdent, there is no user domain.
      $AppPoolIdent_Domain = ""
      Write-LogDebug "[info] We will use IIS' default app pool identity."
    }
    "DomainUser" {
      # The user domain is either specified in the username before the \ or it's the same domain ADCS is bound to. 
      # It's not a local account... that couldn't have permissions on ADCS.
      $AppPoolIdent_Domain = Get-DomainFromUsername -UserName $AppPoolIdent_User
      if($AppPoolIdent_Domain -eq "") {
        Write-LogDebug "[info] No domain found in supplied DOMAIN\username. Using bound domain of the ADCSC host."
        $AppPoolIdent_Domain = (Get-WmiObject win32_computersystem).Domain
        if($AppPoolIdent_Domain -eq "") {
          Write-LogError "Could not obtain the system's domain. Is this host bound?"
        }
      }
      Write-LogDebug "[info] App Pool Identity user's domain will be set to : `"$AppPoolIdent_Domain`""
    }
    Default {
      Write-LogError "Unexpected value for `$AppPoolIdent_Type : `"$AppPoolIdent_Type`"."
    }
  }
  Write-LogDebug "[substep] Calculating info for the client certificate mapping user"
  switch ($Client_MapCertToUser_Type) {
    "DomainUser" {
      Write-LogDebug "[info] We will be using the domain of the supplied domain user"
      $Client_MapCertToUser_Domain = Get-DomainFromUsername -UserName $Client_MapCertToUser_Name
      if($Client_MapCertToUser_Domain -eq "") {
        Write-LogDebug "[info] No domain found in supplied DOMAIN\username. Checking for the bound domain of the ADCSC host instead."
        $Client_MapCertToUser_Domain = (Get-WmiObject win32_computersystem).Domain
        if($Client_MapCertToUser_Domain -eq "") {
          Write-LogError "Could not obtain the system's domain. Is this host bound?"
        }
      }
      Write-LogDebug "[info] Client certificate mapping user's domain will be set to : `"$Client_MapCertToUser_Domain`""
    }
    "LocalUser" {
      Write-LogDebug "[info] Client certificate mapping will be using a local account"
      Write-LogDebug "[substep] Obtaining domain of the local host"
      $Client_MapCertToUser_Domain = (Get-WmiObject win32_computersystem).DNSHostName
      if($Client_MapCertToUser_Domain -eq "") {
        Write-LogError "Could not obtain the local system's name"
      } else {
        Write-LogDebug "[info] Domain for local account will be the local machine : `"$Client_MapCertToUser_Domain`""
      }

      Write-LogDebug "[substep] Calculating a local username to use for client certificate mapping."
      if($Client_MapCertToUser_Name -eq "") {
        $Client_MapCertToUser_Name = $($siteName)
        Write-LogDebug "[info] The local username for client certificate mapping : `"$Client_MapCertToUser_Name`""
      } else {
        Write-LogDebug "[info] The local username for client certificate mapping : `"$Client_MapCertToUser_Name`""
      }

      Write-LogDebug "[substep] Creating a password for the new local user account."
      try {
        $Client_MapCertToUser_Pass = New-PasswordString
      } catch {
        Write-LogError "Could not configure a password for the new local user : $_"
      }  
      Write-LogDebug "[info] Password for the new local user account `$Client_MapCertToUser_Pass : `"${Client_MapCertToUser_Pass}`""
    }
    Default {
      Write-LogError "Unexpected value for `$Client_MapCertToUser_Type : `"$Client_MapCertToUser_Type`"."
    }
  }

  [hashtable]$return = @{}
  $return.AppPoolIdent_Domain         = $AppPoolIdent_Domain
  $return.Client_MapCertToUser_Domain = $Client_MapCertToUser_Domain
  $return.Client_MapCertToUser_Name   = $Client_MapCertToUser_Name
  $return.Client_MapCertToUser_Pass   = $Client_MapCertToUser_Pass

  Write-LogDebug "[OK] User vars calculated."
  Write-LogDebug "@End Set-UserVars"  

  return $return
}

Function Get-DomainFromUsername {
  param ([string]$UserName)
  Write-LogDebug "@End Get-DomainFromUsername"  
  if($UserName.Contains('\')) {
    $domain=$UserName.Split('\')[0]
  } elseif ($UserName.Contains('@')) {
    $domain=$UserName.Split('@')[1]
  } else {
    $domain = ""
  }
  Write-LogDebug "@End Get-DomainFromUsername"  
  return $domain
}

# ==========================================================================================

Function Install-IIS() {
  #Install IIS features
  Write-LogDebug "@End Install-IIS"  
  Write-Log "[step] Enabling IIS and ASP.NET Windows features. This may take a minute..."
  try {
    $result = Install-WindowsFeature -ConfigurationFilePath "$PSScriptRoot\features.xml"
    $resultExitCode = $result.ExitCode
    Write-LogDebug "[info] Install-WindowsFeature Status was `"$resultExitCode`""
  } catch {
    Write-LogError "Error enabling IIS and ASP.NET: $_"
  }
  Write-LogDebug "[OK] IIS and ASP.NET enabled."
  Write-LogDebug "@End Install-IIS"  
}

Function Clear-IIS() {
  Write-LogDebug "[step] Removing any previously configured Connector appPool and site in IIS..."
  Write-LogDebug "[substep] Checking if appPool `"${appPoolName}`" exists..."
  if (Test-Path "IIS:\AppPools\${appPoolName}") {
  #if ((Get-IISAppPool -Name "Jamf_ADCSC_Pool").Status) {
    Write-LogDebug "[info] AppPool already exists. Removing..."
    # Old way...
    # Remove-Item "IIS:\appPoolNames\${appPoolName}" -Recurse *>$null
    Remove-WebAppPool -Name "${appPoolName}"
    Write-LogDebug "[OK] `"$appPoolName`" Application Pool was removed"
  } else {
    Write-LogDebug "[OK] AppPool does not already exist."
  }
  # Test-Path "IIS:\AppPools\Jamf_ADCSC_Pool"
  # Test-Path "IIS:\appPoolNames\Jamf_ADCSC_Pool"     

  Write-LogDebug "[substep] Checking if site `"${siteName}`" exists..."
  if (Test-Path "IIS:\Sites\$siteName") {
    try {
      Write-LogDebug "[info] Site exists. Removing..."
      Remove-Item "IIS:\Sites\$siteName" -Recurse *>$null
      Write-LogDebug "[OK] Site `"$siteName`" was removed"
    } catch {
      Write-LogError "Error removing site `"$siteName`"`: $_"
    }
  }else{
    Write-LogDebug "[OK] Site `"$siteName`" was not found so it does not need to be removed."
  }

  # Now that the old site has been deleted, make sure some other site isn't already using
  #  the requested listening port...
  if(Get-WebBinding -Port $siteBind_Port) {
    Write-LogError "There's already another ISS site bound to port $siteBind_Port. Remove it or select a different port for ADCSC."
  }

}

Function Install-ADCSC() {
  Write-Log "[step] Installing ADCS Connector IIS Site Files"

  if(Test-Path $installPath) {
    try {
      Write-LogDebug "[info] Install path $installPath already exists. Deleting..."
      Write-LogDebug "[substep]Removing existing files from $installPath..."
      Remove-Item -Recurse -Force $installPath
      #Get-ChildItem $installPath -Recurse -Force | Remove-Item -Recurse -Force *>$null
      #Remove-Item $installPath -Recurse *>$null
    } catch {
      Write-LogError "Could not delete the directory: $_"
    }
  }

  try {
    Write-LogDebug "[substep] Creating target directory"
    New-Item -Path $installPath -ItemType directory *>$null
    Write-LogDebug "[OK] Created folder `"$installPath`""    
  } catch {
      Write-LogError "Could not create target directory: $_"
  }
  
  Write-LogDebug "[substep] Unzipping ADCSC site files to $installPath..."
  try {
    Expand-Archive -Path $archivePath -DestinationPath $installPath  *>$null
    Write-LogDebug "[OK] Un-zip Complete"
  }
  catch {
    Write-LogError "Could not extract archive to target directory: $_"
  }
}

Function New-ADCSC_AppPool() {
  param (
    $AppPoolIdent_Domain
  )
  Write-LogDebug "@Start New-ADCSC_AppPool"
  Write-Log "[step] Configuring ADCS Connector IIS AppPool"
  Write-LogDebug "[substep] Creating $appPoolName Application Pool..."
  try {
    # New-Item IIS:\AppPools\$appPoolName *>$null
    New-WebAppPool -Name $appPoolName  *>$null # -Force ?
    Write-LogDebug "[OK] Created App Pool"
  }
  catch {
    Write-LogError "Error creating application pool: $_"
  }
  Write-LogDebug "[substep] Setting AppPool managedRuntimeVersion Property"
  try {
    Set-ItemProperty IIS:\AppPools\$appPoolName managedRuntimeVersion v4.0 *>$null
    Write-LogDebug "[OK] Property set."
  }
  catch {
    Write-LogError "Error setting AppPool property: $_"
  }
  # AppPoolIdent if authenticating to ADCS as ADCSC Host, User if using service account.
  Write-LogDebug "[substep] Setting Application Pool Identity"
  switch ($AppPoolIdent_Type)
  {
    "AppPoolIdent" {
      Write-LogDebug "[info] AppPool will run as the IIS default ApplicationPoolIdentity."
    }
    "DomainUser" {
      Write-LogDebug "[info] Setting AppPool to run as a specific user"
      try {
        Set-ItemProperty IIS:\AppPools\$appPoolName -name processModel -value @{userName="${AppPoolIdent_Domain}\${AppPoolIdent_User}";password="${AppPoolIdent_Pass}";identitytype="SpecificUser"} *>$null
        Write-LogDebug "[OK] Property set."
        $setting=Get-ItemProperty IIS:\AppPools\$appPoolName -name processModel
        Write-LogDebug "[info] The appPool identity will run as : identityType=${setting}.identityType, userName=${setting}.userName"
      }
      catch {
        Write-LogError "Error setting AppPool processModel property: $_"
      }
    }
    default { 
      Write-LogError "An unsupported value was found for `$AppPoolIdent_Type - `"$AppPoolIdent_Type`". " 
    }
  }
  Write-LogDebug "@END New-ADCSC_AppPool"
}

Function Set-ServerCert {
  param (
    [string]$siteName,
    [string[]]$Server_FQDNs,
    [string]$selfSignedCertValidityYears,
    [string]$CertificatesFolder,
    [string]$Server_SuppliedIdentFileName,
    [string]$Server_SuppliedIdentFilePass,
    [switch]$Server_ExportGeneratedIdent
  )

  Write-LogDebug "@Start Set-ServerCert"
  # Figure out if the user is supplying a server identity, or if we need to make one... 
  if ( $Server_SuppliedIdentFileName) {
    Write-LogDebug "[info] Server cert file name was supplied"
    $Server_Identity_ = Set-ServerCert_GetSupplied `
      -CertificatesFolder "$CertificatesFolder" `
      -Server_SuppliedIdentFileName "$Server_SuppliedIdentFileName" `
      -Server_SuppliedIdentFilePass "$Server_SuppliedIdentFilePass"
    # Populate these as blank -- they only have values when we created a new ident and exported it. 
    $Server_IdentityFilePass = ''
  } else {
    Write-LogDebug "[info] No server cert file name was supplied so we'll made a self-signed cert"
    $return = Set-ServerCert_MakeNew `
      -Server_FQDNs $Server_FQDNs `
      -selfSignedCertValidityYears $selfSignedCertValidityYears `
      -CertificatesFolder $CertificatesFolder `
      -Server_ExportGeneratedIdent $Server_ExportGeneratedIdent
    $Server_IdentityFilePass = $return.Server_IdentityFilePass  
    $Server_Identity_ = $return.Server_Identity_  
  }

  Set-ServerCert_TrustedRoot -Server_Identity_ $Server_Identity_
  Write-LogDebug "@END Set-ServerCert"

  [hashtable]$return = @{}
  $return.Server_IdentityFilePass = $Server_IdentityFilePass
  $return.Server_Identity_        = $Server_Identity_
  return $return
}

Function Set-ServerCert_TrustedRoot {
  param (
    $Server_Identity_
  )
  Write-LogDebug "@START Set-ServerCert_TrustedRoot"

  Write-LogDebug "[info] Thumbprint of the IIS Server Cert : $($Server_Identity_.Thumbprint)"
  
  Write-LogDebug "[substep] Exporting the public key for the IIS TLS identity"
  $Server_CertPath="$SavedCertificatesFolder\server-cert.cer"
  Write-Log "[info] The public key for the server SSL certificate will be saved to `"$Server_CertPath`"."
  if(Test-Path $Server_CertPath) {
    Remove-Item $Server_CertPath *>$null
  }
  Export-Certificate -Cert $Server_Identity_ -FilePath "$Server_CertPath" *>$null
  Write-LogDebug "[OK] Exported the public key for import into Jamf Pro."

  Write-LogDebug "[substep] Making the public key a trusted root on this server..."
  # Seems like there should be some way to do this direct from ident object, but I can only figure out how to do it from disk...
  Import-Certificate -FilePath $Server_CertPath -CertStoreLocation Cert:\LocalMachine\Root *>$null

  Write-LogDebug "@END Set-ServerCert_TrustedRoot"
  # return $Server_Identity_
}

Function Set-ServerCert_GetSupplied {
  param (
    $CertificatesFolder,
    $Server_SuppliedIdentFileName,
    $Server_SuppliedIdentFilePass
  )
  Write-LogDebug "@Start Set-ServerCert_GetSupplied"
  $Server_IdentityFilePath="$CertificatesFolder\$Server_SuppliedIdentFileName"
  Write-LogDebug "[step] Using a supplied file for the site TLS certificate : `"$Server_IdentityFilePath`""

  # $objItem = Get-Item cert:\localMachine\my\12672DE7E6465975FD9ED06A1D0C2E17E3E0E65A
  # Try   { 
  #   $blnFound = ($objItem.HasPrivateKey -eq $True) 
  #   $arrSplit = $objItem.PSParentPath -split "::"        
  #   write-host 'Path        '$arrSplit[1]                
  #   write-host 'Subject     '$objItem.SubjectName.Name   
  #   write-host 'Expires     '$objItem.NotAfter           
  #   write-host 'Private Key '$objItem.HasPrivateKey
  # } 
  # Catch { $blnFound = $False }

  Write-LogDebug "[substep] Checking the server identity file."
  $cert_ = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
  $cert_.Import($Server_IdentityFilePath,$Server_SuppliedIdentFilePass,[System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]"DefaultKeySet")
  if ($null -eq ($cert_.EnhancedKeyUsageList | Where-Object FriendlyName -eq "Server Authentication")) {
    Write-LogDebug "The provided server identity does not have `"Server Authentication`" in it's list of purposes. "
    Write-LogDebug "This should have been in the CSR you submitted to obtain the certificate or in the ADCS template."
    Write-LogError "Try again with a corrected identity file."
  } else {
    Write-LogDebug "[ok] The provided server certificate has a `"Server Authentication`" purpose"
  }
  if (($cert_.HasPrivateKey) -ne $true) {
    Write-LogError "The provided server identity does not contain a private key."
  } else {
    Write-LogDebug "[ok] The provided server certificate has a private key"
  }
  $cert_.DnsNameList | ForEach-Object Unicode 
  Write-LogDebug "[substep] Checking the server cert subject alternative names."
  $Server_CertCN=$Server_FQDNs[0]
  Write-LogDebug "[info] The first item in the `$Server_FQDNs parameter is assumed to be the ADCSC host name you will enter in Jamf Pro."
  Write-LogDebug "[info] Hostname used to connect Jamf Pro to ADCSC : $Server_CertCN"
  if ($null -eq ($cert_.DnsNameList | Where-Object DnsNameList -eq "$Server_CertCN" )) {
    Write-Log "[warning] The provided server cert does not include the hostname Jamf Pro will contact to access ADCSC."
    Write-Log "[warning] If you are using a proxy, that may be intentional. If connecting directly, this is an error. "
  }else{
    Write-Log "[ok] The provided server cert includes the hostname Jamf Pro will contact to access ADCSC."
  }
  Write-LogDebug "[info] Certificate Issuer     : $cert_.Issuer"
  Write-LogDebug "[info] Certificate PolicyId   : $cert_.PolicyId"
  Write-LogDebug "[info] Certificate Subject    : $cert_.Subject"
  Write-LogDebug "[info] Certificate Thumbprint : $cert_.Thumbprint"

  Write-LogDebug "[substep]Importing the server TLS identity pfx file from disk : $Server_IdentityFilePath"
  # It's more convenient to accept the .pfx file password as a script parameter
  #  but it's not a safe practice outside of test environments.
  # Write-LogDebug "Password for the pfx file : $Server_SuppliedIdentFilePass"
  if ( $Server_SuppliedIdentFilePass -eq "" ) {
    Write-LogDebug "[Interaction] Prompting for pfx file Password..."
    $Server_SuppliedIdentFilePass_Secure = Read-Host -AsSecureString "Please enter the password to use when reading the `"$Server_SuppliedIdentFileName`" server SSL certificate file"
  }else{
    Write-LogDebug "[>substep] Converting supplied password to secure string"
    $Server_SuppliedIdentFilePass_Secure = ConvertTo-SecureString -String $Server_SuppliedIdentFilePass -AsPlainText -Force
  }
  try {
    # Import certificate chain and private key from PFX file into the destination store.
    # Cert:\LocalMachine\MY or Cert:\LocalMachine\Root ? References differ... 
    $Server_Identity_ = Import-PfxCertificate `
      -FilePath "$Server_IdentityFilePath" `
      -CertStoreLocation 'Cert:\LocalMachine\Root' `
      -Exportable `
      -Password $Server_SuppliedIdentFilePass_Secure
  } catch [System.Management.Automation.ItemNotFoundException] {
    Write-LogError "I couldn't find the pfx you specified for the server cert. Please check the name on that setting. Did you forget the .pfx extension? $_"
  } catch {
    Write-LogError "Error reading in the .pfx :  $_. "
  }
  Write-LogDebug "@End Set-ServerCert_GetSupplied"
  return $Server_Identity_
}

Function Set-ServerCert_MakeNew {
  param (
    [string[]]$Server_FQDNs,
    [string]$selfSignedCertValidityYears,
    [string]$CertificatesFolder,
    [switch]$Server_ExportGeneratedIdent
  )
  Write-LogDebug "@Start Set-ServerCert_MakeNew"
  Write-LogDebug "[step] Generating a self-signed certificate for IIS HTTPS..."
  # $Server_CertCN=$Server_FQDNs[0]
  # Write-LogDebug "[info] Subject=$Server_CertCN"
  # "CN=Jamf ADCSC Server-Self-Signed" @@@
  # -Subject "CN=$Server_CertCN" `
  # -FriendlyName "Jamf ADCSC Server-Self-Signed"
  try {
    $Server_Identity_ = New-SelfSignedCertificate `
      -CertStoreLocation Cert:\LocalMachine\MY `
      -DnsName $Server_FQDNs `
      -KeyExportPolicy Exportable `
      -KeyUsage DigitalSignature,CertSign,CRLSign,DataEncipherment,KeyEncipherment `
      -KeyLength 2048 `
      -KeyAlgorithm 'RSA' `
      -HashAlgorithm 'SHA256' `
      -NotAfter (Get-Date).AddYears($selfSignedCertValidityYears)
  } catch {
    Write-LogError "Could not generate and/or export a self-signed HTTPS certifiate for ${CertCN}`: $_"
  }
  Write-LogDebug "[OK] A self-signed certificate has been generated for IIS's HTTPS..."
  Write-LogDebug "[Info] Subject=${Server_Identity_.Subject}"
  Write-LogDebug "[Info] Issuer=${Server_Identity_.Issuer}"
  Write-LogDebug "[Info] Thumbprint=${Server_Identity_.Thumbprint}"
  Write-LogDebug "[Info] Expiration=${Server_Identity_.NotAfter}"
  Write-Log "[substep] Checking to see if server identity file export was requested"
  if($Server_ExportGeneratedIdent.IsPresent) {
    $Server_IdentityFilePass = Set-ServerCert_MakeNew_Export `
      -Server_Identity_ $Server_Identity_ `
      -CertificatesFolder $CertificatesFolder `
      -timestamp $timestamp
  } else {
    $Server_IdentityFilePass = ''
    Write-LogDebug "[skip] Export was not requested."
  }
  Write-LogDebug "@End Set-ServerCert_MakeNew"

  [hashtable]$return = @{}
  $return.Server_IdentityFilePass   = $Server_IdentityFilePass
  $return.Server_Identity_   = $Server_Identity_
  return $return
}

Function Set-ServerCert_MakeNew_Export{
  Param (
    $Server_Identity_,
    $CertificatesFolder,
    $timestamp
  )
  Write-LogDebug "@START Set-ServerCert_MakeNew_Export"
  # If we created out own server cert and we are load balancing/proxying, we'll need to 
  #  use this identity on other servers. We'll export it so it can be copied over.
  Write-Log "[substep] Exporting the server identity as .pfx for use on replica Connector server(s)."
  # Where is it in windows' keystore?
  $KeystoreIdentPath="Cert:\LocalMachine\MY\$($Server_Identity_.Thumbprint)"
  Write-LogDebug "[info] Path to identity in Windows keystore : $KeystoreIdentPath"
  $Server_IdentityFilePath="$SavedCertificatesFolder\server-cert.pfx"
  Write-Log "[notice] The server.pfx file will be saved to `"$Server_IdentityFilePath`"."
  $Server_IdentityFilePass = New-PasswordString -CharSets "ULN"
  Write-Log "[notice] The .pfx file password is `"$Server_IdentityFilePass`"."
  Write-Log "[notice] You'll need this only if you're going to be setting up additional Connector servers for load balancing or failover."
  if ([string]::IsNullOrEmpty($Server_IdentityFilePass)) {
    Write-LogError "Could not generate a password for the self-signed .pfx certificate export file."
  }
  $Server_IdentityFilePassSecure = ConvertTo-SecureString -String $Server_IdentityFilePass -AsPlainText -Force
  Export-PfxCertificate -Cert $KeystoreIdentPath -FilePath $Server_IdentityFilePath -Password $Server_IdentityFilePassSecure >$null
  Write-Log "[substep] Checking to see if server identity file export was requested"
  if ($Debug) {
    Write-LogDebug "[substep] Running in debug so we'll save server ident password to a file. "
    Write-LogDebug "(Insecure-Not intended for production...)"
    $Client_IdentSaveFilePath = "${SavedCertificatesFolder}\server-cert.pfx ${Server_IdentityFilePass}.pass"
    Set-Content `
      -Path "${Client_IdentSaveFilePath}" `
      -Value 'This is needed to read the server_cert.pfx file: ${Client_SelfSignedCertFilePass}'
  }
  Write-LogDebug "@END Set-ServerCert_MakeNew_Export"
  return $Server_IdentityFilePass
}

Function New-ADCSC_Site {
  param ($Server_Identity_)
  Write-LogDebug "@START New-ADCSC_Site"
  Write-Log "[step] Creating IIS Site `"$siteName`""

  # Start-IISCommitDelay
  # Stop-IISCommitDelay
  # Stop-IISCommitDelay -Commit $false

  Write-LogDebug "[substep] Creating new site"

  try {
    # $site_ = New-IISSite `
    #   -Name $siteName `
    #   -PhysicalPath $installPath `
    #   -BindingInformation "*:$siteBind_Port`:$hostPath" 
    New-Item IIS:\Sites\$siteName `
      -physicalPath $installPath `
      -bindings @{protocol="https";bindingInformation="*:$siteBind_Port`:$hostPath"} *>$null
  } catch {
      Write-Host "Error creating $siteName`: $_"
      exit
  }

  Write-LogDebug "[substep] Setting site to run in the `"$appPoolName`" application pool."
  Set-ItemProperty IIS:\Sites\$siteName -name applicationPool -value $appPoolName *>$null
  # Set-ItemProperty IIS:\Sites\$siteName -name applicationPool -value $appPoolName *>$null
  # $site_.Applications["/"].ApplicationPoolName = "$appPoolName"

  Write-LogDebug "[substep] Setting site SSL flags."
  Set-WebConfigurationProperty `
    -pspath 'MACHINE/WEBROOT/APPHOST' `
    -location "$siteName" `
    -filter "system.webServer/security/access" `
    -name "sslFlags" `
    -value "Ssl,SslNegotiateCert,SslRequireCert" *>$null

  
  # Write-LogDebug "[substep] Getting the thumbprint of the Server TLS identity."
  # $thumbprint = $Server_Identity_.Thumbprint

  $binding = Get-WebBinding -Name "$siteName" -Protocol https
  # deploy.ps1 way: $binding.AddSslCertificate($cert.GetCertHashString(), "MY") *>$null
  $binding.AddSslCertificate($Server_Identity_.GetCertHashString(), "MY") *>$null

  # $binding = Get-WebBinding -Name "$siteName" -Protocol https
  # Set-WebBinding -Name $siteName -BindingInformation "*:${siteBind_Port}:" -PropertyName "Protocol" -Value "https"
  # Set-WebBinding -Name $siteName -Port  -PropertyName "SslFlag" -Value "Ssl,SslNegotiateCert,SslRequireCert"
  # Set-WebBinding -Name $siteName -Port $siteBind_Port -PropertyName "CertificateThumbPrint" -Value "$thumbprint"
  # Set-WebBinding -Name $siteName -Port $siteBind_Port -PropertyName "CertStoreLocation" -Value "Cert:\LocalMachine\MY"

  # Write-LogDebug "[substep] Creating new site"
  # Set-ItemProperty IIS:\Sites\$siteName -name applicationPool       -value $appPoolName *>$null
  # Set-ItemProperty IIS:\Sites\$siteName -name Protocol              -value $appPoolName *>$null
  # Set-ItemProperty IIS:\Sites\$siteName -name SslFlag               -value $appPoolName *>$null
  # Set-ItemProperty IIS:\Sites\$siteName -name CertificateThumbPrint -value $appPoolName *>$null
  # Set-ItemProperty IIS:\Sites\$siteName -name CertStoreLocation     -value $appPoolName *>$null
  
  
  Write-LogDebug "[substep] Disabling anonymousAuthentication"
  Set-WebConfigurationProperty `
    -filter /system.webServer/security/authentication/anonymousAuthentication `
    -name enabled `
    -value false `
    -PSPath IIS:\\ `
    -location ${site_name}  # /${virtual_directory_name}

  Write-LogDebug "[substep] Setting iisClientCertificateMappingAuthentication default login domain."
  Set-WebConfigurationProperty `
    -pspath 'MACHINE/WEBROOT/APPHOST' `
    -location "$siteName" `
    -filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication" `
    -name "defaultLogonDomain" `
    -value $Client_MapCertToUser_Domain # *>$null

  Write-Log "[OK] IIS Site created."


  # try {
  #   Write-LogDebug "[substep] Creating Site"
  #   New-Item IIS:\Sites\$siteName 
  #   -physicalPath $installPath 
  #   -bindings @{protocol="https";bindingInformation="*:$siteBind_Port`:$hostPath"} *>$null
  # 
  # }
  # catch {
  #   Write-LogError "Error creating $siteName`: $_"
  # }

  # $binding = Get-WebBinding -Name "$siteName" -Protocol https
  # $binding.AddSslCertificate($Server_Identity_.GetCertHashString(), "MY") # *>$null

  Write-LogDebug "[info] Binding status of IIS site..."
  Write-LogDebug "X-Path to bound port    : $($binding.ItemXPath)"
  Write-LogDebug "Path to bound host:port : $($binding.bindingInformation)"
  Write-LogDebug "Binding protocol        : $($binding.protocol)"
  Write-LogDebug "Binding cert thumbprint : $($binding.certificateHash)"
  Write-LogDebug "Binding cert store name : $($binding.certificateStoreName)"

  Write-LogDebug "@END New-ADCSC_Site"
}

Function Set-JamfProAuthCert($Server_Identity_) {
  Write-LogDebug "@Start Set-JamfProAuthCert"
  Write-Log "[step] Generating or importing an identity for Jamf Pro authentication to IIS..." 
  if(! $Client_SuppliedIdentFileName) {
    Write-LogDebug "[info] No client identity file supplied. We will create one."
    $Client_IdentSaveFilePath = "${SavedCertificatesFolder}\client-cert.pfx"
    Write-LogDebug "[substep] Generating a self-signed certificate for Jamf Pro to use when authenticating to IIS..."
    $Server_CertCN=$Server_FQDNs[0]
    try {
      # Create a new cert signed by the SSL cert generated or imported above.
      # If we imported a cert it's purpose would need to include DigitalSignature
      $clientCert = New-SelfSignedCertificate `
        -CertStoreLocation Cert:\LocalMachine\MY `
        -Subject "CN=Jamf ADCSC Client Auth" `
        -DnsName $Client_CertSubject `
        -Signer $Server_Identity_ `
        -KeyExportPolicy Exportable `
        -KeyUsage DigitalSignature,DataEncipherment,KeyEncipherment `
        -KeyLength 2048 `
        -KeyAlgorithm 'RSA' `
        -HashAlgorithm 'SHA256' `
        -NotAfter (Get-Date).AddYears($selfSignedCertValidityYears)
    } catch {
      Write-LogError "Could not generate `"${Server_CertCN}`"-signed certificate for ${jamfProAuth_JamfProHostName}: $_"
    }
    try {
      #Grab the base64 of the key -- we'll need it when setting it up as a client authentication cert in IIS...
      $Client_MapCertToUser_base64 = [convert]::tobase64string($clientCert.RawData)
      if(Test-Path $Client_IdentSaveFilePath) {
        Remove-Item $Client_IdentSaveFilePath *>$null
      }
      Write-LogDebug "[substep] Exporting client certificate keystore..."   
      $Client_IdentKeystorePath="Cert:\LocalMachine\MY\$($clientCert.Thumbprint)"
      $Client_SelfSignedCertFilePass = New-PasswordString -CharSets "ULN"
      Write-Log "[info] The client.pfx file will be saved to $Client_IdentSaveFilePath. The keystore password is `"$Client_SelfSignedCertFilePass`". You'll need this when configuring Jamf Pro to talk to this Connector."
      $Client_SelfSignedCertFilePass_Secure = ConvertTo-SecureString -String $Client_SelfSignedCertFilePass -AsPlainText -Force
      Export-PfxCertificate `
        -Cert $Client_IdentKeystorePath `
        -FilePath $Client_IdentSaveFilePath `
        -Password $Client_SelfSignedCertFilePass_Secure *>$null
      Write-LogDebug "[info] Client Authentication Certificate path in Windows keystore : $Client_IdentKeystorePath"
      Write-LogDebug "[OK] Client identity exported."
    } catch {
      Write-LogError "Could not export the `"${Server_CertCN}`"-signed certificate for ${jamfProAuth_JamfProHostName}: $_"
    }
    if ($Debug) {
      Write-LogDebug "[substep] Running in debug so we'll save client cert password to a file. (Insecure-Not intended for production...)"
      $Client_IdentSaveFilePath = "${SavedCertificatesFolder}\client_cert.pfx ${Client_SelfSignedCertFilePass}.pass"
      Set-Content -Path "${Client_IdentSaveFilePath}" -Value "This is needed to read the client_cert.pfx file : ${Client_SelfSignedCertFilePass}."
    }
  }
  [hashtable]$return = @{}
  $return.Client_SelfSignedCertFilePass = $Client_SelfSignedCertFilePass
  $return.Client_MapCertToUser_base64   = $Client_MapCertToUser_base64
  Write-LogDebug "@END Set-JamfProAuthCert"
  return $return
}

Function Set-ClientCertMapping_LocalUser {
  param (
    [string]$Client_MapCertToUser_Name,
    [string]$Client_MapCertToUser_Pass
  )
  Write-LogDebug "@Start Set-ClientCertMapping_Local"
  Write-Log "[step] Creating local user account `"$Client_MapCertToUser_Name`" for IIS Client Certificate Mapping Authentication."
  Write-LogDebug "[substep] Checking if the account already exists."
  # if((Get-WmiObject Win32_UserAccount -Filter "LocalAccount -eq 'true') and (Name -eq '$Client_MapCertToUser_Name'")) {
  #   Write-LogDebug "[info] User already exists. Deleting..."
  #   Remove-LocalUser -Name "$Client_MapCertToUser_Name" # *>$null
  #   Write-LogDebug "[OK] Old account deleted."
  # }else{
  #   Write-LogDebug "[OK] User account does not already exist. "
  # }

  #Declare LocalUser Object
  $ObjLocalUser = $null

  Try {
    $ObjLocalUser = Get-LocalUser $Client_MapCertToUser_Name
  } 
  Catch [Microsoft.PowerShell.Commands.UserNotFoundException] {
    Write-LogDebug "[OK] User $($Client_MapCertToUser_Name) does not yet exist."
  }
  Catch {
    Write-LogError "An error occured while checking for local user account."
  }
  #Delete the user if it was found
  If ($ObjLocalUser) {
    Write-LogDebug "[info] User $($Client_MapCertToUser_Name) Already exists."
    Write-LogDebug "[substep] Deleting old local user account"
    try {
      Remove-LocalUser -Name "$Client_MapCertToUser_Name" # *>$null
    } catch {
      Write-LogError "Could not remove pre-existing local account : $_"
    }
  }

  Write-LogDebug "[substep] Creating new local user account."
  try {
    # $localUser = New-LocalUser -Name "$Client_MapCertToUser_Name" -Password $Client_MapCertToUser_Pass_Secure -AccountNeverExpires -PasswordNeverExpires
    $Client_MapCertToUser_Pass_Secure=ConvertTo-SecureString $Client_MapCertToUser_Pass -AsPlainText -Force
    New-LocalUser -Name "$Client_MapCertToUser_Name" -Password $Client_MapCertToUser_Pass_Secure -AccountNeverExpires -PasswordNeverExpires
    if (! $?) {
      Write-LogError "Could not create the new local user"      
    }
  } catch {
    Write-LogError "Could not create the new local user : $_"
  }

  Write-LogDebug "[>substep] Adding new local account to IIS_IUSRS group."
  if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -eq 2 ) {
    Write-LogDebug "[info] This machine is a domain controller. I'll add the new user account to the domain's IIS_IUSRS group."
    Add-ADGroupMember -Identity "IIS_IUSRS" -Members "$Client_MapCertToUser_Name"
  } else {
    # Add-LocalGroupMember -Member "Jamf_ADCSCUser" -Group "IIS_IUSRS"
    Add-LocalGroupMember -Group "IIS_IUSRS" -Member "$Client_MapCertToUser_Name" *>$null
  }
  Write-LogDebug "[OK] Created new local user $Client_MapCertToUser_Name"

  [hashtable]$return = @{}
  $return.Client_MapCertToUser_Name = $Client_MapCertToUser_Name
  $return.Client_MapCertToUser_Pass = $Client_MapCertToUser_Pass

  Write-LogDebug "@END Set-ClientCertMapping_Local"

  return $return
}

Function Set-ClientCertMapping_DomainUser {

  # mapping to domain service account requested. 
  # If username and password were provided, we will test that and use it if good. 
  # If no username and password were provided, we could create our own but we don't know their naming scheme for service accounts. 
  param ($Client_MapCertToUser_Domain,$Client_MapCertToUser_Name,$Client_MapCertToUser_Pass)
  Write-LogDebug "@Start Set-ClientCertMapping_Domain"

  
  Write-LogDebug "Checking if supplied domain user exists"
  Try {  
    Get-ADuser $Client_MapCertToUser_Name -ErrorAction Stop  
    return $true  
  }   
  Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {  
    Write-LogError("Could not find an existing domain account for `"$Client_MapCertToUser_Name`"")
  }

  if ( $null -ne  (new-object directoryservices.directoryentry "",$Client_MapCertToUser_Name,$Client_MapCertToUser_Pass).psbase.name ) {
    # Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    # $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('domain')
    # $DS.ValidateCredentials($UserName, $Password)
    Write-LogError("Please check the username and password for the domain service account you supplied.")
  }
  $members = Get-ADGroupMember -Identity $Client_MapCertToUser_Domain -Recursive | Select-Object -ExpandProperty Name
  If ($members -contains $Client_MapCertToUser_Name) {
    Write-Host "$Client_MapCertToUser_Name is a member of the IIS_IUSRS group"
  } Else {
    Write-Host "$Client_MapCertToUser_Name is not a member of the IIS_IUSRS group"
    Add-ADGroupMember -Identity "IIS_IUSRS" -Members "$Client_MapCertToUser_Name"
  }
  Write-LogDebug "@END ClientCertMapping_Domain"
}

Function Set-ClientCertMapping_Configure {
  param ($Client_MapCertToUser_Name,$Client_MapCertToUser_Pass,$Client_MapCertToUser_Domain,$Client_MapCertToUser_base64)
  Write-LogDebug "@Start Set-ClientCertMapping_Configure"
  # Write-LogDebug "Parameters:"
  # Write-LogDebug "  Client_MapCertToUser_Domain : ${Client_MapCertToUser_Domain}"
  # Write-LogDebug "  Client_MapCertToUser_Name   : ${Client_MapCertToUser_Name}"
  # Write-LogDebug "  Client_MapCertToUser_Pass   : ${Client_MapCertToUser_Pass}"
  # Write-LogDebug "  Client_MapCertToUser_base64 : ${Client_MapCertToUser_base64}"
  if( ! $Client_SuppliedIdentFileName) {
    # We have made a self-signed cert. Now we will use that to create one to one client cert auth mapping. 
    # to-do -- Isn't this needed if cert was supplied?
    # What if they don't want cert-based auth, like they're doing NTLM or terminating auth at the LB?
    #  Could have a "none" mode.  
    Write-Log "[step] Configuring IIS Client Certificate Mapping Authentication for $Client_MapCertToUser_Name..."
    Write-LogDebug "[substep] Setting default logon domain to $Client_MapCertToUser_Domain"
    try {
      Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' `
        -location "$siteName" `
        -filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication" `
        -name "defaultLogonDomain" `
        -value $Client_MapCertToUser_Domain # *>$null
    }
    catch {
      Write-LogError "Could not set certificate mapping login domain: $_"
    }
    Write-LogDebug "[OK] Set certificate mapping login domain"

    Write-LogDebug "[substep] Enabling iisClientCertificateMappingAuthentication"
    try {
      Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' `
        -location "$siteName" `
        -filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication" `
        -name "enabled" `
        -value "True" #*>$null
    }
    catch {
      Write-LogError "Could not enable iisClientCertificateMappingAuthentication: $_"
    }
    Write-LogDebug "[OK] iisClientCertificateMappingAuthentication enabled"

    Write-LogDebug "[substep] Disabling manyToOneCertificateMapping"
    try {
      Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' `
        -location "$siteName" `
        -filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication" `
        -name "manyToOneCertificateMappingsEnabled" `
        -value "False" #*>$null
    }
    catch {
      Write-LogError "Could not disable manyToOneCertificateMapping: $_"
    }
    Write-LogDebug "[OK] manyToOneCertificateMapping disabled"

    Write-LogDebug "[substep] Setting property list for oneToOneMappings."
    Write-LogDebug "[info] userName=`"$Client_MapCertToUser_Name`""
    Write-LogDebug "[info] password=`"$Client_MapCertToUser_Pass`""
    # Write-LogDebug "[info] certificate : `"$Client_MapCertToUser_base64`""
    try {
      Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' `
        -location "$siteName" `
        -filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication/oneToOneMappings" `
        -name "." `
        -value @{userName="$Client_MapCertToUser_Name"; password="$Client_MapCertToUser_Pass"; certificate="$Client_MapCertToUser_base64"} #*>$null
    } catch {
      Write-LogError "Could not configure IIS client certificate mapping authentication: $_"
    }
  }
  Write-LogDebug "@End Set-ClientCertMapping_Configure"
}

Function Set-ClientCertMapping {

  param(
    [string]$Client_MapCertToUser_Domain,
    [string]$Client_MapCertToUser_Name,
    [string]$Client_MapCertToUser_Pass,
    [string]$Client_MapCertToUser_base64
  )

  Write-LogDebug "@Start Set-ClientCertMapping"
  # Write-LogDebug "Parameters:"
  # Write-LogDebug "  Client_MapCertToUser_Domain : ${Client_MapCertToUser_Domain}"
  # Write-LogDebug "  Client_MapCertToUser_Name   : ${Client_MapCertToUser_Name}"
  # Write-LogDebug "  Client_MapCertToUser_Pass   : ${Client_MapCertToUser_Pass}"
  # Write-LogDebug "  Client_MapCertToUser_base64 : ${Client_MapCertToUser_base64}"

  switch ( $Client_MapCertToUser_Type )
  {
    "LocalUser" {
      # In the local account option, we require that the account does not exist. We will create it and generate a password. 
      Write-LogDebug "[substep] Creating a local account to use with client certificate mapping"
      $result = Set-ClientCertMapping_LocalUser -Client_MapCertToUser_Name "$Client_MapCertToUser_Name" -Client_MapCertToUser_Pass "$Client_MapCertToUser_Pass"
      $Client_MapCertToUser_Name = $result.Client_MapCertToUser_Name
      $Client_MapCertToUser_Pass = $result.Client_MapCertToUser_Pass
    }
    "DomainUser" {
      # In the domain account option, we require that the account already exists and that the password has been provided. 
      Write-LogDebug "[substep] Checking that the requested domain service account exists"
      Set-ClientCertMapping_DomainUser -Client_MapCertToUser_Domain $Client_MapCertToUser_Domain -Client_MapCertToUser_Name "$Client_MapCertToUser_Name" -Client_MapCertToUser_Pass "$Client_MapCertToUser_Pass"
    }
    default {
      Write-LogError "Invalid value for `$Client_MapCertToUser_Type : $Client_MapCertToUser_Type"
    }
  }

  Set-ClientCertMapping_Configure -Client_MapCertToUser_Name "$Client_MapCertToUser_Name" -Client_MapCertToUser_Pass "$Client_MapCertToUser_Pass" -Client_MapCertToUser_Domain "$Client_MapCertToUser_Domain" -Client_MapCertToUser_base64 "$Client_MapCertToUser_base64"
  Write-Log "[OK] Client certificate configured for user authentication in IIS."
  # At the end of C:\Windows\System32\inetsrv\Config\applicationHost.config we would now expect to see something like...
  # <location path="AdcsConnector">
  #   <system.webServer>
  #       <security>
  #           <access sslFlags="Ssl, SslNegotiateCert, SslRequireCert" />
  #           <authentication>
  #               <iisClientCertificateMappingAuthentication enabled="true" manyToOneCertificateMappingsEnabled="false">
  #                   <oneToOneMappings>
  #                       <add userName="<accountName>" password="[enc:IISCngProvider:<longPasswordencryptedstring>f8FuiM0mrKZruF4QN4ueEj1e1N0=:enc]" certificate="" />
  #                   </oneToOneMappings>
  #               </iisClientCertificateMappingAuthentication>
  #           </authentication>
  #       </security>
  #   </system.webServer>
  # </location>
  Write-LogDebug "@End Set-ClientCertMapping"
}

Function New-FirewallRule() {
  Write-LogDebug "@Start New-FirewallRule"
  Write-Log "[step] Adding Windows Firewall rule to allow inbound TCP traffic on port $siteBind_Port"
  try {
    New-NetFirewallRule -DisplayName "ADCS Connector" -Direction Inbound -LocalPort $siteBind_Port -Protocol TCP -Action Allow *>$null
  }
  catch {
    Write-Host "Could not create firewall rule for port $siteBind_Port`: $_"
  }
  Write-LogDebug "[OK] Added Windows firewall rule"
}

Function Start-AppPool() {
  if((Get-WebAppPoolState -Name $appPoolName).Value -ne 'Started'){
    Write-Log ("Starting Application Pool: $appPoolName")
    Start-WebAppPool -Name $appPoolName
  }
}

Function Write-SetupInfo {
  param (
    $Server_IdentityFilePass,
    $Client_SelfSignedCertFilePass
  )
  # Could use this to save pfx passwords to a file. Probably safer to just put them on screen, though.  
  Write-LogDebug "[step] Writing summary information"

$warning = @"
[!] Take care to protect this information and the .p12 file(s) in the certs folder.
User a secure method to transfer from one machine to another. The client key and 
password guard connections to ADCSC. Delete all copies of this information and .p12 
files as soon as you have finished your configuration. 
"@

$summary = @"
What to do next... 
To configure Jamf Pro, go to:
  Settings>PKI Certrificates>Configure New Certificate Authority>Active Directory Certificate Services
Values to fill in are as follows:
> FULLY QUALIFIED DOMAIN NAME of the CA server:
  Fill in the host name the Connector should resolve to get the IP of your ADCS host. 
>CA NAME:
  The name of your CA instance. You can get this from Windows Server's certsrv.
> URL OR IP of the Jamf AD CS Connector:
  If hosting on Jamf Cloud or connecting via a proxy: 
    This is the hostname that Jamf Pro will resolve to get the external IP of the Connector. 
    Add `":<portNumber>`" if you are not using 443. 
    E.g. https://$($Server_FQDNs[0]):${siteBind_Port} 
  If hosting Jamf Pro on-prem and conncting directly to ADCSC:
    https://$((Get-WmiObject win32_computersystem).DNSHostName).$((Get-WmiObject win32_computersystem).Domain):${siteBind_Port}

CERTIFICATES:
> Certificates Folder: ${SavedCertificatesFolder}
> SERVER CERTIFICATE: server-cert.cer"
> CLIENT CERTIFICATE: client-cert.pfx
  When prompted for the client certificate file password, enter: $Client_SelfSignedCertFilePass
"@

$serverIdentInfo = @"
The server.pfx file was also exported. This isn't uploaded to Jamf Pro when entering 
the Connector details. It can be used as the server cert if you need to set up a 
proxy or load balancer in front of the connector. You can also install it on other 
connector instances. The .pfx is locked with a password. 
> Server Identity File Name : server-cert.pfx
> Server Identity File Pass : $Server_IdentityFilePass
"@

  Write-Log "[note] ==================================================================================="
  Write-Log $summary
  if ($Server_IdentityFilePass) {
    Write-Log "[note] ==================================================================================="
    Write-Log $serverIdentInfo
  }
  Write-Log "[note] ==================================================================================="
  Write-Log $warning
}

# ===========================================================================
# Resource functions:

Function New-PasswordString {
  param(
    [Int]$Size = $defaultPasswordLength, 
    [Char[]]$CharSets = "ULNS", 
    [Char[]]$Exclude
  )
  # https://stackoverflow.com/a/37275209/821966
  $Chars = @();
  If (!$TokenSets) {
    $Global:TokenSets = @{
      U = [Char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                #Upper case
      L = [Char[]]'abcdefghijklmnopqrstuvwxyz'                                #Lower case
      N = [Char[]]'0123456789'                                                #Numerals
      S = [Char[]]'!"#$%&''()*+,-./:;<=>?@[\]^_`{|}~'                         #Symbols
    }
  }
  $CharSets | ForEach-Object {
    $Tokens = $TokenSets."$_" | ForEach-Object {If ($Exclude -cNotContains $_) {$_}}
    If ($Tokens) {
      $TokensSet += $Tokens
      # "cle" == case-sensitive <=. Character sets defined in upper case are mandatory
      If ($_ -cle [Char]"Z") {$Chars += $Tokens | Get-Random}
    }
  }
  While ($Chars.Count -lt $Size) {$Chars += $TokensSet | Get-Random}
  # Mix the (mandatory) characters and output string
  ($Chars | Sort-Object {Get-Random}) -Join ""
}

# ########################################################################################
## MAIN

Function Invoke-Main {
  # if($Debug) {Set-strictmode -version latest}
  $thisScript=($MyInvocation.MyCommand.Name) # (split-path $MyInvocation.PSCommandPath -Leaf) works in functions, but not in IDE
  #Starting from ps6, isWindows is a built-in var.
  $Is_Windows = ( [System.Environment]::OSVersion.Platform -eq "Win32NT" )
  Write-LogSection "[start] Running $thisScript"
  if($Debug) { "[info] Running in debug mode, Running on Windows : $Is_Windows" }
  # if($debug) { $PSBoundParameters }
  Test-Environment

  # If we are exporting any certs we'll need a folder in which to save them.  
  $timestamp = Get-Date -UFormat "%Y-%m-%dT%H%M"
  Write-LogDebug "[info] Timestamp for this run will be `"$timestamp`"."
  $SavedCertificatesFolder = "${CertificatesFolder}\${timestamp}"
  Write-LogDebug "[step] Creating a folder to save generated cert files: `"${SavedCertificatesFolder}`"."
  New-Item -Path "$CertificatesFolder" -Name "${timestamp}" -ItemType "directory"

  $returned = Set-UserVars `
    -AppPoolIdent_Type $AppPoolIdent_Type `
    -AppPoolIdent_User $AppPoolIdent_User `
    -AppPoolIdent_Pass $AppPoolIdent_Pass `
    -Client_MapCertToUser_Type $Client_MapCertToUser_Type `
    -Client_MapCertToUser_Name $Client_MapCertToUser_Name `
    -Client_MapCertToUser_Pass $Client_MapCertToUser_Pass
  $AppPoolIdent_Domain         = $returned.AppPoolIdent_Domain
  $Client_MapCertToUser_Domain = $returned.Client_MapCertToUser_Domain
  $Client_MapCertToUser_Name   = $returned.Client_MapCertToUser_Name
  $Client_MapCertToUser_Pass   = $returned.Client_MapCertToUser_Pass

  Install-IIS
  Import-Module WebAdministration
  Clear-IIS                     # Remove any existing connector app pool and/or site 
  Install-ADCSC                 # Unzip the connector files to target folder
  New-ADCSC_AppPool `
    -AppPoolIdent_Domain "$AppPoolIdent_Domain"
  $return = Set-ServerCert `
    -siteName                     $siteName `
    -Server_FQDNs                 $Server_FQDNs `
    -selfSignedCertValidityYears  $selfSignedCertValidityYears `
    -CertificatesFolder           $CertificatesFolder `
    -Server_SuppliedIdentFileName $Server_SuppliedIdentFileName `
    -Server_SuppliedIdentFilePass $Server_SuppliedIdentFilePass `
    -Server_ExportGeneratedIdent  $Server_ExportGeneratedIdent
  $Server_Identity_        = $return.Server_Identity_
  $Server_IdentityFilePass = $return.Server_IdentityFilePass

  New-ADCSC_Site -Server_Identity_ $Server_Identity_
  New-FirewallRule

  $returned = Set-JamfProAuthCert($Server_Identity_)
  $Client_SelfSignedCertFilePass = $returned.Client_SelfSignedCertFilePass
  $Client_MapCertToUser_base64   = $returned.Client_MapCertToUser_base64
  Set-ClientCertMapping `
   -Client_MapCertToUser_Domain "$Client_MapCertToUser_Domain" `
   -Client_MapCertToUser_Name   "$Client_MapCertToUser_Name" `
   -Client_MapCertToUser_Pass   "$Client_MapCertToUser_Pass" `
   -Client_MapCertToUser_base64 "$Client_MapCertToUser_base64"
  Write-SetupInfo `
    -Server_IdentityFilePass       "$Server_IdentityFilePass" `
    -Client_SelfSignedCertFilePass "$Client_SelfSignedCertFilePass"
  Write-LogSection "[end] Finished running $thisScript"
}

$VerbosePreference = 'SilentlyContinue'    
# $VerbosePreference = 'Continue'
$ErrorActionPreference = 'Stop'
Invoke-Main
