#!/bin/bash
# required run by root

work_path=$(dirname $(readlink -f $0))
: ${STORAGE_PATH:="$work_path/images"}

if [ ! -e $STORAGE_PATH ]; then
  mkdir -p $STORAGE_PATH
fi

: ${LOCAL_REGISTRY_PORT:=5000}
: ${THIRD_REGISTRY:=''}
: ${OFFLINE_IP:="localhost"}

IMAGES=()
DOCKER='docker'
REGISTRY_CONTIANER_NAME='offline-registry'
REGISTRY_IMAGE_FILE=$work_path/image_registry
REGISTRY_IMAGE_NAME=registry

function check_port {
  if [ $(sudo lsof -Pi :$LOCAL_REGISTRY_PORT -sTCP:LISTEN -t | wc -l) -ne 0 ]; then
    echo "port $LOCAL_REGISTRY_PORT is busy, pls set an avaliable port by -p"
    exit 2
  fi
}

function check_storage_folder {
  if [ ! -e $STORAGE_PATH ]; then
    mkdir -p $STORAGE_PATH
  else
    echo "warning: folder $STORAGE_PATH is existed, incremental upload images."
  fi
}

function check_docker_daemon_access {
  if [ "$(systemctl is-active docker)" = "inactive" ]; then
    sudo systemctl start docker
  fi

  if [ "$(systemctl is-active docker)" = "active" ]; then
    docker info >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      DOCKER='docker'
    else
      DOCKER='sudo docker'
    fi
  else
    echo "docker is not avaliable, pls install it."
    exit 3
  fi
}

function check_previous_registry {
  $DOCKER inspect $REGISTRY_CONTIANER_NAME >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    $DOCKER rm -f $REGISTRY_CONTIANER_NAME
  fi
}

function check_registry_image {
  local images=($($DOCKER images */registry --format "{{.Repository}}:{{.Tag}}" | sort -u))
  images+=($($DOCKER images registry --format "{{.Repository}}:{{.Tag}}" | sort -u))

  if [ ${#images[@]} -eq 0 ]; then
    $DOCKER load -i $REGISTRY_IMAGE_FILE
  else
    REGISTRY_IMAGE_NAME=${images[0]}
  fi
}

function env_check {
  check_storage_folder

  check_docker_daemon_access
  check_previous_registry

  check_port
  check_registry_image
}

function generate_registry_storage {
#  echo "$DOCKER run -d -p $LOCAL_REGISTRY_PORT:5000 --restart=always -v $STORAGE_PATH:/var/lib/registry --name $REGISTRY_CONTIANER_NAME $REGISTRY_IMAGE_NAME"
  $DOCKER run -d -p $LOCAL_REGISTRY_PORT:5000 --restart=always -v $STORAGE_PATH:/var/lib/registry --name $REGISTRY_CONTIANER_NAME $REGISTRY_IMAGE_NAME

  for image in ${IMAGES[@]}; do
    $DOCKER pull "$THIRD_REGISTRY/$image"
    $DOCKER tag "$THIRD_REGISTRY/$image" "$OFFLINE_IP:$LOCAL_REGISTRY_PORT/$image"
    $DOCKER push "$OFFLINE_IP:$LOCAL_REGISTRY_PORT/$image"
  done
}

function add_images_by_list {
  if [ ! -e $1 ]; then
    echo "file $1 do not existed"
    exit 1
  fi

  IMAGES+=($(cat $1))
}

newargs=`getopt -o s:p:i:r: --longoptions images:,port:,storage_path:,registry:,ip: -- "$@"`

if [ $? != 0 ] ; then
  echo "illegal arguments"
  exit 1
fi

eval set -- "$newargs"
while true; do
  case "$1" in
    -i|--images)
      add_images_by_list $2
      shift 2
      ;;
    -p|--port)
      LOCAL_REGISTRY_PORT=$2
      shift 2
      ;;
    -s|--storage_path)
      STORAGE_PATH=$2
      shift 2
      ;;
    -r|--registry)
      THIRD_REGISTRY="$2"
      echo "set $THIRD_REGISTRY as default docker registry"
      shift 2
      ;;
    --ip)
      OFFLINE_ip="$2"
      shift 2
      ;;

    --)
      shift
      break;
      ;;

    *)
      echo "error parsing arguments"
      exit 1;
      ;;
  esac
done

if [ ${#IMAGES[@]} -eq 0 ]; then
  echo "Warning: Images list is empty, nothing requried to do."
  exit 0
else
  IMAGES=($(echo ${IMAGES[*]}| sed 's/ /\n/g' |sort | uniq))
fi

env_check
generate_registry_storage

