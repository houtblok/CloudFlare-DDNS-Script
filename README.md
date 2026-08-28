# CloudFlare DDNS Script

<img width="360" alt="image" src="https://upload.wikimedia.org/wikipedia/commons/4/4b/Cloudflare_Logo.svg?utm_source=commons.wikimedia.org&utm_campaign=index&utm_content=original" />

The script is a Dynamic DNS updater for CloudFlare. It makes sure that your provided DNS records always point to your current public IPv4 address.

I made this solution because I found existing solutions to be too much of a hassle to set up (requiring manual lookup of hidden Record IDs and Zone IDs for each domain through the API) or requiring many dependencies.

This script is designed to be simple to use, you only need to provide the following:
```
- CloudFlare API Token (with DNS -> Edit permissions)
- Your domain name(s)
```
The script will automatically do the rest for you.

It runs with minimal package requirement, and works with only curl and jq installed.

It can be configured to scheduled every 5 minutes or as desired.

# Installation

## 1. Create the secure CloudFlare Token and configuration

Create an API Token in the [CloudFlare Dashboard](https://dash.cloudflare.com/profile/api-tokens), and for each domain zone you want to include, give it the permission:
```
Zone
 └── DNS
      └── Edit
```
Then, create the configuration file:
```
sudo nano /etc/cloudflare-ddns.conf
```
Use the [cloudflare-ddns.conf configuration](https://github.com/houtblok/CloudFlare-DDNS-Script/blob/main/cloudflare-ddns.conf) in the repository.

Replace the two hostnames with your actual DNS records.

Secure the file:
```
sudo chown root:root /etc/cloudflare-ddns.conf
sudo chmod 600 /etc/cloudflare-ddns.conf
```
This means only root can read the Cloudflare API token.

## 2. Create the DDNS script

Create:
```
sudo nano /usr/local/bin/cloudflare-ddns.sh
```
Use the [cloudflare-ddns.sh script](https://github.com/houtblok/CloudFlare-DDNS-Script/blob/main/cloudflare-ddns.sh) in the repository.

Make it executable:
```
sudo chmod 700 /usr/local/bin/cloudflare-ddns.sh
sudo chown root:root /usr/local/bin/cloudflare-ddns.sh
```
## 3. Install the required packages

On Debian/Ubuntu:
```
sudo apt update
sudo apt install curl jq
```
## 4. Test the script

Before relying on the timer, run:
```
sudo /usr/local/bin/cloudflare-ddns.sh
```
You should get something like:
```
Current public IP: 123.123.123.123

Checking home.example.com...
Cloudflare IP: 123.123.123.123
IP has not changed.

Checking home.example.nl...
Cloudflare IP: 123.123.123.123
IP has not changed.
```
If your IP has changed, you'll instead see:
```
Checking home.example.com...
Cloudflare IP: 111.111.111.111
IP changed!
Updating home.example.com: 111.111.111.111 -> 123.123.123.123
Successfully updated home.example.com to 123.123.123.123
```
# Setup automated runs

## 1. Create the systemd service

Create:
```
sudo nano /etc/systemd/system/cloudflare-ddns.service
```
Add:
```
[Unit]
Description=Cloudflare Dynamic DNS Updater
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cloudflare-ddns.sh

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
```
The service doesn't need to run continuously; it starts the script, updates/checks the DNS records, and exits.

## 2. Create the 5-minute systemd timer

Create:
```
sudo nano /etc/systemd/system/cloudflare-ddns.timer
```
Add:
```
[Unit]
Description=Run Cloudflare DDNS updater every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=cloudflare-ddns.service

[Install]
WantedBy=timers.target
```

## 3. Enable the timer

Run:
```
sudo systemctl daemon-reload
sudo systemctl enable --now cloudflare-ddns.timer
```
Check it:
```
systemctl status cloudflare-ddns.timer
```
You should see something like:
```
Active: active (waiting)
```
You can also check when it will run next:
```
systemctl list-timers cloudflare-ddns.timer
```
## 4. Check the automatic runs

View the service logs:
```
sudo journalctl -u cloudflare-ddns.service
```
Follow them live:
```
sudo journalctl -u cloudflare-ddns.service -f
```
Show only the last 20 runs:
```
sudo journalctl -u cloudflare-ddns.service -n 20
```
# Final remark

One thing to be aware of

The script currently sets:
```
"proxied": true
```
for the records. That's if you want the records to use Cloudflare's proxy (orange cloud).

If the records are for something like SSH, WireGuard, a game server, a mail server, or another service that requires the real IP, you generally want the following instead:
```
"proxied": false
```
