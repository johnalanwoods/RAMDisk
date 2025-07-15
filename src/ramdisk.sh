# ramdisk: create or destroy a macOS APFS RAM disk
ramdisk() {
  local cmd size blocks device backing mp="/Volumes/RAMDisk"

  cmd=$1

  # Create
  if [[ $cmd == create ]]; then
    # require exactly two args
    if (( $# != 2 )); then
      echo "Usage: ramdisk create <size_in_GiB>" >&2
      return 1
    fi

    # numeric check (digits only)
    if ! [[ $2 =~ ^[0-9]+$ ]]; then
      echo "Error: size must be an integer (no letters or symbols)" >&2
      return 1
    fi

    # strip leading zeros and convert to number
    size=$((10#$2))

    # enforce range 1–128 GiB
    if (( size < 1 || size > 128 )); then
      echo "Error: size must be between 1 and 128 GiB" >&2
      return 1
    fi

    # prevent duplicate mount
    if [[ -d $mp ]]; then
      echo "Error: RAMDisk already exists at $mp" >&2
      return 1
    fi

    # calculate block count (GiB × 2^21 blocks of 512 bytes)
    blocks=$(( size * 2097152 ))

    echo "→ Attaching ram://$blocks (512-byte blocks → ${size}GiB)…"
    device=$(hdiutil attach -nomount ram://$blocks 2>/dev/null \
      | awk '/^\/dev/{print $1; exit}') || {
      echo "Error: hdiutil attach failed" >&2
      return 1
    }
    echo "  → assigned device: $device"

    echo "→ Creating APFS container & volume 'RAMDisk' on $device…"
    diskutil apfs create "$device" RAMDisk >/dev/null || {
      echo "Error: formatting failed" >&2
      hdiutil detach "$device" -force >/dev/null
      return 1
    }
    echo "  → volume 'RAMDisk' mounted at $mp"

    echo "✔ RAMDisk (${size}GiB) ready at $mp (device: $device)"
    return 0
  fi

  # Status
  if [[ $cmd == status ]]; then
    # no extra args
    if (( $# != 1 )); then
      echo "Usage: ramdisk status" >&2
      return 1
    fi

    # check if mounted
    if [[ ! -d $mp ]]; then
      echo "Error: no RAMDisk found at $mp. use \`ramdisk create\` for new volume." >&2
      return 1
    fi

    echo "→ RAMDisk mounted at $mp"
    diskutil info -plist /Volumes/RAMDisk | tee \
      >(plutil -extract TotalSize raw - | nfmt |
        awk '{print "  → size: " $1}') \
      >(plutil -extract CapacityInUse raw - | nfmt |
        awk '{print "  → in use: " $1}') \
      >(plutil -extract APFSContainerFree raw - | nfmt |
        awk '{print "  → free: " $1}') \
      >(plutil -extract DeviceNode raw - |
        awk '{print "  → device: " $1}') > /dev/null
    return 0
  fi

  # Destroy
  if [[ $cmd == destroy ]]; then
    # no extra args
    if (( $# != 1 )); then
      echo "Usage: ramdisk destroy" >&2
      return 1
    fi

    # must be mounted
    if [[ ! -d $mp ]]; then
      echo "Error: no RAMDisk found at $mp" >&2
      return 1
    fi

    echo "→ Locating device for $mp…"
    device=$(df "$mp" 2>/dev/null | awk 'NR==2{print $1}') || {
      echo "Error: cannot determine device for $mp" >&2
      return 1
    }
    echo "  → device is $device"

    echo "→ Unmounting $mp"
    diskutil unmount "$mp" >/dev/null || { echo "Error: unmount failed" >&2; return 1; }

    # find the RAM-backing device (Physical Store of the APFS container)
    echo "→ Finding backing store for ${device%s*}…"
    backing=$(diskutil info "${device%s*}" \
      | awk '/Physical Store/{print $NF; exit}') || {
      echo "Error: cannot determine backing device" >&2
      return 1
    }
    echo "  → backing device is /dev/$backing"

    echo "→ Detaching /dev/$backing"
    hdiutil detach "/dev/$backing" >/dev/null || { echo "Error: eject failed" >&2; return 1; }

    echo "✔ RAMDisk at $mp destroyed"
    return 0
  fi

  echo "Usage: ramdisk create <size_in_GiB> | status | destroy" >&2
  return 1
}

nfmt () {
  awk '
      function human(x) {
          if (x<1000) {return x} else {x/=1024}
          s="kMGTEPZY";
          while (x>=1000 && length(s)>1)
              {x/=1024; s=substr(s,2)}
          return int(x+0.5) substr(s,1,1) "iB"
      }
      {sub(/^[0-9]+/, human($1)); print}'
}
