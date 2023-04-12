#!/bin/sh -xe
# Script to install Qt 6 in docker container

[ "$AQT_VERSION" ] || AQT_VERSION=aqtinstall
[ "$QT_VERSION" ] || exit 1

[ "$QT_PATH" ] || QT_PATH=/opt/Qt

root_dir=$PWD
[ "$root_dir" != '/' ] || root_dir=""

# Init the package system
apt update

echo
echo '--> Save the original installed packages list'
echo

dpkg --get-selections | cut -f 1 > /tmp/packages_orig.lst

echo
echo '--> Install the required packages to install Qt'
echo

apt install -y git python3-pip libglib2.0-0
pip3 install --no-cache-dir "$AQT_VERSION"

echo
echo '--> Download & install the Qt library using aqt'
echo

aqt install-qt -O "$QT_PATH" linux desktop "$QT_VERSION" wasm_singlethread  -m qtcharts qtquick3d qtshadertools qtdatavis3d
aqt install-tool -O "$QT_PATH" linux desktop tools_cmake
aqt install-tool -O "$QT_PATH" linux desktop tools_ninja
# Host Qt needed for cross-compilation
aqt install-qt -O "$QT_PATH" linux desktop "$QT_VERSION" gcc_64  -m qtcharts qtquick3d qtshadertools qtdatavis3d

pip3 freeze | xargs pip3 uninstall -y

# Create qt-cmake wrapper to simplify the emsdk usage
mkdir -p /usr/local/bin
cat - <<\EOF > /usr/local/bin/qt-cmake
#!/bin/sh -e

export CMAKE_TOOLCHAIN_FILE=$QT_WASM/lib/cmake/Qt6/qt.toolchain.cmake
exec cmake "-DQT_HOST_PATH=$(dirname "$QT_WASM")/gcc_64" "$@"
EOF

chmod +x /usr/local/bin/*

echo
echo '--> Restore the packages list to the original state'
echo

dpkg --get-selections | cut -f 1 > /tmp/packages_curr.lst
grep -Fxv -f /tmp/packages_orig.lst /tmp/packages_curr.lst | xargs apt remove -y --purge

# Complete the cleaning

apt -qq clean
rm -rf /var/lib/apt/lists/*