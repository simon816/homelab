#!/bin/bash

CLOUDIMG="/data/Virtualization/IMG/ubuntu-22.04-minimal-cloudimg-amd64.img"

IMGDIR="/var/lib/libvirt/images"

INITIMG="lab-base.qcow2"

create_initial_image() {
#    set -e
    [ -e "$IMGDIR/$INITIMG" ] && return 0
    sudo qemu-img convert -O qcow2 "$CLOUDIMG" "$IMGDIR/$INITIMG"
    sudo qemu-img resize "$IMGDIR/$INITIMG" 4G

    genisoimage -output init.iso -volid cidata -joliet -rock bootstrap/*

    # starts the bootstrap VM and waits until shutdown
    virt-install \
        --name bootstrap-init-firstboot \
        --memory 512 \
        --vcpus 1 \
        --os-type linux \
        --os-variant ubuntu20.04 \
        --network bridge=virbr0,model=virtio \
        --nographics \
        --disk path="$IMGDIR/$INITIMG",bus=virtio \
        --disk path=init.iso,bus=virtio \
        --import

    virsh undefine bootstrap-init-firstboot
    rm init.iso

    # we're now left with INITIMG containing the base OS
}

create_disk() {
    file="$IMGDIR/$1.qcow2"
    if [ ! -e "$file" ]
    then
        echo Creating disk $file
        sudo cp "$IMGDIR/$INITIMG" "$file"
        sudo chown libvirt-qemu:kvm "$file"
    fi
}

if [ "$1" == "disks" ]
then
    create_disk gateway
    create_disk dbserver2
    exit
fi

CONTROLLER=controller
MAC=52:54:00:dc:86:46

create_controller() {
    [ -z "$(virsh list --all | grep $CONTROLLER)" ] || return 0

    create_disk $CONTROLLER

    virt-install \
        -n $CONTROLLER \
        --os-type=Linux \
        --os-variant ubuntu20.04 \
        --ram=512 \
        --vcpus=1 \
        --import \
        --disk path=$IMGDIR/$CONTROLLER.qcow2,bus=virtio \
        --network network=default \
        --mac=$MAC \
        --nographics \
        --print-xml \
        | virsh define /dev/stdin
}

create_initial_image
create_controller

virsh start $CONTROLLER

while :
do
    leases=$(virsh net-dhcp-leases default --mac $MAC)
    lnum=$(echo "$leases" | wc -l)
    if [ $lnum -ne 3 ]
    then
        sleep 1
        continue
    fi
    ip=$(echo "$leases" | tail -n 1 | tr -s ' ' | cut -d' ' -f6 |cut -d'/' -f1)
    break
done

echo "Got IP: $ip"

while :
do
    nc -z $ip 22
    if [ $? -eq 0 ]; then break; fi
    echo "Wait for SSH"
    sleep 1
done

echo "SSH open"

scp -o "StrictHostKeyChecking no" -i ~/.ssh/ansible_rsa ~/.ssh/ansible_rsa* "ansible@$ip:~/.ssh/"

ssh -i ~/.ssh/ansible_rsa ansible@$ip <<'EOF'
sudo apt update
sudo apt install --yes git software-properties-common
ssh-keyscan 192.168.122.1 >> ~/.ssh/known_hosts
mv .ssh/ansible_rsa .ssh/id_rsa
mv .ssh/ansible_rsa.pub .ssh/id_rsa.pub
rm -rf homelab
git clone simon@192.168.122.1:~/code/Lab/homelab
mkdir homelab/certs
mkdir homelab/vpn-config
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install --yes ansible
EOF

scp -i ~/.ssh/ansible_rsa ~/code/Lab/private/certs/* "ansible@$ip:~/homelab/certs"
scp -i ~/.ssh/ansible_rsa ~/code/Lab/private/vpn-config/* "ansible@$ip:~/homelab/vpn-config"
