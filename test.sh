dom_info ()
{
echo "# To be add to dns resolver for $uidtemp build $nb domains"
local domc=$(virsh list --all --name)
for domn in $(echo "$domc"); do
        domipc=$(virsh net-dhcp-leases default | grep $domn | awk -F' ' '{print $5}')
        domip=$(echo ${domipc%/*})
        echo -e "\n${domn}\n"
        echo $(ping -c 1 $domip 2> /dev/null | head -n 2)
done
}

dom_info
