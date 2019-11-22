#!/bin/bash


imgdir=/var/lib/libvirt/images

for disk in controller cloud dbserver gateway sinkhole dev
do
    file=$imgdir/$disk.qcow2
    if [ ! -e $file ]
    then
        echo Creating disk $file
        sudo qemu-img create -f qcow2 -o backing_file=$imgdir/ubuntu_base.qcow2 $file
        sudo chown libvirt-qemu:kvm $file
    fi
done

mac=52:54:00:dc:86:46

exists=$(virsh list --all | grep controller)

if [ -z "$exists" ]
then
    virt-install \
        -n controller \
        --os-type=Linux \
        --os-variant ubuntu18.04 \
        --ram=512 \
        --vcpus=1 \
        --import \
        --disk path=$imgdir/controller.qcow2,bus=virtio \
        --network network=default \
        --mac=$mac \
        --graphics spice \
        --print-xml \
        | virsh define /dev/stdin
fi

virsh start controller

while :
do
    leases=$(virsh net-dhcp-leases default --mac $mac)
    lnum=$(echo "$leases" | wc -l)
    if [ ! $lnum -eq 3 ]
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
    sleep 1
done

echo "SSH open"

scp -i ~/.ssh/ansible_rsa ~/.ssh/ansible_rsa* "ansible@$ip:~/.ssh/"

ssh -i ~/.ssh/ansible_rsa ansible@$ip <<'EOF'
ssh-keyscan 192.168.122.1 >> ~/.ssh/known_hosts
mv .ssh/ansible_rsa .ssh/id_rsa
mv .ssh/ansible_rsa.pub .ssh/id_rsa.pub
git clone simon@192.168.122.1:~/Documents/labconfig
mkdir labconfig/certs
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install --yes ansible
EOF

scp -i ~/.ssh/ansible_rsa ~/Documents/private/certs/* "ansible@$ip:~/labconfig/certs"
