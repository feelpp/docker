export QT_VERSION=6.5.0
export QT_PATH=/opt/Qt

export SDK_PATH=/opt/emsdk
export SDK_VERSION=3.1.25
export SDK_SHA256=b8772e32043905b3af4b926f54ac7ca3faf5d5eb93105973c85c56ec60c832d5

export ADDITIONAL_PACKAGES="sudo git openssh-client ca-certificates curl python3 locales"


export DEBIAN_FRONTEND=noninteractive 
export DEBCONF_NONINTERACTIVE_SEEN=true
export QT_PATH=${QT_PATH}
export QT_WASM=${QT_PATH}/${QT_VERSION}/wasm_singlethread
export EMSDK=${SDK_PATH}
export EMSDK_NODE=${SDK_PATH}/node/14.18.2_64bit/bin/node
export PATH=$PATH:${QT_PATH}/Tools/CMake/bin:${QT_PATH}/Tools/Ninja:${QT_PATH}/${QT_VERSION}/wasm_singlethread/bin:${SDK_PATH}/upstream/bin:${SDK_PATH}/upstream/emscripten:${SDK_PATH}/node/14.18.2_64bit/bin:${SDK_PATH}

dirname=$(dirname "$0")

# Install emscripten
sh $dirname/get_emsdk.sh

# Get Qt binaries with aqt
sh $dirname/get_qt.sh

# Install the required packages
sh $dirname/install_packages.sh
