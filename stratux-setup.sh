# Copyright (c) 2016 Joseph D Poirier
# Distributable under the terms of The New BSD License
# that can be found in the LICENSE file.


BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)


if [ $(whoami) != 'root' ]; then
    echo "${BOLD}${RED}This script must be executed as root, exiting...${WHITE}${NORMAL}"
    exit
fi


SCRIPTDIR="`pwd`"

#set -e

#outfile=setuplog
#rm -f $outfile

#exec > >(cat >> $outfile)
#exec 2> >(cat >> $outfile)

#### stdout and stderr to log file
#exec > >(tee -a $outfile >&1)
#exec 2> >(tee -a $outfile >&2)

#### execute the script: bash stratux-setup.sh

#### Revision numbers found via cat /proc/cpuinfo
# [Labeled Section]                                       [File]
# Dependencies                                          - stratux-setup.sh
# Hardware check                                        - stratux-setup.sh
# Setup /etc/hostapd/hostapd.conf                       - wifi-ap.sh
# Edimax WiFi check                                     - stratux-wifi.sh
# Boot config settings                                  - rpi.sh
# RPi 0/2 check to enable Edimax wifi dongle option     - rpi.sh
#
RPI0xREV=900092
RPI0yREV=900093

RPI2BxREV=a01041
RPI2ByREV=a21041

RPI3BxREV=a02082
RPI3ByREV=a22082

ODROIDC2=020b

#### unchecked
RPIBPxREV=0010
RPIAPxREV=0012
RPIBPyREV=0013

REVISION="$(cat /proc/cpuinfo | grep Revision | cut -d ':' -f 2 | xargs)"


# Processor 
# [Labeled Section]                                       [File]
# Go bootstrap compiler installation                    - stratux-setup.sh
#
ARM6L=armv6l
ARM7L=armv7l
ARM64=aarch64

MACHINE="$(uname -m)"

# Edimax WiFi dongle
EW7811Un=$(lsusb | grep EW-7811Un)


echo "${MAGENTA}"
echo "************************************"
echo "**** Stratux Setup Starting... *****"
echo "************************************"
echo "${WHITE}"

if which ntp >/dev/null; then
    ntp -q -g
fi


##############################################################
##  Stop exisiting services
##############################################################
echo
echo "${YELLOW}**** Stop exisiting services... *****${WHITE}"

if [ -f "/etc/init.d/stratux" ]; then
    service stratux stop
    echo "${MAGENTA}stratux service found and stopped...${WHITE}"
fi

if [ -f "/etc/init.d/hostapd" ]; then
    service hostapd stop
    echo "${MAGENTA}hostapd service found and stopped...${WHITE}"
fi

if [ -f "/etc/init.d/isc-dhcp-server" ]; then
    service isc-dhcp-server stop
    echo "${MAGENTA}isc-dhcp service found and stopped...${WHITE}"
fi

echo "${GREEN}...done${WHITE}"


##############################################################
##  Dependencies
##############################################################
echo
echo "${YELLOW}**** Installing dependencies... *****${WHITE}"

if [ "$REVISION" == "$RPI2BxREV" ] || [ "$REVISION" == "$RPI2ByREV" ]  || [ "$REVISION" == "$RPI3BxREV" ] || [ "$REVISION" == "$RPI3ByREV" ] || [ "$REVISION" == "$RPI0xREV" ] || [ "$REVISION" == "$RPI0yREV" ]; then
    apt-get install -y rpi-update
    rpi-update
fi

apt-get update
apt-get dist-upgrade -y
apt-get upgrade -y
apt-get install -y git
git config --global http.sslVerify false
apt-get install -y iw
apt-get install -y lshw
apt-get install -y wget
apt-get install -y isc-dhcp-server
apt-get install -y tcpdump
apt-get install -y cmake
apt-get install -y libusb-1.0-0.dev
apt-get install -y build-essential
apt-get install -y mercurial
apt-get install -y autoconf
apt-get install -y fftw3
apt-get install -y fftw3-dev
apt-get install -y libtool
apt-get install -y automake
apt-get remove -y hostapd
apt-get install -y hostapd

echo "${GREEN}...done${WHITE}"


##############################################################
##  Hardware check
##############################################################
echo
echo "${YELLOW}**** Hardware check... *****${WHITE}"

