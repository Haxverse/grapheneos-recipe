#!/bin/bash -i
#
set -o pipefail
set -e

set_vars() {
   export DEBIAN_FRONTEND=noninteractive
   export OFFICIAL_BUILD=true
   export ORIG_UPDATE_URL=https://releases.grapheneos.org
   export BUILD_NUMBER=`curl -s $ORIG_UPDATE_URL/$DEVICE-$CHANNEL | awk '{print $1}'`
   export BUILD_DATETIME=`curl -s $ORIG_UPDATE_URL/$DEVICE-$CHANNEL | awk '{print $2}'`
}

unzip_keys() {
   cd /root
   cp $ANDROID_CERTS certs.zip
   rm -rf .android-certs
   mkdir -p .android-certs
   mv certs.zip .android-certs/certs.zip
   cd .android-certs
   unzip certs.zip
   rm -rf certs.zip
   cd /ham-build
}

install_deps() {
   curl -fsSL https://rclone.org/install.sh | bash
   curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg
   echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | tee /etc/apt/sources.list.d/yarn.list
   curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
   echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
   chmod 644 /usr/share/keyrings/nodesource.gpg
   chmod 644 /usr/share/keyrings/yarnkey.gpg
   apt update && apt install -y -qq nodejs yarn python-is-python3 tmux wget unzip python3 diffutils fontconfig openssl signify-openbsd python3-protobuf e2fsprogs repo e2fsprogs jq openssh-client
   git config --global user.email \"you@example.com\"
   git config --global user.name \"Your Name\"
   git config --global color.ui false
   ln -s /usr/bin/signify-openbsd /usr/local/bin/signify
}

apply_patches() {
   sed -i -e "s|$ORIG_UPDATE_URL|$UPDATE_URL|g" "packages/apps/Updater/res/values/config.xml"
}

download_source() {
   set_vars
   repo init -u https://github.com/GrapheneOS/platform_manifest.git -b refs/tags/$BUILD_NUMBER
   curl -s https://grapheneos.org/allowed_signers > ~/.ssh/grapheneos_allowed_signers
   cd .repo/manifests
   git config gpg.ssh.allowedSignersFile ~/.ssh/grapheneos_allowed_signers
   git verify-tag $(git describe)
   cd ../..
   repo sync -c
   apply_patches
}

download_vendor() {
   yarn install --cwd vendor/adevtool/
   source build/envsetup.sh
   lunch sdk_phone64_x86_64-cur-user
   m aapt2
   vendor/adevtool/bin/run generate-all -d $DEVICE
}

build_source() {
   source build/envsetup.sh
   lunch $DEVICE-cur-user
   set_vars
   rm -rf out
   if [[ $DEVICE == @(akita|tokay|caiman|komodo|comet) ]]; then
      m target-files-package
   elif [[ $DEVICE == @(oriole|raven|bluejay) ]]; then
      m vendorbootimage target-files-package
   elif [[ $DEVICE == @(panther|cheetah|lynx|tangorpro|felix|shiba|husky) ]]; then
      m vendorbootimage vendorkernelbootimage target-files-package
   else
      echo "$DEVICE is not supported by the release script"
      exit -1
   fi
}

build_releases() {
   set_vars
   mkdir -p keys/$DEVICE
   cp -r /root/.android-certs/* keys/$DEVICE
   mkdir -p /ham-output
   m otatools-package
   script/finalize.sh
   echo "" | script/generate-release.sh $DEVICE $BUILD_NUMBER

   if [ -d /ham-build/releases/$BUILD_NUMBER/release-$DEVICE-$BUILD_NUMBER ]; then
      echo "Done!"
      cp -r /ham-build/releases/$BUILD_NUMBER/release-$DEVICE-$BUILD_NUMBER/$DEVICE-install-$BUILD_NUMBER.zip /ham-build/releases/$BUILD_NUMBER/release-$DEVICE-$BUILD_NUMBER/$DEVICE-install-$BUILD_NUMBER.zip.sig /ham-build/releases/$BUILD_NUMBER/release-$DEVICE-$BUILD_NUMBER/$DEVICE-ota_update-$BUILD_NUMBER.zip /ham-build/releases/$BUILD_NUMBER/release-$DEVICE-$BUILD_NUMBER/$DEVICE-$CHANNEL /ham-output
      exit 0
   else
      echo "ERROR: Release folder (/ham-build/out/release-$DEVICE-$BUILD_NUMBER) not found!"
      exit -1
   fi
}

set_vars
unzip_keys
install_deps

for DEVICE in $DEVICES; do
   download_source
   download_vendor

   build_source
   build_releases
done
