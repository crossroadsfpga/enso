apt-get update -y;
apt install  make -y;
apt install gcc --fix-missing -y;
apt install gcc-5 --fix-missing -y;
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 20;
gcc --version;