if [ "$REVISION" == "$RPI2BxREV" ] || [ "$REVISION" == "$RPI2ByREV" ]  || [ "$REVISION" == "$RPI3BxREV" ] || [ "$REVISION" == "$RPI3ByREV" ] || [ "$REVISION" == "$RPI0xREV" ] || [ "$REVISION" == "$RPI0yREV" ]; then
    echo
    echo "${MAGENTA}Raspberry Pi detected...${WHITE}"

    . ${SCRIPTDIR}/rpi.sh
elif [ "$REVISION" == "$ODROIDC2" ]; then
    echo
    echo "${MAGENTA}Odroid-C2 detected...${WHITE}"

    . ${SCRIPTDIR}/odroid.sh
else
    echo
    echo "${BOLD}${RED}WARNING - unable to identify the board using /proc/cpuinfo...${WHITE}${NORMAL}"

    #exit
fi

echo "${GREEN}...done${WHITE}"


##############################################################
##  Stratux USB devices udev rules
##############################################################
echo
echo "${YELLOW}**** Stratux USB devices udev rules to /etc/udev/rules.d/10-stratux.rules *****${WHITE}"

cat <<EOT > /etc/udev/rules.d/10-stratux.rules
SUBSYSTEMS=="usb", ATTRS{idVendor}=="1546", ATTRS{idProduct}=="01a8", SYMLINK+="ublox8"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="1546", ATTRS{idProduct}=="01a7", SYMLINK+="ublox7"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="1546", ATTRS{idProduct}=="01a6", SYMLINK+="ublox6"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="067b", ATTRS{idProduct}=="2303", SYMLINK+="prolific%n"
EOT

echo "${GREEN}...done${WHITE}"


##############################################################
##  SSH setup and config
##############################################################
echo
echo "${YELLOW}**** SSH setup and config... *****${WHITE}"

if [ ! -d "$DIRECTORY" ]; then
    mkdir -p /etc/ssh/authorized_keys
fi

cp -n /etc/ssh/authorized_keys/root{,.bak}
cp -f ${SCRIPTDIR}/files/root /etc/ssh/authorized_keys/root
chown root.root /etc/ssh/authorized_keys/root
chmod 644 /etc/ssh/authorized_keys/root

cp -n /etc/ssh/sshd_config{,.bak}
cp -f ${SCRIPTDIR}/files/sshd_config /etc/ssh/sshd_config
rm -f /usr/share/dbus-1/system-services/fi.epitest.hostap.WPASupplicant.service

echo "${GREEN}...done${WHITE}"


##############################################################
##  Hardware blacklisting
##############################################################
echo
echo "${YELLOW}**** Hardware blacklisting... *****${WHITE}"

if ! grep -q "blacklist dvb_usb_rtl28xxu" "/etc/modprobe.d/rtl-sdr-blacklist.conf"; then
    echo blacklist dvb_usb_rtl28xxu >>/etc/modprobe.d/rtl-sdr-blacklist.conf
fi

if ! grep -q "blacklist e4000" "/etc/modprobe.d/rtl-sdr-blacklist.conf"; then
    echo blacklist e4000 >>/etc/modprobe.d/rtl-sdr-blacklist.conf
fi

if ! grep -q "blacklist rtl2832" "/etc/modprobe.d/rtl-sdr-blacklist.conf"; then
    echo blacklist rtl2832 >>/etc/modprobe.d/rtl-sdr-blacklist.conf
fi


##############################################################
##  Go environment setup
##############################################################
echo
echo "${YELLOW}**** Go environment setup... *****${WHITE}"

# if any of the following environment variables are set in .bashrc delete them
if grep -q "export GOROOT_BOOTSTRAP=" "/root/.bashrc"; then
    line=$(grep -n 'GOROOT_BOOTSTRAP=' /root/.bashrc | awk -F':' '{print $1}')d
    sed -i $line /root/.bashrc
fi

if grep -q "export GOPATH=" "/root/.bashrc"; then
    line=$(grep -n 'GOPATH=' /root/.bashrc | awk -F':' '{print $1}')d
    sed -i $line /root/.bashrc
fi

if grep -q "export GOROOT=" "/root/.bashrc"; then
    line=$(grep -n 'GOROOT=' /root/.bashrc | awk -F':' '{print $1}')d
    sed -i $line /root/.bashrc
fi

