
Distributed CI setup and OSP Installer
======================================

##Purpose

The distributed CI system is a framework created by Redhat to enable partners to validate frequent preview releases of Openstack on a Partner Lab setup.

After the physical hardware is setup a combination of Ansible playbooks, Python and Bash scripts are used to bring up the undercloud and overcloud stacks on a cluster of compute/controller nodes. 

After the overcloud is installed, the CI system also initiates a series of tempest tests on the overcloud. The test results are then uploaded to a Redhat CI server where the results and logs of the test are archived. All debug logs pertaining to various stages of undercloud and overcloud setup are also archived in the CI system and accessible via the CI portal.


##Hardware components of the DCI setup

- DCI jumpbox : The 'jumpbox' is nothing more that a VM on which a DCI agent would be installed. The VM needs to be able to have an IP address in the lab network and should be able to reach both the OSP director node (within lab) and external world (via. lab proxies).

- OSP Director: This is the entity that hosts the OpenStack undercloud and orchestrates the lifecycle of the OpenStack overcloud on a set of controller/compute hardware. The OSP director is hosted on a separate UCS server in the VTS DCI setup. It has exclusive NICs to the lab management network and another to reach all the computes/controller hardware. The director node also has an exclusive NIC to the CIMC.

- Controllers and Computes: These are the nodes on which the OpenStack overcloud is installed. Each controller/compute node maps to a physical UCS server in the VTS lab. Each node has one NIC for the CIMC, one for the OpenStack API communication and PXE boot and one for the tenant traffic. The Controller and Compute nodes do NOT have 'management' IP addresses in the lab network. However, they can access both the external world and the lab network using director as the gateway. 


##Software components

- DCI agent: The agent is the entity that pulls in latest set of software for a given OpenStack version. It then 'orchestrates' the install of the director node, buildup of the undercloud and overcloud using 'hooks'.  The agent uses Ansible playbooks to orchestrate the bring up of the undercloud, overcloud and runnign the tempest test suite. Once the DCI jumpbox VM is setup with (RHEL OS), follow the steps mentioned in :
  https://doc.distributed-ci.io/dci-ansible-agent/ to install and setup the DCI agent.

As for the generic install requirements for the DCI agent, please refer RH document:
  https://github.com/redhat-cip/dci-ansible-agent#requirements

