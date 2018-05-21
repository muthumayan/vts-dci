#! /bin/bash

set -e
set -x

DISK_IMAGE=$(realpath ${1:-./overcloud-full.qcow2})

RPM_URLS=({{ rpms_for_image }})
RPM_FILES_ON_DISK=


echo "Updating image: $DISK_IMAGE"
#echo "Using Puppet Neutron ref: ${PUPPET_REF}"

mkdir -p /tmp/update-osp-image
cd /tmp/update-osp-image
cp $DISK_IMAGE .

add_rpm_from_url () {
  rpm_url=$1
  file_name=${rpm_url##*/}
  curl -o "${file_name}" "${rpm_url}"
  virt-customize -a overcloud-full.qcow2 --upload ${file_name}:/tmp/${file_name}
  RPM_FILES_ON_DISK="${RPM_FILES_ON_DISK} /tmp/${file_name}"
}

correct_selinux_context () {
    ref_dir=$1
    target_dir=$2
    virt-customize -a overcloud-full.qcow2 --run-command "chcon -Rv --reference=${ref_dir} ${target_dir}"
}

# install virt-customize
# sudo yum install -y libguestfs-tools

# set password for development
virt-customize -a overcloud-full.qcow2 --root-password password:cisco123
virt-customize --selinux-relabel -a overcloud-full.qcow2 --run-command "sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config"
virt-customize --selinux-relabel -a overcloud-full.qcow2 --run-command "sed -i 's/PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config"

# now patch the image with RPMs
for rpm_url in ${RPM_URLS[*]}
do
  add_rpm_from_url "${rpm_url}"
done

if [ -n "$RPM_FILES_ON_DISK" ]; then
  virt-customize --selinux-relabel -a overcloud-full.qcow2 --run-command "rpm -Uvh ${RPM_FILES_ON_DISK}"
  virt-customize -a overcloud-full.qcow2 --run-command "rm ${RPM_FILES_ON_DISK}"
fi


{% for patch_info in patch_infos %}
# create {{ patch_info['name'] }}-{{ loop.index }}
if [ ! -d "{{ patch_info['name'] }}-{{ loop.index }}" ]; then
    git init {{ patch_info['name'] }}-{{ loop.index }}
fi

cd {{ patch_info['name'] }}-{{ loop.index }}
{% if 'ref' in patch_info %}
git fetch https://review.openstack.org/openstack/{{ patch_info['name'] }} {{ patch_info['ref'] }} && git checkout FETCH_HEAD
git format-patch -n HEAD^ --no-prefix --stdout > /home/stack/{{ patch_info['name'] }}-{{ loop.index }}.patch
{% elif 'patchfile' in patch_info %}
cp /home/stack/images/{{patch_info['patchfile'] }} /home/stack/{{ patch_info['name'] }}-{{ loop.index }}.patch
{% endif %}
cd ..

virt-customize --selinux-relabel -a overcloud-full.qcow2 --upload /home/stack/{{ patch_info['name'] }}-{{ loop.index }}.patch:/tmp
{% if 'path' in patch_info %}
virt-customize --selinux-relabel -a overcloud-full.qcow2 --run-command "patch -f -d {{ patch_info['path'] }} < /tmp/{{ patch_info['name'] }}-{{ loop.index }}.patch"
{% endif %}
{% endfor %}


## first udpate all the openstack RPMs
#virt-customize -a overcloud-full.qcow2 --run-command 'subscription-manager register --user={{ rhel_username }} --password={{ rhel_password }}'
#virt-customize -a overcloud-full.qcow2 --run-command 'subscription-manager attach --pool={{ rhel_pool }}'
#virt-customize -a overcloud-full.qcow2 --run-command 'subscription-manager repos --disable=*'
#virt-customize -a overcloud-full.qcow2 --run-command 'subscription-manager repos --enable=rhel-7-server-openstack-7.0-rpms'
#virt-customize -a overcloud-full.qcow2 --run-command 'yum makecache'
#virt-customize -a overcloud-full.qcow2 --run-command 'yum update -y'
#virt-customize -a overcloud-full.qcow2 --run-command 'yum clean all'


# correct SELinux security context
correct_selinux_context '/usr/lib/python2.7/site-packages/neutron' '/usr/lib/python2.7/site-packages/networking_cisco*'
correct_selinux_context '/usr/lib/python2.7/site-packages/neutron' '/usr/lib64/python2.7/site-packages/lxml*'
correct_selinux_context '/usr/lib/python2.7/site-packages/neutron' '/usr/lib/python2.7/site-packages/UcsSdk*'
correct_selinux_context '/usr/lib/python2.7/site-packages/neutron' '/usr/share/openstack-puppet'

#virt-ls -a overcloud-full.qcow2 /usr/share/openstack-puppet/modules/neutron/manifests/plugins/ml2

#virt-customize -v -x --selinux-relabel -a overcloud-full.qcow2 --copy-in /usr/share/openstack-puppet/modules/neutron/manifests/plugins/ml2:/usr/share/openstack-puppet/modules/neutron/manifests/plugins/
virt-customize -v -x --selinux-relabel -a overcloud-full.qcow2 --copy-in /home/stack/images/config.py:/usr/lib/python2.7/site-packages/networking_cisco/plugins/ml2/drivers/cisco/ucsm/

# update 40-hiera-datafiles
#virt-customize --selinux-relabel -a overcloud-full.qcow2 --upload tripleo-puppet-elements/elements/hiera/os-refresh-config/configure.d/40-hiera-datafiles:/usr/libexec/os-refresh-config/configure.d

mv overcloud-full.qcow2 "${DISK_IMAGE}"