if grep -q "export PATH=" "/root/.bashrc"; then
    line=$(grep -n 'PATH=' /root/.bashrc | awk -F':' '{print $1}')d
    sed -i $line /root/.bashrc
fi

# only add new paths
XPATH="\$PATH"
if [[ ! "$PATH" =~ "/root/go/bin" ]]; then
    XPATH+=:/root/go/bin
fi

if [[ ! "$PATH" =~ "/root/gopath/bin" ]]; then
    XPATH+=:/root/gopath/bin
fi

echo export GOROOT_BOOTSTRAP=/root/gobootstrap >>/root/.bashrc
echo export GOPATH=/root/gopath >>/root/.bashrc
echo export GOROOT=/root/go >>/root/.bashrc
echo export PATH=${XPATH} >>/root/.bashrc

export GOROOT_BOOTSTRAP=/root/gobootstrap
export GOPATH=/root/gopath
export GOROOT=/root/go
export PATH=${PATH}:/root/go/bin:/root/gopath/bin

source /root/.bashrc

echo "${GREEN}...done${WHITE}"


##############################################################
##  Go bootstrap compiler installation
##############################################################
echo
echo "${YELLOW}**** Go bootstrap compiler installtion... *****${WHITE}"

cd /root

rm -rf go/
rm -rf gobootstrap/

if [ "$MACHINE" == "$ARM6L" ] || [ "$MACHINE" == "$ARM7L" ]; then
    #### For RPi-2/3, is there any disadvantage to using the armv6l compiler?

#    wget https://storage.googleapis.com/golang/go1.7beta1.linux-armv6l.tar.gz
#    tar -zxvf go1.7beta1.linux-armv6l.tar.gz
    wget https://storage.googleapis.com/golang/go1.6.2.linux-armv6l.tar.gz
    tar -zxvf go1.6.2.linux-armv6l.tar.gz
    if [ ! -d /root/go ]; then
        echo "${BOLD}${RED}ERROR - go folder doesn't exist, exiting...${WHITE}${NORMAL}"
        exit
    fi
elif [ "$MACHINE" == "$ARM64" ]; then
    # ulimit -s 1024     # set the thread stack limit to 1mb
    # ulimit -s          # check that it worked
    # env GO_TEST_TIMEOUT_SCALE=10 GOROOT_BOOTSTRAP=/root/gobootstrap

    wget https://github.com/jpoirier/GoAarch64Binaries/raw/master/go1.6.linux-armvAarch64.tar.gz
    tar -zxvf go1.6.linux-armvAarch64.tar.gz
    if [ ! -d /root/go ]; then
        echo "${BOLD}${RED}ERROR - go folder doesn't exist, exiting...${WHITE}${NORMAL}"
        exit
    fi
else
    echo
    echo "${BOLD}${RED}ERROR - unsupported machine type: $MACHINE, exiting...${WHITE}${NORMAL}"
fi

rm -f go1.6.linux*
rm -rf /root/gopath
mkdir -p /root/gopath

echo "${GREEN}...done${WHITE}"


##############################################################
##  RTL-SDR tools build
##############################################################
echo
echo "${YELLOW}**** RTL-SDR library build... *****${WHITE}"

cd /root

rm -rf librtlsdr
git clone https://github.com/jpoirier/librtlsdr
cd librtlsdr
mkdir build
cd build
cmake ../
make
make install
ldconfig

echo "${GREEN}...done${WHITE}"


##############################################################
##  Stratux build and installation
##############################################################
echo
echo "${YELLOW}**** Stratux build and installation... *****${WHITE}"

cd /root

rm -rf stratux
git clone https://github.com/cyoung/stratux --recursive
cd stratux
git fetch --tags
tag=$(git describe --tags `git rev-list --tags --max-count=1`)
# checkout the latest release
git checkout $tag

make all
make install

#### sanity checks
if [ ! -f "/usr/bin/gen_gdl90" ]; then
    echo "${BOLD}${RED}ERROR - gen_gdl90 file missing, exiting...${WHITE}${NORMAL}"
    exit
fi

if [ ! -f "/etc/init.d/stratux" ]; then
    echo "${BOLD}${RED}ERROR - stratux file missing, exiting...${WHITE}${NORMAL}"
    exit
fi

if [ ! -f "/etc/rc2.d/S01stratux" ]; then
    echo "${BOLD}${RED}ERROR - S01stratux link file missing, exiting...${WHITE}${NORMAL}"
    exit
