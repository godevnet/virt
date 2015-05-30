#/bin/bash

## autovm.sh file
## usage : autovm.sh [baseline] "[domain list]"
##         autovm.sh $1 "$2" 
## Linux KVM domain automatic deployment Fedora/Centos 7
## baseline : small, medium ou large
## domain list between " "
##

## Variables
baseline=$1
list=$2
## $uidtemp var : template uid
uidtemp="gi-$(uuidgen | cut -d - -f 1)"
## $vol var : path to domain images
vol=/var/lib/libvirt/images
## $www var : local path to template kickstart file
www=/var/www/html/conf
## $conf var : http path to template kickstart file 
conf=http://192.168.122.1/conf
## $mirror var : http path to an installation mirrot
mirror=http://192.168.122.1/repo
## Public mirrors
#mirror=http://centos.mirrors.ovh.net/ftp.centos.org/7/os/x86_64
#mirror=http://ftp.belnet.be/ftp.centos.org/7/os/x86_64
#mirror=http://mirror.i3d.net/pub/centos/7/os/x86_64
## count domain in $list
nb=$(echo $list | wc -w)

install_info ()
{

# Show install configuation 
echo "* Install configuration : $baseline"
echo "* $nb domains to create : $list"
echo "* Path to images : $vol"
echo "* FS path to kickstart file : $www"
echo "* http path to kickstart file : $conf"
echo "* Mirroir des fichiers d'installation : $mirror"

}

temp_erase ()
{

echo "Erasing template"
virsh destroy $uidtemp 2> /dev/null
virsh undefine $uidtemp 2> /dev/null
rm -f $vol/$uidtemp.*
rm -f $www/$uidtemp.*

}

temp_create ()
{

ks_prep ()
{

## Kickstart file preparation
echo "Kickstart file preparation : @core+SSH key+LV 4G"

##
touch $www/$uidtemp.ks
cat << EOF > $www/$uidtemp.ks 
install
keyboard --vckeymap=be-oss --xlayouts='be (oss)'
reboot
rootpw --plaintext testtest
timezone Europe/Brussels
url --url="$mirror"
lang fr_BE
firewall --disabled
network --bootproto=dhcp --device=eth0
network --hostname=$uidtemp
# network --device=eth0 --bootproto=static --ip=192.168.22.10 --netmask 255.255.255.0 --gateway 192.168.22.254 --nameserver=192.168.22.11 --ipv6 auto
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
@core
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

## Template domain installation start ... 
echo "Template \"$baseline\" domain installation is starting  ... "
## virt-install process installation via http following kickstart file config
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
-x "ks=$conf/$uidtemp.ks console=ttyS0,115200n8 serial" \
> /dev/null 2>&1 &

## cd-rom installation and local kickstart
#ks=/var/www/html/conf
#iso=path/to/iso
#--cdrom $iso \
#--initrd-inject=/$uidtemp.ks -x "ks=file:/$uidtemp.ks console=ttyS0,115200n8 serial" \

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

if [ $baseline = small ] ; then
        size=8
        format=qcow2
        ram=1024
        vcpus=1
        bridge=virbr0
    installation
elif [ $baseline = medium ] ; then
        size=16
        format=qcow2
        ram=2048
        vcpus=2
        bridge=virbr0
    installation
elif [ $baseline = large ] ; then
        size=32
        format=qcow2
        ram=4096
        vcpus=4
        bridge=virbr0
    installation
else
        exit
fi

}

temp_erase
ks_prep
virt_install

}

clone ()
{

dom_man ()
{

# Domains to deploy already present ?

for ((i=1;i<=$nb;i++)); do

domain=$(echo $list | cut -d" " -f $i)

if $(virsh list --all | grep -w "$domain" &> /dev/null); then
        read -p "Domain $domain exists. Erasing (y/n) ? " answer
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

dom_man
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

#vol=/var/lib/libvirt/images
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
temp_erase
echo $(date +"%M:%S")
dom_start
echo $(date +"%M:%S")
#dom_info
