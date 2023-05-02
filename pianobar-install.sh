#!/bin/bash
# Distro: Debian; Devuan; Ubuntu

if [[ `command -v sudo` ]]; then
	:;
else
	echo "This script requires you to setup sudo."
	exit 0
fi

# USER VARIABLES
EMAIL="user@email.com" # login username
PASSWD="password" # login password
STATION="digits" # autostart station

# Find the master volume: amixer scontrols
# Example: Speaker Headphone Master 'PCM,2'
MIXER="Master"

# Choose compiler
#GCC="gcc-9"  # ubuntu focal
GCC="gcc-10" # debian bullseye
#GCC="gcc-11" # debian bookworm / ubuntu jammy

# Install python (probs not needed)
ENABLE_PYTHON="false"

# COLORS
RED="\e[1;31m"
GRN="\e[1;32m"
PNK="\e[1;35m"
WHT="\e[1;37m"
YLW="\e[1;33m"
FIN="\e[0m"

# SYSTEM VARIABLES
RELEASE=`cat /etc/os-release | grep -w VERSION_CODENAME | sed 's/VERSION_CODENAME=//g'`
TLS_FINGERPRINT=`openssl s_client -connect tuner.pandora.com:443 < /dev/null 2> /dev/null | openssl x509 -noout -fingerprint | tr -d ':' | cut -d'=' -f2`
CONFIGDIR="${HOME}/.config/pianobar"
CORES=`nproc`

# PACKAGES
PKGS="alsa-utils ffmpeg libssl-dev liblzo2-2 libcurl4-openssl-dev libgcrypt20-dev ${GCC} \
	libgcrypt20 libjson-c-dev libavfilter-dev libao4 libao-common screen libao-dev git \
	gettext autopoint autoconf automake pkg-config libtool device-tree-compiler libell0"

PYTHON="python3-dbus python3 python3-setuptools python3-pyaudio python3-pexpect"

echo ""
echo -en "${WHT}Checking Internet Connection:${FIN} "
if [[ `wget -S --spider https://github.com 2>&1 | grep 'HTTP/1.1 200 OK'` ]]; then
	echo -e "${PNK}[${FIN}${GRN}OK${FIN}${PNK}]${FIN}"
	echo ""
	sleep .75; echo -e "Installing dependencies:${FIN}"
	sudo apt update; sudo apt upgrade -y
	if [[ "$ENABLE_PYTHON" == "true" ]]; then
		sudo apt install -y ${PKGS} ${PYTHON}
	else
		sudo apt install -y ${PKGS}
	fi
	echo ""
else
	echo -en "${PNK}[${FIN}${RED}failed${FIN}${PNK}]${FIN}"
	echo ""
	echo -e "${WHT}Please check your internet connection and try again${FIN}."
	exit 0
fi

# PIANOBAR
echo "Installing Pianobar ..."
git clone https://github.com/PromyLOPh/pianobar.git
cd pianobar
make -j${CORES} CC=/usr/bin/${GCC}
sudo make install
cd ..
sudo rm -fdr pianobar

# LIBAO CONFIG
if [[ -f "/etc/libao.conf" ]]; then
	sudo mv -f /etc/libao.conf /etc/libao.conf.bak
	echo "default_driver=alsa" | sudo tee /etc/libao.conf
	echo "quiet" | sudo tee -a /etc/libao.conf
else
	echo "default_driver=alsa" | sudo tee /etc/libao.conf
	echo "quiet" | sudo tee -a /etc/libao.conf
fi

# USER CONFIG
mkdir -p ${CONFIGDIR}
if [[ -f "${CONFIGDIR}/config" ]]; then
	mv -f ${CONFIGDIR}/config ${CONFIGDIR}/config.bak
fi
cat << EOF >> "${CONFIGDIR}/config"
user = ${EMAIL}
password = ${PASSWD}
autostart_station = ${STATION}
audio_quality = high
buffer_seconds = 0
tls_fingerprint = ${TLS_FINGERPRINT}
EOF

# FUNCTIONS
mute (){
cat << EOF >> ${HOME}/bin/mute.sh
#!/bin/bash
amixer sset ${MIXER} mute
EOF
}

next (){
cat << EOF >> ${HOME}/bin/next.sh
#!/bin/bash
screen -S pianobar -p 0 -X stuff "n^M"
EOF
}

play (){
cat << EOF >> ${HOME}/bin/play.sh
#!/bin/bash
screen -S pianobar -p 0 -X stuff "p^M"
EOF
}

song (){
cat << EOF >> ${HOME}/bin/song.sh
#!/bin/bash
echo ""
awk -F\, '{printf $1" - "$4}' ~/.config/pianobar/currentSong
echo ""
EOF
sed -i 's/" - "/$1" - "$4/g' ${HOME}/bin/song.sh
}

start (){
cat << EOF >> ${HOME}/bin/start.sh
#!/bin/bash
echo -en "Starting pianobar "
${HOME}/bin/stop.sh 1> /dev/null
screen -S pianobar -d -m bash -c 'pianobar'
sleep .50
echo "[done]"
EOF
}

stop (){
cat << EOF >> ${HOME}/bin/stop.sh
#!/bin/bash
echo -en "Stopping pianobar "
pkill -xf "SCREEN -S pianobar -d -m bash -c pianobar"
sleep .50
echo "[done]"
EOF
}

unmute (){
cat << EOF >> ${HOME}/bin/unmute.sh
#!/bin/bash
amixer sset ${MIXER} unmute
EOF
}

voldn (){
cat << EOF >> ${HOME}/bin/voldn.sh
#!/bin/bash
amixer sset ${MIXER} 5%-
EOF
}

volup (){
cat << EOF >> ${HOME}/bin/volup.sh
#!/bin/bash
amixer sset ${MIXER} 5%+
EOF
}

volume (){
cat << EOF >> ${HOME}/bin/volume.sh
#!/bin/bash
amixer sset ${MIXER} 50%
EOF
}

# FIN
echo ""
mkdir -p ${HOME}/bin
mute; next; play; start; stop; unmute; voldn; volup; volume;
chmod +x ${HOME}/bin/*.sh
cat "${CONFIGDIR}/config"
echo export PATH="$PATH" >> ~/.bashrc
echo ""

exit 0
