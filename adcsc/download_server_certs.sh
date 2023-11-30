#!/bin/bash

# Change the host-name and port below to your server then run the script. 
# The script will tell you about the server's trust cert and save the server's public cacert 
#   chain to your desktop. 

# We often use this script when we need to upload the trust chain for an LDAP server when setting up Jamf Pro

server='www.apple.com'
port='443'


# ==============================================================

echo "[start] Script will export the certificate chain for ${server} running on port ${port}..."
echo "[step] Downloading certs from the server..."
 
showcerts=$( echo | openssl s_client -showcerts -connect "${server}:${port}" -servername "${server}")

if [[ $? ]]; then
  echo "[OK] openssl"
else
  echo "[error] openssl"
fi

echo "============================================================================="
echo "output of openssl -showcerts"
echo "============================================================================="
echo "$showcerts"
echo "============================================================================="
echo "============================================================================="


# Make a folder to save the new identity keypair we're creating... 
pathToMe="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
now=$( date +%Y-%m-%d_%H-%M-%S )
serverNoDots=$(echo "$server" | tr "." "-" )
timeStamp=$(date +"%Y-%m-%d_%H-%M-%S")
saveToFolder="${pathToMe}/Certchain for ${server} ${timeStamp}" 
echo "[info] The trust chain certificates will be saved to :"
echo "${saveToFolder}"
mkdir "$saveToFolder"
cd "$saveToFolder"
open "${saveToFolder}"
echo

  
echo "[step] Saving certs to files..."
echo "$showcerts" | awk '/BEGIN /,/END /{ if(/BEGIN/){filenum++}; out="cert"filenum".cer"; print >out}'
echo
echo "[info] Here is the trust chain for this server:"
echo "$showcerts" | grep 'depth'
echo

echo "[step] Combining the individual certificate into a single .pem"
combinedCerFileName="Combined ${server} Certificate Trust Chain.pem"
find . -name "*.cer" -o -name "cert*.cer" | xargs cat > "$combinedCerFileName"

echo "[step] Renaming the exported certificate files as their certificate's subject..."
 
for certfile in *.cer; do
  [ -f "$certfile" ] || continue
  newname=$( openssl x509 -noout -subject -in "$certfile" | sed -n 's/^.*CN=\(.*\)$/\1/; s/[ ,.*]/_/g; s/__/_/g; s/^_//g;p')
  newname=${newname//_-_/-}
  newname="Individual ${newname} Certificate.cer"
  echo "Renaming $certfile to \"${newname}\""
  mv "$certfile" "$newname"
done
 
#  After combining the ASCII data into one file, verify validity of certificate chain for sslserver usage:
openssl verify -verbose -purpose sslserver "$combinedCerFileName"

 
echo '-end-'
 
exit 0

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