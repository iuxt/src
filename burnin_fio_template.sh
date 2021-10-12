#!/bin/bash
set -euo pipefail

FIO_BURNIN_CONFIG=./fio-burnin.conf
FIO_CLEAN_FILESYSTEM_CONFIG=./fio-clean_filesystem.conf

cat <<EOF
1. fio burning disk

sudo yum install fio
nohup fio ./fio-burnin.conf &

2. clean filesystem
> After running fio, it will write to the filesystem, so you need to clear the filesystem and execute:

fio ./fio-clean_filesystem.conf

EOF

cat > "$FIO_BURNIN_CONFIG" <<EOF
[global]
ioengine=libaio
group_reporting
blocksize=1M
iodepth=32
direct=1
verify=md5
do_verify=1
rw=write

EOF

cat > "$FIO_CLEAN_FILESYSTEM_CONFIG" <<EOF
[global]
ioengine=libaio
group_reporting
blocksize=1M
iodepth=32
direct=1
size=1M
rw=write
buffer_pattern=0

EOF

for block in $(ls /sys/block); do
  # Skip blocks not starting with 'sd'
  if [[ ! $block =~ ^sd ]]; then
    continue
  fi
  # Skip blocks with unkown model
  if [[ ! -f /sys/block/$block/device/model ]]; then
    continue
  fi
  # Skip INTEL SSD
  if [[ $(cat /sys/block/$block/device/model) =~ .*INTEL.* ]]; then
    continue
  fi
  # Skip blocks having any file systems on it
  subblock=""
  for subblock in $(ls -d /sys/block/$block/$block* 2> /dev/null); do
    if [[ -f /dev/$subblock ]] && ! sudo blkid /dev/$subblock | grep -q $subblock; then
      echo "[$subblock]" >> "$FIO_BURNIN_CONFIG"
      echo "filename=/dev/$subblock" >> "$FIO_BURNIN_CONFIG"
      echo "[$subblock]" >> ""$FIO_CLEAN_FILESYSTEM_CONFIG""
      echo "filename=/dev/$subblock" >> ""$FIO_CLEAN_FILESYSTEM_CONFIG""
    fi
  done
  if [[ -z $subblock ]] && ! sudo blkid /dev/$block | grep -q $block; then
    echo "[$block]" >> "$FIO_BURNIN_CONFIG"
    echo "filename=/dev/$block" >> "$FIO_BURNIN_CONFIG"
    echo "[$block]" >> "$FIO_CLEAN_FILESYSTEM_CONFIG"
    echo "filename=/dev/$block" >> "$FIO_CLEAN_FILESYSTEM_CONFIG"
  fi
done
