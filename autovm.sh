#/bin/bash

## autovm.sh file
## usage : autovm.sh [baseline] [method] "[domain list]"
##         autovm.sh $1 $2 "$3"
## ex :    autovm.sh small http "vm00 vm01 vm02 vm03" 
## Linux KVM domain automatic deployment Fedora/Centos 7
## via HTTP repo the options are :
##  * baseline : small, medium ou large
##  * method : http or local to get Kickstart
##  * domain list between " "
##

## Internal variables 
baseline=$1
method=$2
list=$3
# count domain in $list
nb=$(echo $list | wc -w)
# $uidtemp var : template uid
uidtemp="gi-$(uuidgen | cut -d - -f 1)"

## Options to configure (network and paths)
## Base scenario with libvirt Default network
## and local http browser for ks and as repo
# bridge network
bridge=virbr0
bridgeip4=$(ip -4 address show $bridge | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/')
# $vol var : path to domain images
vol=/var/lib/libvirt/images
# $www var : local path to template kickstart file
www=/var/www/html/conf
# $conf var : http path to template kickstart file 
conf=http://$bridgeip4/conf
# $mirror var : http path to an installation mirror
mirror=http://$bridgeip4/repo
## Public mirrors
#mirror=http://centos.mirrors.ovh.net/ftp.centos.org/7/os/x86_64
#mirror=http://ftp.belnet.be/ftp.centos.org/7/os/x86_64
#mirror=http://mirror.i3d.net/pub/centos/7/os/x86_64

## Driving the script ?
## 1. Check the five options variables 
## 2. Launch the script with the baseline machine, the kickstart file location 
## and the name of your new domains between double quotes as arguments.
## 3. Look to your console and please read the logs. 
## If the newly created domains already exist, the script ask you what to do with them. 
## Assume that you have a local http server avaible
## when you choose http kickstart installation
##
## What the script is doing for you ?
## 1. Checking the configuration 
## 2. Generation of a fresh temporary template via http repo and local or remote ks file
## 3. Building clones from the template domain
## 4. Preparing, optimizing, customizing each new virtual disk
## 5. Starting and monitoring new domains
##
## Automation goal ?
## This script is used to deploy a numberous of idendial domains 
## on a libvirtd/libguestfs host. 
## 
## What are the next goals ?
## But the "use case" is followed by some next steps.
## After this operation, the goal is to manage those new linux para-virtualized virtual machines
## via Ansible and deploy configurations and applications (native or container based as Docker)
##
## Source of this script : practice lab in Linux training classroom with a motived team

install_info ()
{

# Show install configuation 
echo "+ Install configuration : $baseline"
echo "+ Kickstart file method : $method"
echo "+ $nb domains to create : $list"
echo "+ Path to images : $vol"
echo "+ FS path to kickstart file : $www"
echo "+ http path to kickstart file : $conf"
echo "+ Mirroir des fichiers d'installation : $mirror"

}

dom_erase ()
{

# Template already present ? Probably not
echo "Erasing template"
virsh destroy $uidtemp 2> /dev/null
virsh undefine $uidtemp 2> /dev/null
rm -f $vol/$uidtemp.*
rm -f $www/$uidtemp.*

# Domains to deploy already present ?
for ((i=1;i<=$nb;i++)); do
domain=$(echo $list | cut -d" " -f $i)
if $(virsh list --all | grep -w "$domain" &> /dev/null); then
        read -p "$domain domain  exists. Erasing (y/n) ? " answer
        if [ $answer = 'y' ]
         then
                /bin/virsh destroy $domain 2> /dev/null
                /bin/virsh undefine $domain 2> /dev/null
                rm -rf $vol/$domain.* 2> /dev/null
        elif [ $answer = 'n' ]
         then
                list=$(echo "$list" | sed "s/$domain//g")
                i=$((i-1))
                nb=$((nb-1))
        else
                i=$((i-1))
                continue
        fi
fi
done

}

temp_create ()
{

ks_prep ()
{

## Kickstart file preparation
echo "Kickstart file preparation"

# Put packages line by line between EOM as variable $packages
read -r -d '' packages <<- EOM
@core
wget
EOM

touch $www/$uidtemp.ks
cat << EOF > $www/$uidtemp.ks 
install
reboot
rootpw --plaintext testtest
keyboard --vckeymap=be-oss --xlayouts='be (oss)'
timezone Europe/Brussels
lang fr_BE
url --url="$mirror"
firewall --disabled
network --bootproto=dhcp --device=eth0
network --hostname=$uidtemp
# network --device=eth0 --bootproto=static --ip=192.168.22.10 --netmask 255.255.255.0 --gateway $bridgeip4 --nameserver=$bridgeip4 --ipv6 auto
auth  --useshadow  --passalgo=sha512
text
firstboot --enable
skipx
ignoredisk --only-use=vda
bootloader --location=mbr --boot-drive=vda
zerombr
clearpart --all --initlabel
part /boot --fstype="xfs" --ondisk=vda --size=500
part swap --recommended
part pv.00 --fstype="lvmpv" --ondisk=vda --size=500 --grow
volgroup local0 --pesize=4096 pv.00
logvol /  --fstype="xfs"  --size=4000 --name=root --vgname=local0
%packages
$packages
%end
%post
#yum -y update
mkdir /root/.ssh
curl $conf/id_rsa.pub > /root/.ssh/authorized_keys
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
%end
EOF

chown apache:apache $www/$uidtemp.ks

}

virt_install ()
{

installation ()
{

playtemp ()
{
## virt-install process installation via http following kickstart file config
echo "Template \"$baseline\" domain installation is starting  ... "
nohup \
/bin/virt-install \
--virt-type kvm \
--name=$uidtemp \
--disk path=$vol/$uidtemp.$format,size=$size,format=$format \
--ram=$ram \
--vcpus=$vcpus \
--os-variant=rhel7 \
--network bridge=$bridge \
--graphics none \
--noreboot \
--console pty,target_type=serial \
--location $mirror \
$init \
-x " $extra " > /dev/null 2>&1 &
sleep 5
while (true) do
        check_install=$(virsh list | grep $uidtemp 2> /dev/null)
	echo -n "."
	sleep 3
	if [ -z "$check_install" ]; then
		break
	fi
done

echo -e "\nTemplate is created ! "
}

if [ $method = http ] ; then
	extra="ks=$conf/$uidtemp.ks console=ttyS0,115200n8 serial"
	init=""
	playtemp
elif [ $method = local ] ; then
        extra="console=ttyS0,115200n8 serial"
	init="--initrd-inject=/$uidtemp.ks"
	playtemp
else
        exit
fi


}

if [ $baseline = small ] ; then
        size=8
        format=qcow2
        ram=1024
        vcpus=1
    installation
elif [ $baseline = medium ] ; then
        size=16
        format=qcow2
        ram=2048
        vcpus=2
    installation
elif [ $baseline = large ] ; then
        size=32
        format=qcow2
        ram=4096
        vcpus=4
    installation
else
        exit
fi

}

dom_erase
ks_prep
virt_install

}

clone ()
{
sysprep ()
{
## !!!
virt-sysprep --format=$format -a $vol/$uidtemp.$format &> /dev/null
}

cloning ()
{

# cloning loop
for domain in $list; do
mac=$(printf '52:54:00:EF:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)))
# uuid generation for domain image
uiddom=$(uuidgen | cut -d - -f 1)
# image format
format=qcow2
	# vir-clone operations
	virt-clone \
	--connect qemu:///system \
	--original $uidtemp \
	--name $domain \
	--file $vol/$domain-$uiddom.$format \
	--mac $mac
	# clone domain customizations
guestfish -a $vol/$domain-$uiddom.$format -i <<EOF
write-append /etc/sysconfig/network-scripts/ifcfg-eth0 "DHCP_HOSTNAME=$domain\nHWADDR=$mac\n"
write /etc/hostname "$domain\n"
EOF
done

}

sysprep
cloning
}

dom_start ()
{
# start domains
for domain_new in $list; do
	virsh start $domain_new
	sleep 5
done
}

temp_all_erase ()
{

echo "Destroy, undefine and erase temporary template domains"
for gi-dom in $(virsh list --name --all | grep gi-.*); do 
        virsh destroy $gi-dom 2> /dev/null
        virsh undefine $gi-dom
        rm -f $vol/$gi-dom*
done

}

echo $(date +"%M:%S")
install_info
echo $(date +"%M:%S")
temp_create
echo $(date +"%M:%S")
clone
echo $(date +"%M:%S")
temp_all_erase
echo $(date +"%M:%S")
dom_start
echo $(date +"%M:%S")
#dom_info
