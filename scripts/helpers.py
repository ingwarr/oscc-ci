#!/usr/bin/poython

import sys
sys.path.append('/usr/share/fuel-qa/')

from fuelweb_test.models import nailgun_client

def getOperationalCluster (fuel_ip):
  """
    return first operational cluster id
  """

  cluster_id = ''
  client = nailgun_client.NailgunClient(fuel_ip)
  for cluster in client.list_clusters():
    if cluster['status'] == 'operational':
      cluster_id = cluster['id']
      break;

  return cluster_id


def getClusterAttributes (fuel_ip):
  data={}
  client = nailgun_client.NailgunClient(fuel_ip)

  cluster_id = getOperationalCluster (fuel_ip)

  #If multiple cluster in operational status, first will be used.
  if cluster_id:
    data['mode'] = client.get_cluster(cluster_id)['mode']
    data['net_provider'] = client.get_cluster(cluster_id)['net_provider']

    if data['net_provider'] == 'neutron':
      data['net_segment_type'] = client.get_networks(cluster_id)['networking_parameters']['segmentation_type']

    attributes = client.get_cluster_attributes(cluster_id)

    data['volumes_ceph'] = attributes['editable']['storage']['volumes_ceph']['value']
    data['images_ceph'] = attributes['editable']['storage']['images_ceph']['value']
    data['ephemeral_ceph'] = attributes['editable']['storage']['ephemeral_ceph']['value']
    data['volumes_lvm'] = attributes['editable']['storage']['volumes_lvm']['value']
    data['public_ssl_services'] = attributes['editable']['public_ssl']['services']['value']

  return data

def translateClusterAttributes(data):
  message = ""
  if data:
    if data['public_ssl_services']:
      message+="TLS; "

    if data['mode'] == 'ha_compact':
      message+="mode: HA; "
    else:
      message+="mode: Simple; "

    if data['net_provider'] == 'neutron':
      if data['net_segment_type'].upper() == 'GRE':
        message+="Neutron with TUN; "
      else:
        message+="Neutron with %s; " % data['net_segment_type'].upper()

    if data['volumes_lvm']:
      message+="Cinder LVM; "
    else:
      message+="Ceph: "
      ceph_options = []

      if data['volumes_ceph']:
        ceph_options.append('volumes')
      if data['images_ceph']:
        ceph_options.append('images')
      if data['ephemeral_ceph']:
        ceph_options.append('eph. volumes')
      if ceph_options:
        message+=",".join(ceph_options)

  return message


def printClusterAttributes(fuel_ip):

  attr = getClusterAttributes(fuel_ip)
  message = translateClusterAttributes (attr)

  print message

def getClusterRelease (fuel_ip):
  release = ""
  client = nailgun_client.NailgunClient(fuel_ip)

  cluster_id = getOperationalCluster (fuel_ip)

  release = client.get_release(
              client.get_cluster(cluster_id)['release_id'])['name']

  return release


def printClusterRelease(fuel_ip):
  release = getClusterRelease(fuel_ip)
  rel = ""
  if 'ubuntu' in release.lower():
    rel = "Ubuntu 14.04"
  elif 'centos' in release.lower():
    rel = "Centos 6.5"

  print rel
