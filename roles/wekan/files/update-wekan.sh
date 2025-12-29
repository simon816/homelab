#!/bin/bash

set -ex

sudo rm -rf /tmp/wekan-update
mkdir /tmp/wekan-update
cd /tmp/wekan-update

latest=$(curl -s https://api.github.com/repos/wekan/wekan/tags | python3 -c 'import json, sys; print(json.load(sys.stdin)[0]["name"])')
filename="wekan-$(echo $latest | sed s/^v//)-amd64.zip"

wget "https://github.com/wekan/wekan/releases/download/$latest/$filename"

mkdir extract
sudo chown www-data:www-data extract
sudo -u www-data unzip $filename -d extract
sudo systemctl stop wekan

sudo rm -rf /var/www/wekan/
sudo mv extract/bundle/ /var/www/wekan

cd /var/www/wekan/programs/server

sudo rm -rf /tmp/wekan-update

sudo rm node_modules/.bin/node-pre-gyp \
    node_modules/.bin/node-gyp \
    node_modules/.bin/detect-libc
sudo -u www-data NPM_CONFIG_CACHE=/tmp/npmcache npm install node-gyp node-pre-gyp fibers
sudo -u www-data NPM_CONFIG_CACHE=/tmp/npmcache npm audit fix
sudo -u www-data NPM_CONFIG_CACHE=/tmp/npmcache npm install
sudo systemctl restart wekan
