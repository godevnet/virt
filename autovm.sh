#/bin/bash
# fichier autovm.sh
## usage : autovm.sh [baseline] "[liste de domaines]"
##         autovm.sh $1 "$2" 
## Création et installation automatisée Fedora/Centos 7
## baseline : small, medium ou large
## liste : liste de domaines à créer entre " "
##

## Variables générales
baseline=$1
list=$2
## $uidtemp : id aléatoire pour le domaine modèle 
uidtemp="gi-$(uuidgen | cut -d - -f 1)"
## $vol : Emplacement images des disques
vol=/var/lib/libvirt/images
## $www : emplacement physique des fichiers de configuration
www=/var/www/html/conf
mirror=http://192.168.122.1/repo
## Miroirs publics
#mirror=http://centos.mirrors.ovh.net/ftp.centos.org/7/os/x86_64
#mirror=http://ftp.belnet.be/ftp.centos.org/7/os/x86_64
#mirror=http://mirror.i3d.net/pub/centos/7/os/x86_64
## $conf : Emplacement HTTP des fichiers Kickstart
## Serveur Web sur l'hyperviseur (adresse du réseau "Default")
conf=http://192.168.122.1/conf
## Nombre de domaines
nb=$(echo $list | wc -w)

install_info ()
{

# Affichage des informations
echo "* Type d'installation : $baseline"
echo "* $nb domaines : $list"
echo "* Emplacement des images disques : $vol"
echo "* Emplacement physique des fichiers de configuration : $www"
echo "* Mirroir des fichiers d'installation : $mirror"
echo "* Serveur des fichiers de configuration : $conf"

}

temp_erase ()
{

echo "Supression du modèle"
virsh destroy $uidtemp 2> /dev/null
virsh undefine $uidtemp 2> /dev/null
rm -f $vol/$uidtemp.*

}

temp_create ()
{

ks_prep ()
{

## Préparation du fichier Kickstart
echo "Préparation du fichier Kickstart @core+clé SSH LV / 4G"

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

## Démarrage de l'installation du modèle
echo "Démarrage de la création du modèle $uidtemp de type \"$baseline\""
## Installation et lancement silencieux en mode texte
## selon le profil (baseline) défini dans la variable $baseline
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

## choix installation cdrom avec Kickstart local
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

echo -e "\nCréation du modèle $uidtemp terminée"

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

# Les domaines existent-ils ?

for ((i=1;i<=$nb;i++)); do

domain=$(echo $list | cut -d" " -f $i)

if $(virsh list --all | grep -w "$domain" &> /dev/null)
then
        read -p "Ecraser le domaine $domain (o/n) ? " answer
        if [ $answer = 'o' ]
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

# Boucle de clonage
for domain in $list; do
mac=$(printf '52:54:00:EF:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)))
# Génération d'un uuid
uiddom=$(uuidgen | cut -d - -f 1)
# Format de disque
format=qcow2
	# Clonage
	virt-clone \
	--connect qemu:///system \
	--original $uidtemp \
	--name $domain \
	--file $vol/$domain-$uiddom.$format \
	--mac $mac
	# Personnalisation du clonage
guestfish -a $vol/$domain-$domid.$format -i <<EOF
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
# Démarrage des domaines
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
