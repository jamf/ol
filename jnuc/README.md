# Network Notes


wifi: 
jnuc_labs / ilabs2019

Lab Laptops Login
User: jnuc_labs
Password: Jamf

Enroll your own (if you're not already)
https://jnucinteractivelabs.jamfcloud.com
User: e 
Password: e

Open in a browser:
http://jamf.it/notebook


## Terminal Commands

### 12
$ sudo echo
$ echo Hi
$ echo 'hi
there' | grep hi

### 13
$ ping -c 2 1.1.1.1
$ ping -c 2 one.one.one.one

### 15
$ route -n get jamf.com | grep 'interface'

### 16
$ ipconfig getifaddr en0 
$ ifconfig en0 | grep 'inet'
$ dig +short myip.opendn .com
$ curl ifconfig.me

### 17
dig apple.com

### 18
$ traceroute google.com

### 19
$ whois 1e100.net | grep Registrant 

### 20
nc -z 1-courier.push.apple.com 5223

### 21
$ nc -z ad.my.org 389
$ nc -z ad.my.org 636

### 22
$ nc -l 9999
⌘T    (To simulate remote)
$ nc -z localhost 9999

### 23
$ nc -l 9999 > loveletter.txt
$ cat loveletter.txt | nc host 9999

### 24
$ netstat -f inet | grep "17\."

### 26
$ lsof -i4TCP | grep LISTEN

### 27
$ curl https://github.com/macnotes/jnuc/blob/master/README.md > ~/Desktop/notebook.md

### 31
$ echo | openssl s_client -showcerts -connect "jamfse.io:636"




### openssl

This command will show information about the certificate trust chain on a server. You can use it on any server that uses TLS, not just web servers. 
```bash
echo | openssl s_client -showcerts -connect "${server}:${port}"
```

Some servers host more than one site ("SNI"). In this case, add the -servername parameter...
```bash
echo | openssl s_client -showcerts -connect "${server}:${port}" -servername "${server}"
```

This resource has endpoints with many possible TLS certificate issues. It is useful for observing the output produced in different configuration errors so you can compare to your servers: 
badssl.com - https://badssl.com
