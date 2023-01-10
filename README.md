# Quick Jibri Installer
Bash installer for Jitsi Meet standalone along with Jibri on supported **Ubuntu LTS** based systems using **nginx** as default webserver.

## Usage
As for our current latest release, as we have integrated more and more features, we highly recommend to use a **purpose specific-newly spawn server** to host the jitsi-meet framework, making sure you stick to the requirements and recommendations as much as possible, in order to avoid issues.

**WARNING:** Please, avoid using this installer on your everyday GNU/Linux system, as this is an unsupported use and it will likely BREAK YOUR SYSTEM, so please don't.


### Main Server
Login into your clean server, clone git repository and run the installer,

```
git clone https://github.com/codex-ist/quick-jibri-installer
cd quick-jibri-installer
sudo bash quick_jibri_installer.sh
```
![QJI - Setup](https://raw.githubusercontent.com/wiki/switnet-ltd/quick-jibri-installer/images/qji-diagram-setup.png)

If your server meet the necessary resources, then at the end on the installer you should have a working Jitsi Meet Server along with a Jibri server ready to record.

Additional jibris need to be set on separate servers, only necesary on simultaneous recordings for that please use add-jibri-node.sh.

### Add Jibri node

Copy the modified `add-jibri-node.sh` file from your early cloned installation directory once the installation is completed, to the new server meant to be a jibri node using your preferred method, then run it

**WARNING:** This file contains sensitive information from your setup, please handle with care.

```
bash add-jibri-node.sh
```

Please remember that on newer versions, jibri will record on FHD (1920x1080) so please make sure your server have enough CPU power in orther to handle the encoding load.

### Add JVB2 node

Copy the modified `add-jvb2-node.sh` file from your early cloned installation directory once the installation is completed, to the new server meant to be a jibri node using your preferred method, then run it

**WARNING:** This file contains sensitive information from your setup, please handle with care.

```
bash add-jvb2-node.sh
```

Check more details on our wiki.

## Requirements
1. Clean VM/VPS/Server using a supported Ubuntu LTS
2. Valid domain with DNS record, **mandatory** for SSL certs via Let's Encrypt.
3. open ports for JMS interaction.
4. Starting at 8 GB RAM / 4 Cores @ ~3.0GHz
    *  Adding resources as your audience or features you require, so your experience don't suffer from the lack of resources.
5. Webcam

### Jibri Recodings Access via Nextcloud
* Valid domain with DNS record for Nextcloud SSL.
 
### Jigasi Transcript (stalled)
* SIP account
* Google Cloud Account with Billing setup.



## Kernel warning
For AWS users or any cloud service provider that might use their own kernel on their products (servers/vm/vps), might cause Jibri failure to start due not allowing `snd_aloop` module.

Make sure that you update your grub to boot the right one.

Feel free to use our `test-jibri-env.sh` tool to find some details on your current setup.

## Features
* Enabled Session Recording via Jibri
  * Rename Jibri folder with name room + date.
  * Jibri node network.
    * Automatic Jibri nodes network sync.
* JRA (Jibri Recordings Access) via Nextcloud
* Grafana Dashboard
* Etherpad via docker install
* Authentication
  1. Local
  2. JWT
  3. None
* Lobby Rooms
* Conference Duration
* Customized brandless mode
  * Setting up custom interface_config.js (to be deprecated by upstream)
* JVB2 nodes network.

* Enabled Jitsi Electron app detection server side.
* Standalone SSL Certbot/LE implementation
* Improved recurring updater
* Jigasi Transcript - Speech to Text powered by Google API (stalled)

## Tools
* Jibri Environment Tester
 * Jibri Conf Upgrader (late 2020).
* Selenium Grid via Docker
* Start over, installation cleansing tool.

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

Please note: This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY.

