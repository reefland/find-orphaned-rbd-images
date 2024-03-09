
# Find Orphaned Ceph RBD Images

Script tries to locate stale/orphaned Ceph RBD images which are no longer referenced by existing Kubernetes PV (Persistent Volume). The respective PV has already been deleted.  This can happen when Rook-Ceph `reclaimPolicy: Retain` is set and someone has manually delete the PV that was in `Released` status. Unfortunately removal of the PV does not remove the Ceph RBD image.  The Ceph RBD image will remain consuming storage space until it is removed. See <https://github.com/rook/rook/issues/4651>

* The script will NOT remove any images for you. It will only help you identify images which can be removed.

* *Script requires the [krew](https://krew.sigs.k8s.io/) rook-ceph plugin for `kubectl` installed*

Running the script without any flags will show the usage statement.

---

## Script Flags

```text
-a, --all         : Check all RBD Images (in pool of the storage class type)
-i, --image       : Check single RBD Image name
-l, --list-pools  : List all pools with "block" in the name
-n, --namespace   : Kubernetes namespace where rook-ceph is installed
-p, --pool        : Name of Ceph RBD Block Pool to check
-q, --quiet       : Reduced output
-h, --help        : This usage statement
-v, --version     : Script version
```

Defaults values for Ceph Pool and Namespace are shown within the usage statement / help screen:

```text
find_orphan_rbd_images.sh [--quiet] -a [--pool ceph-blockpool] [--namespace rook-ceph]

find_orphan_rbd_images.sh [-q ] -i csi-vol-<image_name> [-p ceph-blockpool] [-n rook-ceph]
```

* If you need to use different values set flags appropriate for your environment.

---

## List all RBD Images without PV

This is the normal way to run the script, scan all RBD images.

```shell
$ ./find_orphan_rbd_images.sh -a

PVs found: 34
RBD Images: 110
RBD Pool: ceph-blockpool

RBD Image: csi-vol-00b2e9e7-65e7-11ed-a2b8-ea677ad8a25d has PV, skipping.
--[ RBD Image has no Persistent Volume (PV) ]----------------------------
NAME                                          PROVISIONED  USED
csi-vol-00b3557e-624c-4892-8ed9-2d1ffc9683db       10 GiB  72 MiB
size 10 GiB in 2560 objects
snapshot_count: 0
create_timestamp: Wed Aug 23 12:21:36 2023
access_timestamp: Wed Aug 23 12:21:36 2023
modify_timestamp: Wed Aug 23 12:21:36 2023
-------------------------------------------------------------------------
--[ RBD Image has no Persistent Volume (PV) ]----------------------------
NAME                                          PROVISIONED  USED
csi-vol-00b88510-767e-4c1e-93f4-bed07e559d6a        1 GiB  64 MiB
size 1 GiB in 256 objects
snapshot_count: 0
create_timestamp: Mon Feb 26 14:53:35 2024
access_timestamp: Mon Feb 26 14:53:35 2024
modify_timestamp: Mon Feb 26 14:53:35 2024
-------------------------------------------------------------------------

... ( lines removed for brevity )

--[ RBD Image has no Persistent Volume (PV) ]----------------------------
NAME                                          PROVISIONED  USED
csi-vol-cbaa0262-461e-4fe8-a8bb-07f655bb423f       50 GiB  872 MiB
size 50 GiB in 12800 objects
snapshot_count: 3
create_timestamp: Tue Feb 27 15:42:34 2024
access_timestamp: Tue Feb 27 15:42:34 2024
modify_timestamp: Tue Feb 27 15:42:34 2024
-------------------------------------------------------------------------
RBD Image: csi-vol-cc9349ec-c871-43d1-9bb8-0e63898e0d8c has PV, skipping.
RBD Image: csi-vol-cfb44755-66a9-11ed-a2b8-ea677ad8a25d has PV, skipping.
RBD Image: csi-vol-d01a63f6-684d-11ed-a2b8-ea677ad8a25d has PV, skipping.
RBD Image: csi-vol-d78d76ea-ee48-4f5d-b1c0-c34ce4e6c07f has PV, skipping.
RBD Image: csi-vol-d7ac3bba-abef-11ed-9116-960dd16b9a1c has PV, skipping.
RBD Image: csi-vol-ede26e4a-8a25-11ed-9b4d-0ecde2b23cd0 has PV, skipping.
--[ RBD Image has no Persistent Volume (PV) ]----------------------------
NAME                                          PROVISIONED  USED
csi-vol-f8fb1f75-ab0c-4b80-b43c-1455215d2732       50 GiB  948 MiB
size 50 GiB in 12800 objects
snapshot_count: 4
create_timestamp: Mon Feb 26 15:56:01 2024
access_timestamp: Mon Feb 26 15:56:01 2024
modify_timestamp: Mon Feb 26 15:56:01 2024
-------------------------------------------------------------------------

Matched 34 of 34 PVs. Possible 76 RBD Images can be deleted of the 110 total images (0 considered still had watchers)
```

### List all RBD Images in quiet mode

Same as above with (`-q`) `quiet mode` flag set. Quiet mode runs faster as details of each image is not queried. However, it is not known if the RBD image has snapshots in quiet mode.

```shell
$ ./find_orphan_rbd_images.sh -q -a

--[ RBD Image has no Persistent Volume (PV) ]----------------------------
NAME                                          PROVISIONED  USED
csi-vol-00b3557e-624c-4892-8ed9-2d1ffc9683db       10 GiB  72 MiB
-------------------------------------------------------------------------
--[ RBD Image has no Persistent Volume (PV) ]----------------------------
NAME                                          PROVISIONED  USED
csi-vol-00b88510-767e-4c1e-93f4-bed07e559d6a        1 GiB  64 MiB
-------------------------------------------------------------------------
--[ RBD Image has no Persistent Volume (PV) ]----------------------------
NAME                                          PROVISIONED  USED
csi-vol-01668759-1751-4138-bb75-8bcbb7f9f35a        1 GiB  96 MiB
-------------------------------------------------------------------------

...

--[ RBD Image has no Persistent Volume (PV) ]----------------------------
NAME                                          PROVISIONED  USED
csi-vol-8429e6bb-d15e-4c16-be27-dceec440d53d       20 GiB  292 MiB
-------------------------------------------------------------------------
--[ RBD Image has no Persistent Volume (PV) ]----------------------------
NAME                                          PROVISIONED  USED
csi-vol-cbaa0262-461e-4fe8-a8bb-07f655bb423f       50 GiB  872 MiB
-------------------------------------------------------------------------
--[ RBD Image has no Persistent Volume (PV) ]----------------------------
NAME                                          PROVISIONED  USED
csi-vol-f8fb1f75-ab0c-4b80-b43c-1455215d2732       50 GiB  948 MiB
-------------------------------------------------------------------------
```

---

## Remove orphaned image

An RBD image not referenced by a PV, has no watchers and has zero snapshots is a candidate for removal.

Once you have identified images which can be removed, you can use the Rook-Ceph Toolbox Pod to remove images. This script will *NOT* remove any images for you. It will only help you identify images which can be removed.

From Rook-Ceph Toolbox pod:

```shell
$ rbd -p ceph-blockpool rm csi-vol-fcfe42b0-4218-442a-ba3e-0b793c31fd19
Removing image: 100% complete...done.
```

### Attempting to remove orphaned image with snapshots

RBD image with snapshots can not be removed:

```text
--[ RBD Image has no Persistent Volume (PV) ]----------------------------
NAME                                          PROVISIONED  USED
csi-vol-f8fb1f75-ab0c-4b80-b43c-1455215d2732       50 GiB  948 MiB
size 50 GiB in 12800 objects
snapshot_count: 6
create_timestamp: Mon Feb 26 15:56:01 2024
access_timestamp: Mon Feb 26 15:56:01 2024
modify_timestamp: Mon Feb 26 15:56:01 2024
-------------------------------------------------------------------------
```

* If you try, an error message will be issued:

From Rook-Ceph Toolbox pod:

```shell
$ rbd -p ceph-blockpool rm csi-vol-f8fb1f75-ab0c-4b80-b43c-1455215d2732

2024-03-02T04:13:09.419+0000 7f9034c0f580 -1 librbd::api::Image: remove: image has snapshots - not removing
Removing image: 0% complete...failed.
rbd: image has snapshots with linked clones - these must be deleted or flattened before the image can be removed.
```

NOTE: RBD Images removed can be snapshots of other images.  As you removed RBD images you may notice the snapshot count of other images lower. They may reach zero allowing them to be removed.  Keep running the script and removing RBD images that have zero snapshot count.

---

## Testing RBD Image with associated PV

If an RBD image is associated to a PV it is NOT a candidate for image removal. Below shows how to use `kubectl` to get the RBD Image Name associated with a PV.

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

* No output when quiet mode enabled and image cannot be removed.

---

## Testing Stale/Orphaned RBD Image (has no PV)

An RBD image not referenced by a PV, has no watchers and has zero snapshots is a candidate for removal:

```shell
$ ./find_orphan_rbd_images.sh -i csi-vol-fcfe42b0-4218-442a-ba3e-0b793c31fd19

--[ RBD Image has no Persistent Volume (PV) ]----------------------------
NAME                                          PROVISIONED  USED
csi-vol-fcfe42b0-4218-442a-ba3e-0b793c31fd19       20 GiB  1.8 GiB
size 20 GiB in 5120 objects
snapshot_count: 0
create_timestamp: Mon Apr 17 12:48:00 2023
access_timestamp: Mon Apr 17 12:48:00 2023
modify_timestamp: Mon Apr 17 12:48:00 2023
-------------------------------------------------------------------------

Matched 0 of 34 PVs. Possible 1 RBD Images can be deleted of the 1 total images (0 considered still had watchers)
```

### Example Stale/Orphaned RBD Image in quiet mode

```shell
$ ./find_orphan_rbd_images.sh -q -i csi-vol-fcfe42b0-4218-442a-ba3e-0b793c31fd19
--[ RBD Image has no Persistent Volume (PV) ]----------------------------
NAME                                          PROVISIONED  USED
csi-vol-fcfe42b0-4218-442a-ba3e-0b793c31fd19       20 GiB  1.8 GiB
-------------------------------------------------------------------------
```
