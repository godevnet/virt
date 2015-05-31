# virt

## Introduction

This project is born from the lecture of [CentOS-KVM-Image-Tools](https://github.com/fubralimited/CentOS-KVM-Image-Tools). 

### Objective

We use this to illustrate virtualization concepts and practice in Linux training classrooms. 

The main objective is practice and design several scripts and procedures to manage virtual infrastructure using KVM, Xen, LXC, Docker technologies or other open source projects around the *cloud paradigm*. *Automation* is an other main objective.

### Requirements

* KVM
* libvirt
* libguestfs
* Centos 7 dev server
* /tmp available space to sparsifying (depending on the size of the original disk, 8GB min)

### Performances

Please use :

* HTTP or NFS local repo instead of local iso dvd
* dedicated network storage pools

## autovm.sh

The starting goal of the `autovm.sh`script is to build and start numerous KVM domains (Centos 7 image) in one optimized, quick and proper way for automation.

Build and give birth to atomic virtual machines to host micro services topologies is an other way to read this objective. 

Consider that this script is a way to launch virtual instances at the beginning of their life in their development environment. You are present at the delivery of newborn domains in at the maternity hospital. This is the dawn of those IP addressed black boxes. Their life is conditioned by other events : *migration* in production environnement; *configuration management* tools and procedures; configuration, deployment and management of *network micro/services*. **Their life goal is to serve as hosts for micro-services in a virtual infrastructure.** We use it as lab automatic deployment tool. But you can exploit the **VPS use case** or the **SaaS use case**, offering micro-services like remote ssh shell, pre-configured ts/game servers, VoIP, Lamp, Bind/Dhcpd, Wordpress, X2Go, Odoo, node.js, Owncloud, Lime Survey, and many other instances.

The interoperable, the efficient and the versatile linux kernel virtualization technology is working in any scenario. If the code has no limits, lack of imagination, of ressources or in infrastructure design are sources of frustrations.

###  Service offered

The service offered by this script is a *gentleman agreement* between foreign images download  tools (virt-build, oz-tools) and owned semi-automatic installation for KVM guests (libvirtd domains). It combines automatic gold image generation to clone and cloning operations.

But the libvirt library authorize some interoperable perspectives as the choice of the hypervisor (Xen, LXC, ESXi, cloud), remote procedures or live migrations options.

For every day usage, consider that you are root on the development system (hypervisor system). You can read the logs displayed on the console or turn off the verbose mode for totally automatic usage. Also consider that you are working on a build server for virtual guests. After this you can use your guests as lab/dev machines or migrate them to their production environment.

### Saving ressouces

The concept save compute and storage ressources. If you host your own http repo or your repo proxy on the hypervisor for availability, performance and portability, you can optimize the installation process.

As suggered, it is useful to start the new domains on a dev network bridge for dhcp and dns service avaibility. In the next step, you can add a second network interface binded to the "prod" bridge or connect the main interface on a new bridge, or migrate them. Executing this configuration management task by hand is the hard way. Please consider some automation tools as Ansible.

#### Optimization approach

The process optimization is done by :

* The creation of only one new fresh install of Centos 7 (configurable). This new install is **life limited** only for quick and optimized cloning.
* The disk of this guest template is syspreped and sparsifyed.
* The guest template is erased (destroy, undefine, rm temporary disks) after cloning.
* The new guest domains are started for monitoring.  

### Procedure followed by this script

1. Verify the presence of future domains in the libvirtd "defined" domains. At this moment, if it is positive, the script asks you what to do with them. You can easily turn off this feature and choose a default action.
* Build a fresh minimal Centos 7 installation by HTTP repo (local or remote depending the configuration and the kickstart template. This procedure has his own process and start here in background as autonomous. The script is paused during the installation.
* Sysprep and sparsify the disk of the new fresh install called template in our context. This procedure takes less than 10 minutes depending the host and the network access performance.
* Clone the template some much times that you have defined. The network configuration file and the hostname are adapted.
* The template is erased 
* and the new domains are started for monitoring.

### Script Usage

Before anything please verify those default variables in the script :

* bridged network `bridge=virbr0`
* path to domain images `vol=/var/lib/libvirt/images`
* local path to template kickstart file `data=/var/www/html/conf`
* http path to template kickstart file `conf=http://$bridgeip4/conf`
* http path to an installation mirror `mirror=http://$bridgeip4/repo`
    * Working public mirrors
        * mirror=http://centos.mirrors.ovh.net/ftp.centos.org/7/os/x86_64
        * mirror=http://ftp.belnet.be/ftp.centos.org/7/os/x86_64
        * mirror=http://mirror.i3d.net/pub/centos/7/os/x86_64

You are invited to specify three arguments after the command. You must choose or indicate :

1. tree models (baselines) of guests : 
    * small
    * medium
    * large
* two types of Kickstart file (depending if you must own a local http server) :
    * local or
    * http
* the list of your new KVM domains : "vm00 vm01 vm02 vm3"


### Wished corrections

* A way to disable interaction with users (interactive=on/off)
* Problem procedure to exit the program with informations display.
* Test : check erroneous arguments
* After template creation, verify the good starting of the image (function alive).
Without this feature, if the template building fail for any reason, it try to continue but it do not find anything to clone. Alive with :
    1. wait 30
    * grep $uuid in virsh net-dhcp-leases
    * get $ipadd of the guest template
    * ping -c 1 $ipadd
        * --> if responding, continue
        * --> if not wait 30  
    * continue
* Limitation of simultaneous domain starting and reporting.
* define the network bridge as dns forwarder for the host `/etc/resolv.conf`, write the NS resolution of the new guests in `/etc/hosts` file on the hypervisor, print the Ansible inventory.

## others

* *x`virsh`* domain list as argument.
* add live new NIC and sparsed storage
