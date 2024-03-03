
# Find Orphaned Ceph RBD Images

Script tries to locate stale/orphaned RBD images which are no longer referenced by existing PVs (Persistent Volumes). The respective PVs have already been deleted.  This can happen when `reclaimPolicy: Retain` is set and someone has manually delete the PV. The Ceph RBD image will remain consuming storage space until it is removed. See <https://github.com/rook/rook/issues/4651>

* The script will NOT remove any images for you. It will only help you identify images which can be removed.

* *Script requires the [krew](https://krew.sigs.k8s.io/) rook-ceph plugin for kubectl installed*

---

## Script Flags

```text
-a, --all         : Check all RBD Images (in pool of the storage class type)
-c, --class       : Name of Ceph Storage Class to check
-i, --image       : Check single RBD Image name
-n, --namespace   : Kubernetes namespace where rook-ceph is installed
-p, --pool        : Name of Ceph RBD Block Pool to check
-q, --quiet       : Reduced output
-h, --help        : This usage statement
-v, --version     : Script version
```

Defaults values for StorageClass, Ceph Pool and Namespace are shown in the usage statement / help screen example:

```text
find_orphan_rbd_images.sh [--quiet] -a [--pool ceph-blockpool] [--class ceph-block] [--namespace rook-ceph]

find_orphan_rbd_images.sh [-q ] -i csi-vol-<image_name> [-p ceph-blockpool] [-c ceph-block] [-n rook-ceph]
```

* If you need to use different values pass flags as required for your environment.

---

## List all RBD Images without PV

This is the normal way to run the script, scan all RBD images.

```shell
$ ./find_orphan_rbd_images.sh -a
RBD Image: csi-vol-00b2e9e7-65e7-11ed-a2b8-ea677ad8a25d has PV, skipping.
--[ RBD Image can be deleted! ]----------------------------------------
NAME                                          PROVISIONED  USED
csi-vol-00b3557e-624c-4892-8ed9-2d1ffc9683db       10 GiB  72 MiB
size 10 GiB in 2560 objects
snapshot_count: 0
create_timestamp: Wed Aug 23 12:21:36 2023
access_timestamp: Wed Aug 23 12:21:36 2023
modify_timestamp: Wed Aug 23 12:21:36 2023
-----------------------------------------------------------------------
--[ RBD Image can be deleted! ]----------------------------------------
NAME                                          PROVISIONED  USED
csi-vol-00b88510-767e-4c1e-93f4-bed07e559d6a        1 GiB  64 MiB
size 1 GiB in 256 objects
snapshot_count: 0
create_timestamp: Mon Feb 26 14:53:35 2024
access_timestamp: Mon Feb 26 14:53:35 2024
modify_timestamp: Mon Feb 26 14:53:35 2024
-----------------------------------------------------------------------

... ( lines removed for brevity )

--[ RBD Image can be deleted! ]----------------------------------------
NAME                                          PROVISIONED  USED
csi-vol-f8fb1f75-ab0c-4b80-b43c-1455215d2732       50 GiB  948 MiB
size 50 GiB in 12800 objects
snapshot_count: 6
create_timestamp: Mon Feb 26 15:56:01 2024
access_timestamp: Mon Feb 26 15:56:01 2024
modify_timestamp: Mon Feb 26 15:56:01 2024
-----------------------------------------------------------------------
--[ RBD Image can be deleted! ]----------------------------------------
NAME                                          PROVISIONED  USED
csi-vol-fbc03112-67c1-407c-b988-67073f6567a8       50 GiB  44 MiB
size 50 GiB in 12800 objects
snapshot_count: 0
create_timestamp: Wed Feb 28 16:00:04 2024
access_timestamp: Wed Feb 28 16:00:04 2024
modify_timestamp: Wed Feb 28 16:00:04 2024
-----------------------------------------------------------------------

Matched 34 of 34 PVs. Possible 76 RBD Images can be deleted of the 110 total images (0 considered still had watchers)
```

### List all RBD Images in quiet mode

Same as above with quiet mode flag set.

```shell
$ ./find_orphan_rbd_images.sh -q -a

--[ RBD Image can be deleted! ]----------------------------------------
NAME                                          PROVISIONED  USED
csi-vol-00b3557e-624c-4892-8ed9-2d1ffc9683db       10 GiB  72 MiB
-----------------------------------------------------------------------
--[ RBD Image can be deleted! ]----------------------------------------
NAME                                          PROVISIONED  USED
csi-vol-00b88510-767e-4c1e-93f4-bed07e559d6a        1 GiB  64 MiB
-----------------------------------------------------------------------
--[ RBD Image can be deleted! ]----------------------------------------
NAME                                          PROVISIONED  USED
csi-vol-01668759-1751-4138-bb75-8bcbb7f9f35a        1 GiB  96 MiB
-----------------------------------------------------------------------

...

--[ RBD Image can be deleted! ]----------------------------------------
NAME                                          PROVISIONED  USED
csi-vol-f42f0674-a75e-11ed-9116-960dd16b9a1c        1 GiB  760 MiB
-----------------------------------------------------------------------
--[ RBD Image can be deleted! ]----------------------------------------
NAME                                          PROVISIONED  USED
csi-vol-f8fb1f75-ab0c-4b80-b43c-1455215d2732       50 GiB  948 MiB
-----------------------------------------------------------------------
--[ RBD Image can be deleted! ]----------------------------------------
NAME                                          PROVISIONED  USED
csi-vol-fbc03112-67c1-407c-b988-67073f6567a8       50 GiB  44 MiB
-----------------------------------------------------------------------
```

---

## Remove orphaned image

Once you have identified images which can be removed, you can use the Rook-Ceph Toolbox Pod to remove images. The script will not remove any images for you. It will only help you identify images which can be removed.

From Rook-Ceph Toolbox pod:

```shell
$ rbd -p ceph-blockpool rm csi-vol-fcfe42b0-4218-442a-ba3e-0b793c31fd19
Removing image: 100% complete...done.
```

### Attempting to remove orphaned image with snapshots

RBD image with snapshots can not be removed.  If you try, an error message will be issued.

```shell
--[ RBD Image can be deleted! ]----------------------------------------
NAME                                          PROVISIONED  USED
csi-vol-f8fb1f75-ab0c-4b80-b43c-1455215d2732       50 GiB  948 MiB
size 50 GiB in 12800 objects
snapshot_count: 6
create_timestamp: Mon Feb 26 15:56:01 2024
access_timestamp: Mon Feb 26 15:56:01 2024
modify_timestamp: Mon Feb 26 15:56:01 2024
```

From Rook-Ceph Toolbox pod:

```shell
$ rbd -p ceph-blockpool rm csi-vol-f8fb1f75-ab0c-4b80-b43c-1455215d2732
2024-03-02T04:13:09.419+0000 7f9034c0f580 -1 librbd::api::Image: remove: image has snapshots - not removing
Removing image: 0% complete...failed.
rbd: image has snapshots with linked clones - these must be deleted or flattened before the image can be removed.
```

---

## Testing RBD Image with associated PV

If an RBD image is associated to a PV it is NOT a candidate for image removal. Below shows how to get the RBD IMage Name associated with a PV.

```shell
$ kubectl get pv pvc-fcc86902-bfb7-4ca7-ab21-7e69b8035227 -o 'custom-columns=NAME:.spec.claimRef.name,STORAGECLASS:.spec.storageClassName,IMAGENAME:.spec.csi.volumeAttributes.imageName'

NAME           STORAGECLASS   IMAGENAME
postgres16-2   ceph-block     csi-vol-b513c1de-6e88-4e0d-aa70-a114e8fd482f
```

Script indicates a PV is found and it will be skipped:

```shell
$ ./find_orphan_rbd_images.sh -i csi-vol-b513c1de-6e88-4e0d-aa70-a114e8fd482f
RBD Image: csi-vol-b513c1de-6e88-4e0d-aa70-a114e8fd482f has PV, skipping.

Matched 1 of 34 PVs. Possible 0 RBD Images can be deleted of the 1 total images (0 considered still had watchers)
```

### Example RBD Image with PV in quiet mode

Same as above, this example has quiet flag set.

```shell
$ ./find_orphan_rbd_images.sh -q -i csi-vol-b513c1de-6e88-4e0d-aa70-a114e8fd482f
# no output
```

* No output when quiet mode enabled and image can not be removed.

---

## Testing Stale/Orphaned RBD Image (has no PV)

An RBD image not referenced by a PV, has no watchers and has zero snapshots is a candidate for removal:

```shell
$ ./find_orphan_rbd_images.sh -i csi-vol-fcfe42b0-4218-442a-ba3e-0b793c31fd19
--[ RBD Image can be deleted! ]----------------------------------------
NAME                                          PROVISIONED  USED
csi-vol-fcfe42b0-4218-442a-ba3e-0b793c31fd19       20 GiB  1.8 GiB
size 20 GiB in 5120 objects
snapshot_count: 0
create_timestamp: Mon Apr 17 12:48:00 2023
access_timestamp: Mon Apr 17 12:48:00 2023
modify_timestamp: Mon Apr 17 12:48:00 2023
-----------------------------------------------------------------------

Matched 0 of 34 PVs. Possible 1 RBD Images can be deleted of the 1 total images (0 considered still had watchers)
```

### Example Stale/Orphaned RBD Image in quiet mode

```shell
$ ./find_orphan_rbd_images.sh -q -i csi-vol-fcfe42b0-4218-442a-ba3e-0b793c31fd19
--[ RBD Image can be deleted! ]----------------------------------------
NAME                                          PROVISIONED  USED
csi-vol-fcfe42b0-4218-442a-ba3e-0b793c31fd19       20 GiB  1.8 GiB
-----------------------------------------------------------------------
```

---
