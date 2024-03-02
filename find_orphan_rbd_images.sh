#!/bin/bash
# NAME: find_orphan_rbd_images.sh
#
# DESCRIPTION:
# Script tries to locate stale/orphaned RBD images which no longer referenced
# by existing PVs. The respective PVs have already been deleted.  This can 
# happen when "reclaimPolicy: Retain" is set and you manually delete the PV,
# the RBD image will remain consuming storage space until it is removed.
# See https://github.com/rook/rook/issues/4651
#
# NOTE: Script requires the rook-ceph plugin for kubectl installed

AUTHOR="Richard J. Durso"
RELDATE="03/02/2024"
VERSION="0.10"
###############################################################################

# ---[ Init Routines ]---------------------------------------------------------
required_utils=("kubectl" "kubectl-rook_ceph")

# Confirm required utilities are installed.
for util in "${required_utils[@]}"; do
  [ -z "$(command -v "$util")" ] && echo "ERROR: the utility '$util' is required to be installed." >&2 && exit 1
done

# Create working directory and trap to cleanup on exit
MYTMPDIR="$(mktemp -d)"
trap 'rm -rf -- "$MYTMPDIR"' EXIT

# ---[ Usage Statement ]------------------------------------------------------
__usage() {
  echo "
  ${0##*/} | Version: ${VERSION} | ${RELDATE} | ${AUTHOR}

  Locate stale/orphaned Ceph RBD images no longer referenced by an existing PV
  -----------------------------------------------------------------------------

  This script will look at all existing PVs (Persistant Volumes) and cross
  reference this to RBD images stored in Ceph to determine which RBD images
  are no longer referenced.  This happens when "reclaimPolicy: Retain" is set
  and you manually delete the PV, the RBD image will remain consuming storage
  space until the image is removed.

  Script is designed for Kubernetes' Rook-Ceph. Required local kubectl with
  Rook-Ceph krew plugin installed.

  -a, --all         : Check all RBD Images (in pool of the storage class type)
  -d, --debug       : Show additional information
  -p, --pool        : Name of Ceph RBD Block Pool to check
  -c, --class       : Name of Ceph Storage Class to check
  -i, --image       : Check single RBD Image name
  -n, --namespace   : Kubernetes namespace where rook-ceph is installed
  -h, --help        : This usage statement
  -v, --version     : Script version

  ${0##*/} [--debug] -a [--pool ${POOL_NAME}] [--class ${STORAGE_CLASS}] [--namespace ${ROOK_NAMESPACE}]

  ${0##*/} [-d ] -i csi-vol-<image_name> [-p ${POOL_NAME}] [-c ${STORAGE_CLASS}] [-n ${ROOK_NAMESPACE}]
  "
}  

# ---[ Error Handler ]---------------------------------------------------------
# Write error messages to STDERR.

__error_message() {
  echo "[$(date "$timestamp_format")]: $*" >&2
}

# ---[ Create list of known PVs ]----------------------------------------------
# PVs are not namespaced. A complete list of PVs will be fetched. The list will
# be filtered to the specified Ceph storage class. Each Ceph RBD image will be
# checked against this list

__load_pv_list_by_storage_class() {
  # get list of PVs using the storage class
  kubectl get pv -o 'custom-columns=STORAGECLASS:.spec.storageClassName,VOLUMEHANDLE:.spec.csi.volumeHandle' | grep -E "(^|\s)${STORAGE_CLASS}(\$|\s)" > "${MYTMPDIR}/pv_list.txt"
}

# ---[ Create List of RBD Images ]---------------------------------------------
# Get a list of all Ceph RBD block images for the specified Ceph Block Pool.
# Each image is named like "csi-vol-973cd687-edab-4a8a-aaf9-39a820cad02d"
# Any CSI snapshots will be filted out

__load_rbd_images_by_ceph_block_pool() {
  if [ -n "$1" ]; then
    if kubectl -n "${ROOK_NAMESPACE}" exec -it deploy/rook-ceph-tools -- rbd status --pool "${POOL_NAME}" "$1" > /dev/null 2> /dev/null
    then 
      RBD_IMAGES="$1"
    fi
  else
    mapfile -t RBD_IMAGES < <(kubectl -n "${ROOK_NAMESPACE}" exec -it deploy/rook-ceph-tools -- rbd ls "${POOL_NAME}" | sed '/^csi-snap-.*/d')
  fi
}

# ---[ Confirm Ceph Pool Name ]------------------------------------------------
__test_ceph_pool_name() {
  if ! kubectl -n "${ROOK_NAMESPACE}" exec -it deploy/rook-ceph-tools -- rbd pool --pool "${POOL_NAME}" stats > /dev/null 2> /dev/null
  then
    __error_message "Invalid Ceph Pool Name specified: ${POOL_NAME}"
    exit 2
  fi
}

# ---[ Confirm Storage Class ]-------------------------------------------------
__test_ceph_storage_class() {
  if ! ( kubectl get sc "${STORAGE_CLASS}" | grep -q "ceph")
  then
    __error_message "Invalid Ceph Storage Class specified: ${STORAGE_CLASS}"
    exit 2
  fi
}

# ---[ Initial Variables and Load Data ]---------------------------------------
# Initialize variables and load PV and RBD Images

__init() {

  __load_pv_list_by_storage_class
  if [ "$1" == "image" ]; then
    if [ -z "$2" ]; then
      __error_message "Image flag specified without image name"
      exit 2
    fi
    __load_rbd_images_by_ceph_block_pool "$2"
  else
    __load_rbd_images_by_ceph_block_pool
  fi
  # Tracking counters for summary line
  PV_TOTAL=$(< "${MYTMPDIR}/pv_list.txt" wc -l)
  PV_FOUND=0
  IMAGES_TOTAL="${#RBD_IMAGES[@]}"
  IMAGES_TO_DELETE=0
  IMAGES_TO_SKIP=0

  if [ "$DEBUG" == "$TRUE" ]; then
    echo "PVs found: ${PV_TOTAL}"
    echo "RBD Images: ${IMAGES_TOTAL}"
    echo
  fi
}

# ---[ Default Values ]--------------------------------------------------------
POOL_NAME="ceph-blockpool"
STORAGE_CLASS="ceph-block"
ROOK_NAMESPACE="rook-ceph"

FALSE=0
TRUE=1
DEBUG="$FALSE"
timestamp_format="+%Y-%m-%dT%H:%M:%S%z"  # 2023-09-25T12:56:02-0400

# ---[ Process Argument List ]-------------------------------------------------
if [ "$#" -ne 0 ]; then
  while [ "$#" -gt 0 ]
  do
    case "$1" in
      -a|--all)
        __init
        __test_ceph_pool_name
        __test_ceph_storage_class
        ;;
      -d|--debug)
        DEBUG="$TRUE"
        ;;
      -p|--pool)
        POOL_NAME="$2"
        ;;
      -c|--class)
        STORAGE_CLASS="$2"
        ;;
      -n|--namespace)
        ROOK_NAMESPACE="$2"
        ;;
      -h|--help)
        __usage
        exit 0
        ;;
      -i|--image)
        __init "image" "$2"
        __test_ceph_pool_name
        __test_ceph_storage_class
        ;;
      -v|--version)
        echo "$VERSION"
        exit 0
      ;;
      --)
        break
        ;;
      -*)
        __error_message "Invalid option '$1'. Use --help to see the valid options"
        exit 2
      ;;
    # an option argument, continue
    *)  ;;
    esac
    shift
  done
