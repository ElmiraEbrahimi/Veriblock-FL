# Server Deployment (Ubuntu Server)

## Server Security

### Non-root Sudo User

Create a non-root sudo user (we named it `toor`).

### General

- Update and upgrade regularly: `sudo apt update && sudo apt upgrade`
- Power off the server when not in use to avoid getting attacks.

### SSH-KEYGEN

Create private/public SSH key locally and copy the KEY.pub to .ssh folder of `toor` user.

### SSH Connection

- Test connecting with the new created user and the new generated SSH key before disabling the access.
- Disable `root` SSH remote access.
- Disable password logins.
- Set login limit.
- Change default SSH port.

### Firewall

Exclude ssh port and enable.

Note: `ufw` won't work with Docker (yet).

## Prerequisites

### Essentials

- First update and upgrade packages: `sudo apt update && sudo apt upgrade`
- Now install essentials: `sudo apt install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev git` and `sudo apt install software-properties-common`.

### OMZ (Optional)

Visit: <https://ohmyz.sh/>

### Python

- Install python3.9: `sudo apt install python3.9`
- Change the default python to python3.9.
- Install venv: `sudo apt install python3-venv`
- Check the version: `python -V`.

### Docker

Visit: <https://docs.docker.com/engine/install/ubuntu/>

### Node

- Install: `sudo apt install nodejs`
- Check version: `node -v`

### Zokrates

- Install: `curl -LSfs get.zokrat.es | sh`
- Set env var: export `PATH=$PATH:/home/toor/.zokrates/bin`
- Add `PATH=$PATH:/home/toor/.zokrates/bin` to the end of the file in `.zshrc` - if omz is installed (see above sections)

## Project

- Generate a GitHub deploy token for the server. Visit: <https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys>
- Clone the project via SSH and the generated token.
- Set a virtual environment and enable it.

## VSCode (Optional)

- Add `Remote Explorer` and `Remote - SSH` extensions.
- Create a new remote from the extension and connect to the server.

Done!