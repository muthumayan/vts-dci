#!/bin/bash
openstack overcloud deploy \
--templates \
-e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
-e /home/stack/templates/network-environment.yaml \
--control-scale 3 \
--compute-scale 3 \
--control-flavor control \
--compute-flavor compute \
--neutron-network-type vxlan \
--neutron-tunnel-types vxlan \
--debug \
--log-file oclogs/overcloudDeploy_$(date +%m_%d_%y__%H_%M_%S).log \
--ntp-server ntp.esl.cisco.com \
--verbose --timeout 100