else
  __usage
  exit 1
fi

for IMAGE in "${RBD_IMAGES[@]}"; do
  # remove the "csi-vol-" prefix when searching
  FIND_IMAGE="${IMAGE#"csi-vol-"}"
  # remove any trailing CRs
  FIND_IMAGE="${FIND_IMAGE%$'\r'}"
  IMAGE="${IMAGE%$'\r'}"

  # if the RBD image is not listed in the PV list then look closer at the image
  if (awk '$2~/'"${FIND_IMAGE}"'/{ print $2 }' "${MYTMPDIR}/pv_list.txt" | grep -q .)
  then
    if [ "$DEBUG" == "$TRUE" ]; then
      echo "RBD Image: ${IMAGE} has PV, skipping."
      PV_FOUND=$((PV_FOUND+1))
    fi
  else
    # Determine if the RBD image has any watchers
    if (kubectl -n "${ROOK_NAMESPACE}" exec -it deploy/rook-ceph-tools -- rbd status --pool "${POOL_NAME}" "${IMAGE}" | grep -q "Watchers: none")
    then
      echo "--[ RBD Image can be deleted! ]----------------------------------------"
      # supress "warning: fast-diff map is not enabled"
      kubectl -n "${ROOK_NAMESPACE}" exec -it deploy/rook-ceph-tools -- rbd --pool "${POOL_NAME}" du "${IMAGE}" | grep -v "fast-diff"
      if [ "$DEBUG" == "$TRUE" ]; then
        # show additional details is debug is enabled
        kubectl -n "${ROOK_NAMESPACE}" exec -it deploy/rook-ceph-tools -- rbd --pool "${POOL_NAME}" info "${IMAGE}" | grep 'timestamp\|size\|count'
      fi
      echo "-----------------------------------------------------------------------"
      IMAGES_TO_DELETE=$((IMAGES_TO_DELETE+1))
    else
      if [ "$DEBUG" == "$TRUE" ]; then
        echo "RBD Immage: ${IMAGE} has watcher, skipping."
        IMAGES_TO_SKIP=$((IMAGES_TO_SKIP+1))
      fi
    fi
  fi
done

if [ "$DEBUG" == "$TRUE" ]; then
  echo
  echo "Matched ${PV_FOUND} of ${PV_TOTAL} PVs. Possible ${IMAGES_TO_DELETE} RBD Images can be deleted of the ${IMAGES_TOTAL} total images (${IMAGES_TO_SKIP} considered still had watchers)"
  echo
fi