#!/bin/bash
export DOMAIN=ocp-master-pro.tmn.local
export USERNAME=admin
export PASSWORD=admin@pwdprod
export VERSION=${VERSION:="v3.6.1"}

export SCRIPT_REPO=${SCRIPT_REPO:="https://raw.githubusercontent.com/thol-voleak/install-or-centos-3.9/master/"}

export IP="$(ip route get 8.8.8.8 | awk '{print $NF; exit}')"

echo "******"
echo "* Your domain is $DOMAIN "
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "* OpenShift version: $VERSION "
echo "******"

yum install -y epel-release
yum install -y git wget zile net-tools \
python-cryptography pyOpenSSL.x86_64 python2-pip \
openssl-devel python-devel httpd-tools NetworkManager python-passlib \
java-1.8.0-openjdk-headless "@Development Tools" \
bind-utils iptables-services bridge-utils bash-completion kexec-tools sos psacct 
yum groupinstall -y file-server nfs-utils
systemctl enable rpcbind
systemctl enable nfs-server
systemctl start rpcbind
systemctl start nfs-server

systemctl | grep "NetworkManager.*running" 
if [ $? -eq 1 ]; then
	systemctl start NetworkManager
	systemctl enable NetworkManager
fi

which ansible || pip install -Iv ansible
[ ! -d openshift-ansible ] && git clone https://github.com/openshift/openshift-ansible.git
cd openshift-ansible && git fetch && git checkout release-3.6 && cd ..

cat <<EOD > /etc/hosts
	127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 
	::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
	${IP}		$(hostname) console console.${DOMAIN} 
EOD

if [ -z $DISK ]; then 
	export DISK="/dev/sda"
	cp /etc/sysconfig/docker-storage-setup /etc/sysconfig/docker-storage-setup.bk
	echo DEVS=$DISK > /etc/sysconfig/docker-storage-setup
	echo VG=DOCKER >> /etc/sysconfig/docker-storage-setup
	echo SETUP_LVM_THIN_POOL=yes >> /etc/sysconfig/docker-storage-setup
	echo DATA_SIZE="100%FREE" >> /etc/sysconfig/docker-storage-setup

	systemctl stop docker

	rm -rf /var/lib/docker
	wipefs --force $DISK
	docker-storage-setup
fi
 
curl -o inventory.download $SCRIPT_REPO/inventory.ini
envsubst < inventory.download > inventory.ini
ansible-playbook -i inventory.ini openshift-ansible/playbooks/byo/config.yml

htpasswd -b /etc/origin/master/htpasswd ${USERNAME} ${PASSWORD}
oc adm policy add-cluster-role-to-user cluster-admin ${USERNAME}

systemctl restart origin-master

echo "******"
echo "* Your conosle is https://console.$DOMAIN:8443"
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "*"
echo "* Login using:"
echo "*"
echo "$ oc login -u ${USERNAME} -p ${PASSWORD} https://console.$DOMAIN:8443/"
echo "******"
oc login -u ${USERNAME} -p ${PASSWORD} https://console.$DOMAIN:8443/