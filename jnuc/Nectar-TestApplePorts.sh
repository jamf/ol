#!/bin/bash
​
output="/tmp/ports.txt"
touch "$output"
echo "--Various Ports--" >> "$output"
nc -vz gateway.push.apple.com 2195 >> "$output" 2>&1
nc -vz gateway.sandbox.push.apple.com 2195 >> "$output" 2>&1
nc -vz gateway.push.apple.com 2196 >> "$output" 2>&1
nc -vz gateway.sandbox.push.apple.com 2196 >> "$output" 2>&1
nc -vz 35-courier.push.apple.com 5223 >> "$output" 2>&1
nc -vz deploy.apple.com 443 >> "$output" 2>&1
echo "--Port 80 Below--" >> "$output" 2>&1
nc -vz hrweb.cdn-apple.com 80 >> "$output" 2>&1
nc -vz itunes.apple.com 80 >> "$output" 2>&1
nc -vz mzstatic.com 80 >> "$output" 2>&1
nc -vz appldnld.apple.com 80 >> "$output" 2>&1
nc -vz gg.apple.com 80 >> "$output" 2>&1
nc -vz gs.apple.com 80 >> "$output" 2>&1
nc -vz itunes.apple.com 80 >> "$output" 2>&1
nc -vz mesu.apple.com 80 >> "$output" 2>&1
nc -vz swscan.apple.com 80 >> "$output" 2>&1
nc -vz xp.apple.com 80 >> "$output" 2>&1
nc -vz configuration.apple.com 80 >> "$output" 2>&1
echo "--Port 443 Below --" >> "$output" 2>&1
nc -vz hrweb.cdn-apple.com 443 >> "$output" 2>&1
nc -vz itunes.apple.com 443 >> "$output" 2>&1
nc -vz mzstatic.com 443 >> "$output" 2>&1
nc -vz albert.apple.com 443 >> "$output" 2>&1
nc -vz appldnld.apple.com 443 >> "$output" 2>&1
nc -vz gg.apple.com 443 >> "$output" 2>&1
nc -vz gs.apple.com 443 >> "$output" 2>&1
nc -vz itunes.apple.com 443 >> "$output" 2>&1 2>&1
nc -vz skl.apple.com 443 >> "$output" 2>&1 2>&1
nc -vz mesu.apple.com 443 >> "$output" 2>&1
nc -vz swscan.apple.com 443 >> "$output" 2>&1
nc -vz xp.apple.com 443 >> "$output" 2>&1
nc -vz configuration.apple.com 443 >> "$output" 2>&1
​
 echo "Done"
