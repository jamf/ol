# Credit: cbrewer/Jamf Nation
# https://stackoverflow.com/questions/24672760/powershells-invoke-restmethod-equivalent-of-curl-u-basic-authentication

function checkJamfAuthToken {
  if (!$authTokenData) {
    # We don't have an auth token
    Write-Host 'Getting new Jamf authorization token... ' -NoNewline
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $jamfUser,$jamfPass)))
    $script:authTokenData = Invoke-RestMethod -Uri "$jamfUrl/api/v1/auth/token" -Credential $creds -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method Post
    $script:authToken = $authTokenData.token
    $script:authTokenExpireDate = Get-Date "$($authTokenData.expires)"
    Write-Host 'Done.'
  } elseif($(Get-Date).AddMinutes(5) -gt $authTokenExpireDate) {
    # Update token if it expires in 5 minutes or less
    Write-Host 'Renewing Jamf authorization token... ' -NoNewline
    $script:authTokenData = Invoke-RestMethod -Uri "$jamfUrl/api/v1/auth/keep-alive" -Headers $jamfApiHeaders -Method Post
    $script:authToken = $authTokenData.token
    $script:authTokenExpireDate = Get-Date "$($authTokenData.expires)"
    Write-Host 'Done.'
  }

  $script:jamfApiHeaders = @{
    Authorization="Bearer $authToken"
    Accept="application/json"
  }
}