fi

if [ ! -f "/etc/rc6.d/K01stratux" ]; then
    echo "${BOLD}${RED}ERROR - K01stratux link file missing, exiting...${WHITE}${NORMAL}"
    exit
fi

if [ ! -f "/usr/bin/dump1090" ]; then
    echo "${BOLD}${RED}ERROR - dump1090 file missing, exiting...${WHITE}${NORMAL}"
    exit
fi

echo "${GREEN}...done${WHITE}"


##############################################################
##  Kalibrate build and installation
##############################################################
echo
echo "${YELLOW}**** Kalibrate build and installation... *****${WHITE}"

cd /root

rm -rf kalibrate-rtl
git clone https://github.com/steve-m/kalibrate-rtl
cd kalibrate-rtl
./bootstrap
./configure
make
make install

echo "${GREEN}...done${WHITE}"


##############################################################
##  System tweaks
##############################################################
echo
echo "${YELLOW}**** System tweaks... *****${WHITE}"

##### disable serial console
if [ -f /etc/inittab ]; then
    sed -i /etc/inittab -e "s|^.*:.*:respawn:.*ttyAMA0|#&|"
fi

##### Set the keyboard layout to US.
if [ -f /etc/default/keyboard ]; then
    sed -i /etc/default/keyboard -e "/^XKBLAYOUT/s/\".*\"/\"us\"/"
fi

#### allow starting services
if [ -f /usr/sbin/policy-rc.d ]; then
    rm /usr/sbin/policy-rc.d
fi

echo "${GREEN}...done${WHITE}"


#################################################
## Setup /root/.stxAliases
#################################################
echo
echo "${YELLOW}**** Setup /root/.stxAliases *****${WHITE}"

if [ -f "/root/stratux/image/stxAliases.txt" ]; then
    cp /root/stratux/image/stxAliases.txt /root/.stxAliases
else
    cp ${SCRIPTDIR}/files/stxAliases.txt /root/.stxAliases
fi

if [ ! -f "/root/.stxAliases" ]; then
    echo "${BOLD}${RED}ERROR - /root/.stxAliases file missing, exiting...${WHITE}${NORMAL}"
    exit
fi

echo "${GREEN}...done${WHITE}"


#################################################
## Add .stxAliases command to /root/.bashrc
#################################################
echo
echo "${YELLOW}**** Add .stxAliases command to /root/.bashrc *****${WHITE}"

if ! grep -q ".stxAliases" "/root/.bashrc"; then
cat <<EOT >> /root/.bashrc
if [ -f /root/.stxAliases ]; then
. /root/.stxAliases
fi
EOT
fi

echo "${GREEN}...done${WHITE}"


##############################################################
##  WiFi Access Point setup
##############################################################
echo
echo "${YELLOW}**** WiFi Access Point setup... *****${WHITE}"

. ${SCRIPTDIR}/wifi-ap.sh


##############################################################
## Copying the hostapd_manager.sh utility
##############################################################
echo
echo "${YELLOW}**** Copying the hostapd_manager.sh utility... *****${WHITE}"

#if [ -f /root/stratux/image/hostapd_manager.sh ]; then
#    chmod 755 /root/stratux/image/hostapd_manager.sh
#    cp /root/stratux/image/hostapd_manager.sh /usr/bin/hostapd_manager.sh
#else
chmod 755 ${SCRIPTDIR}/files/hostapd_manager.sh
cp ${SCRIPTDIR}/files/hostapd_manager.sh /usr/bin/hostapd_manager.sh
#fi

echo "${GREEN}...done${WHITE}"


##############################################################
## Disable ntpd autostart
##############################################################
echo
echo "${YELLOW}**** Disable ntpd autostart... *****${WHITE}"

if which ntp >/dev/null; then
    systemctl disbable ntp
fi

echo "${GREEN}...done${WHITE}"


##############################################################
## Enable update-rc.d stratux
##############################################################
echo
echo "${YELLOW}**** Enable update-rc.d stratux... *****${WHITE}"
####
update-rc.d stratux enable

echo "${GREEN}...done${WHITE}"


##############################################################
## Epilogue
##############################################################
echo
echo
echo "${MAGENTA}**** Setup complete, don't forget to reboot! *****${WHITE}"
echo

echo ${NORMAL}
