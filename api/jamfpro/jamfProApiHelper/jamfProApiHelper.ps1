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