- OSP installer:  Although the DCI agent is responsible for bringing up the undercloud and overcloud, it cannot be generic enough to cater to all partner environments. Hence they rely on partner specific hooks to implement different 'stages' of the CI setup. These hooks depend on deployment specific configuration files to build out the undercloud and overcloud. The code that the CI hooks call into is Cisco VTS specific and is currently hosted here:
  https://github.com/muthumayan/vts-dci


  Note: The code for these hooks come from CPSG team in Boxborough (the original repo being: https://github.com/sadasu/osp7-install-dci. These hooks
  themselves make use of Ansible for driving the build up of director, undercloud and overcloud. For historical reasons, the hooks code use an older 
  version of Ansible and hence is run in a separate python virtual environment. 


  The OSP installer does the 'bulk' of the work in initializing the director node, installing the undercloud and overcloud nodes. 


- Tempest test suite: After the overcloud is functional, the DCI agent initiates the tempest suite of tests. 


- CI server and portal:  The CI server is reachable at the URI: https://www.distributed-ci.io/login

  Credentials for logging in:  rmaddipu@cisco.com.1 / rangam

  Within a login, one can create different team (for different activities). Each team is also associated with a remote CI. The setup of team and 
  remote CI is handled by Redhat (email: distributed-ci@redhat.com)

  In the portal, all the jobs that were run on the DCI setup are visible and each job has an archive of all the activities that happened on the run.

  Once a team and a remote CI are created, Redhat prepares a list of environmental variables that would need to be setup on the jumphost. To this
  end, there is a file called 'remoteci.sh' that is generated and downloadable from the CI server. This file needs to be saved in the jumphost and
  should be sourced prior to starting any 'integration' tests.


##Starting a CI job

The CI activity can only be initiated on the jumphost (by any user logged in to the jumphost). There is a systemd service created for starting the 
CI job. 

There are several configuration files (each one serving a different purpose) used in the CI job. A brief of each of them is given below:

 - /etc/dci-ansible-agent/settings.yml: Config in this file is primarily related to the DCI setup. The jumpbox IP, director node IP, RHEL credentials,
   RHEL pool, DCI system login, OpenStack version, Tempest settings and a pointer to overcloud config file are controlled via this file. 
 - overcloud config file: This file contains all configurable knobs for customizing the overcloud and undercloud - based on the lab network and 
   hardware settings. In VTS case, this is the file vts_osp.conf
 - base.conf: This configuraton file is used by the OSP installer. It has some overlap with the above vts_osp.conf. We may have to clean these two
   files to have a proper definition for each of these configuration files.
 - ospX.conf: This configuration file is OSP version dependent and has pointers to OSP version specific YUM repos, patches, disk images etc.

Each of the above configuration files lack sufficient documentation and would require some effort to figure out if several of the settings are 
relevant now and then clean them up.

After setting up all the above config files, the job can be started using:

source /path/to/remoteci.sh && systemctl start dci-ansible-agent


 
##State of CI jobs

The CI jobs tranistion through several states in carrying out the integration tests. In brief:
 

- New:  This is primarily DCI agent activity. It would reach the server and bring in latest set of software for OpenStack version.
- Pre-run: This is where the 'hooks' come into play for setting up the director node. 
- Running: In this state, the 'hooks' are intended to set up the undercloud and overcloud 
- Post-run: This is the state where tempest tests are run.



OSP bootstrap
-------------

This is the python wrapper script invoked by the DCI 'hooks' to trigger creation of the undercloud and overcloud. The script runs in 
a virtual environment. The 'hook' callbacks need to do the following to invoke the appropriate portion of undercloud/overcloud installation.

Clone the repo from: https://github.com/muthumayan/vts-dci to a local directory on the jumpbox (currently set to /tmp/install-vts-dci).
Change directory to /tmp/install-vts-dci and activate the virtualenv. Typically you will find the following code in the hooks yaml files:

$ cd /tmp/install-vts-dci
$ virtualenv .venv
$ source .venv/bin/activate
$ pip install -r requirements.txt
$ python setup.py develop
$ osp_bootstrap <optional parameters> <type of installation>

For help see: `osp_bootstrap --help`

Testbed Configuration
=====================

[DCI Lab setup](images/DCI-setup.png)

Physical Setup
--------------
All node types (controller, compute, ceph) need same NIC ordering due to use of per-node interface templates.

Each node has multiple NICs - NIC1, NIC2 and NIC3.

### NICs
1. Controller NICs
    1. NIC2: This NIC is used for both OpenStack API, Storage, StorageMgmt as well as to PXE boot the node (from director). This NIC is 
             connected to the br-ctlplane bridge (enp1s0f1)
    1. NIC3: This NIC is used for tenant traffic. This NIC is connected to the br-tenant bridge. (enp6s0f0/enp7s0f0)
    1. NIC1: THis NIC is used for external management access to tbe node (enp1s0f0)
1. Compute NICs
    1. NIC2: This NIC is used for both OpenStack API, Storage, StorageMgmt as well as to PXE boot the node (from director). This NIC is 
             connected to the br-ctlplane bridge. (eno2/enp1s0f1)
    1. NIC3: This NIC is used for tenant traffic. This NIC is connected to the br-tenant bridge. (enp6s0f0/enp7s0f0)
    1. NIC1: Unused
1. Director node
    1. eth1: This NIC is used for both OpenStack API, Storage, StorageMgmt as well as to PXE boot the node (from director). This NIC is 
             connected to the br-ctlplane bridge. 
    1. eth0: This NIC is used for lab management access to the director.


### Testbed Settings 
1. osp_director_node: The jumphost needs IP reachability to the OSP director node. These settings are provided in the undercloud_ip setting of settings.yaml
1. Switch: There are two switches in this setup (refer figure in: https://cisco.jiveon.com/docs/DOC-1833964#jive_content_id_Testbed_Name_TBOSPD10_RHEL)
   One switch (TOR1) is used for interconnecting the openstack control plane & PXE boot netwrok between the controller, compute and director nodes
   One switch (TOR2) is used for tenant VM traffic on the computes.
   Switch configuration on ToR1 is hard-coded by manual configuration
   Switch configuration on ToR2 would be managed by VTC. 
1. All NIC settings
   Instead of making this configurable via. base.conf, currently all configuration is dumped into compute.yaml
   and controller.yaml and is part of the testbed template configuration under:
   osp_installer/ansible/roles/osp-overcloud/templates
1. SJC lab proxy settings: osp7_installer/conf_common/sj.conf
1. Default config can be found in: osp_installer/conf_common/base.conf. THis file is a mix of all sort of configuration pertaining to undercloud/overcloud.
   May need to split this into more manageable number of knobs.
1. List of overcloud nodes: Found as variable 'overcloud_nodes' in vts_osp.conf. This list is directly copied over as instackenv.json on the testbed.
1. Director Node config (in vts_osp.conf)

   director_node_hostname = 
   director_node_ssh_ip = 
   director_node_ssh_username = 



TODO
-----
1. Create a directory in git to store contents of the hooks - for VTS
2. Create a copy of the network-environment.yaml and network-isolation.yaml (if required) in git.
3. Remove unncessary repetition of variable in both .conf files and overcloud configuration files. Just copy them over.
3. Use the latest overcloud installation procedure provided in 2.6.1 to insert ML2 plugin into the overcloud controllers.
4. Connect to VTC. 
5. Ensure that VTC can manage the ToR for setting up VM traffic.
