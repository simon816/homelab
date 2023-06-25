#!/bin/bash

set -ex

sudo rm -rf /tmp/wekan-update
mkdir /tmp/wekan-update
cd /tmp/wekan-update
wget https://releases.wekan.team/SHA256SUMS.txt
wget https://releases.wekan.team/wekan-latest-amd64.zip
sed -i 's/wekan-.*\.zip$/wekan-latest-amd64.zip/; /\.zip$/! d' 'SHA256SUMS.txt'
sha256sum -c SHA256SUMS.txt

mkdir extract
sudo chown www-data:www-data extract
sudo -u www-data unzip wekan-latest-amd64.zip -d extract
sudo systemctl stop wekan

sudo rm -rf /var/www/wekan/
sudo mv extract/bundle/ /var/www/wekan

cd /var/www/wekan/programs/server

sudo rm -rf /tmp/wekan-update

sudo rm node_modules/.bin/node-pre-gyp node_modules/.bin/node-gyp node_modules/.bin/detect-libc node_modules/node-gyp/node_modules/.bin/semver node_modules/@npmcli/fs/node_modules/.bin/semver
sudo -u www-data NPM_CONFIG_CACHE=/tmp/npmcache npm install node-gyp node-pre-gyp fibers
sudo -u www-data NPM_CONFIG_CACHE=/tmp/npmcache npm audit fix
sudo -u www-data NPM_CONFIG_CACHE=/tmp/npmcache npm install
sudo systemctl restart wekan
