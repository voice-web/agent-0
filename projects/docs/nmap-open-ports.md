# Nmap open ports (worldcliques.org)

Raw Nmap output captured on `2026-03-31 22:28 -0400` for `worldcliques.org` (`141.148.57.20`).

```text
PORT    STATE SERVICE
21/tcp  open  ftp
22/tcp  open  ssh
80/tcp  open  http
110/tcp open  pop3
143/tcp open  imap
443/tcp open  https
993/tcp open  imaps
995/tcp open  pop3s

PORT    STATE SERVICE    VERSION
21/tcp  open  ftp?
22/tcp  open  ssh        OpenSSH 8.7 (protocol 2.0)
80/tcp  open  http-proxy WatchGuard http proxy
110/tcp open  ssl/pop3?
143/tcp open  ssl/imap?
443/tcp open  ssl/https?
993/tcp open  ssl/imaps?
995/tcp open  ssl/pop3s?

Starting Nmap 7.99 ( https://nmap.org ) at 2026-03-31 22:28 -0400
Stats: 0:00:03 elapsed; 0 hosts completed (0 up), 0 undergoing Script Pre-Scan
NSE Timing: About 0.00% done
Nmap scan report for worldcliques.org (141.148.57.20)
Host is up (0.0045s latency).
Not shown: 992 filtered tcp ports (no-response)
PORT    STATE SERVICE
21/tcp  open  ftp
22/tcp  open  ssh
80/tcp  open  http
|_http-dombased-xss: Couldn't find any DOM based XSS.
|_http-aspnet-debug: ERROR: Script execution failed (use -d to debug)
|_http-csrf: Couldn't find any CSRF vulnerabilities.
|_http-vuln-cve2014-3704: ERROR: Script execution failed (use -d to debug)
|_http-stored-xss: Couldn't find any stored XSS vulnerabilities.
110/tcp open  pop3
143/tcp open  imap
443/tcp open  https
|_http-vuln-cve2014-3704: ERROR: Script execution failed (use -d to debug)
|_http-aspnet-debug: ERROR: Script execution failed (use -d to debug)
|_http-csrf: Couldn't find any CSRF vulnerabilities.
|_http-dombased-xss: Couldn't find any DOM based XSS.
|_ssl-ccs-injection: No reply from server (TIMEOUT)
|_http-stored-xss: Couldn't find any stored XSS vulnerabilities.
993/tcp open  imaps
|_ssl-ccs-injection: No reply from server (TIMEOUT)
995/tcp open  pop3s
|_ssl-ccs-injection: No reply from server (TIMEOUT)
```

