#!/bin/bash
# required run by root

# Note: make sure followings has been done if you use USB
#: ${USB_DEVICE:="/dev/sdb"}
#: ${USB_PATH:="/Storage"}
#mkdir $USB_PATH
#mount -t vfat $USB_DEVICE $USB_PATH -o uid=1000,gid=1000,utf8,dmask=027,fmask=137
#cd $USB_PATH

: ${PORT:=5011}
WORKING_PATH=$(dirname $(readlink -f $0))
IMAGE_REGISTRY_FILE=$WORKING_PATH/image_registry

function prepare_docker_daemon {
# Note: this function is tight coupling with stx brootscrapt process, which is
# an implement of a workaround to avoid docker daemon being initialized, caused
# by docker root path remounting, during controller prevision. 

  local LOCKFILE=/var/lock/.puppet.applyscript.lock
  local LOCK_FD=200
  local LOCK_TIMEOUT=60

  eval "exec ${LOCK_FD}>$LOCKFILE"

  while :; do
    flock -w $LOCK_TIMEOUT $LOCK_FD && break
    logger -t $0 "Failed to get lock for puppet applyscript after $LOCK_TIMEOUT seconds. Trying again"
    sleep 1
  done

  TMPDIR=$(pwd)/temp
  mkdir $TMPDIR
  cat > $TMPDIR/fs_docker_bootstrap.pp << EOF
Exec {
  timeout => 600,
  path => '/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin:/usr/local/sbin'
}

include ::platform::filesystem::docker::bootstrap
EOF

  local PUPPET_MODULES_PATH=/usr/share/puppet/modules:/usr/share/openstack-puppet/modules
  local PUPPET_MANIFEST=$TMPDIR/fs_docker_bootstrap.pp
  puppet apply --debug --trace --modulepath ${PUPPET_MODULES_PATH} ${PUPPET_MANIFEST}

  rm $PUPPET_MANIFEST
  sudo systemctl start docker
}

function start_offline_registry {
  sudo docker load -i $IMAGE_REGISTRY_FILE
  IMAGES_PATH=$WORKING_PATH/images

  sudo docker rm -f offline-registry
  sudo docker run -d -p $PORT:5000 --restart=always -v $IMAGES_PATH:/var/lib/registry --name offline-registry registry
}



prepare_docker_daemon
start_offline_registry

