# Quick Jibri Installer
Bash installer for Jibri on **\*buntu LTS** based systems using **nginx** as default webserver.

## Requirements
* Clean VM/VPS/Server using Ubuntu LTS
* Valid domain with DNS record, **mandatory** for SSL certs via Let's Encrypt.
* Ports open for ACME (SSL) interaction & validation.
* Minimum recommended for video recording: 8 GB RAM / 2 Cores.
* Dropbox developer App key & redirect url configured (if you choose to enable local recording).
* Webcam

## Features
* Enabled Session (video) Recording using Jibri
* Enabled Jitsi Electron app detection server side.
* Standalone SSL Certbot/LE implementation
* Jigasi Transcript - Speech to Text powered by Google API
* (New) JRA (Jibri Recordings Access) via Nextcloud
* (New) Customized brandless mode
* (New) Improved recurring updater

### Jigasi Transcript
* SIP account
* Google Cloud Account with Billing setup.

### Jibri Recodings Access via Nextcloud
* Valid domain with DNS record for Nextcloud SSL.

## Optional custom changes
* Optional default language
* Option to enable Secure Rooms
* Option to enable Welcome Page
* Option to enable Local audio recording using flac.
* Option to use Rodentia static avatar (icon credit: sixsixfive).

## Custom changes
* Start with video muted by default
* Start with audio muted but moderator

* Set displayname as not required since jibri can't set it up.

## Documentation
* Please check our wiki for further documentation.

Please note: This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY.

SwITNet Ltd © - 2020, https://switnet.net/
