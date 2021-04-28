# Quick Jibri Installer
Bash installer for Jibri on supported **Ubuntu LTS** based systems using **nginx** as default webserver.

## Usage
As for our current latest release, as we have integrated more and more features, we highly recommend to use a purpose specific-newly spawn server to host the jitsi-meet framework, making sure you stick to the requirements and recommendations as much as possible, in order to avoid issues.


### Main Server
Login into your clean server, clone git repository and run the installer,

```
git clone https://github.com/switnet-ltd/quick-jibri-installer
cd quick-jibri-installer
bash quick-jibri-installer.sh
```

### Add Jibri node

Copy the modified `add-jibri-node.sh` file from your early cloned installation directory once the installation is completed, to the new server meant to be a jibri node using your preferred method, then run it

**WARNING:** This file contains sensitive information from your setup, please handle with care.

```
bash add-jibri-node.sh
```

### Add JVB2 node

Copy the modified `add-jvb2-node.sh` file from your early cloned installation directory once the installation is completed, to the new server meant to be a jibri node using your preferred method, then run it

**WARNING:** This file contains sensitive information from your setup, please handle with care.

```
bash add-jvb2-node.sh
```

Check more details on our wiki.

## Requirements
* Clean VM/VPS/Server using a supported Ubuntu LTS
* Valid domain with DNS record, **mandatory** for SSL certs via Let's Encrypt.
* Ports open for ACME (SSL) interaction & validation.
* Highly recommended: 8 GB RAM / 4 Cores.
* Webcam

### Jigasi Transcript
* SIP account
* Google Cloud Account with Billing setup.

### Jibri Recodings Access via Nextcloud
* Valid domain with DNS record for Nextcloud SSL.

## Kernel warning
For AWS users or any cloud service provider that might use their own kernel on their products (servers/vm/vps), might cause Jibri failure to start due not allowing `snd_aloop` module.

Make sure that you update your grub to boot the right one.

Feel free to use our `test-jibri-env.sh` tool to find some details on your current setup.

## Features
* Enabled Session Recording using Jibri
* Enabled Jitsi Electron app detection server side.
* Standalone SSL Certbot/LE implementation
* Jigasi Transcript - Speech to Text powered by Google API (stalled)
* JRA (Jibri Recordings Access) via Nextcloud
* Improved recurring updater
* Customized brandless mode
  * Setting up custom interface_config.js (to be deprecated by upstream)
* Grafana Dashboard
* Lobby Rooms via
* Conference Duration via
* Automatic Jibri nodes network sync ([see more](https://github.com/switnet-ltd/quick-jibri-installer/wiki/Setup-and-Jibri-Nodes)).
* JVB2 nodes network.
* JWT auth.
* Rename Jibri folder with name room + date.

## Tools
* Jibri Environment Tester
 * Jibri Conf Upgrader (late 2020).
* Selenium Grid via Docker

## Optional custom changes
* Optional default language
* Option to enable Secure Rooms
* Option to enable Welcome page
* Option to enable Close page
* Option to set domain as hostname on JMS

### Modes
* Custom High Performance config

## Custom changes
* Start with video muted by default
* Start with audio muted but moderator
* Set pre-join screen by default.


## Documentation
* Please check our [wiki](https://github.com/switnet-ltd/quick-jibri-installer/wiki) for further documentation.

Please note: This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY.

SwITNet Ltd © - 2021, https://switnet.net/
