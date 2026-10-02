ramdisk() {
  setopt localoptions nobashrematch
  # Keep things local
  local MATCH MBEGIN MEND
  local size bytes limit plist device backing mountpoint="/Volumes/RAMDisk"
  local -x LC_ALL=C
  case "${1-}:$#" in
    create:2)
      # Validate RAM bounds
      if ! bytes=$(command sysctl -n hw.memsize) ||
         ! [[ $bytes =~ ^[1-9][0-9]{0,18}$ ]] ||
         { (( ${#bytes} == 19 )) && [[ $bytes > 9223372036854775807 ]]; } ||
         (( bytes < 1073741824 )); then
        echo "FATAL: cannot determine installed RAM" >&2
        return 1
      fi
      # Limit in GiB
      limit=$((bytes / 1073741824))
      # Strip zeros
      size=${2#"${2%%[!0]*}"}
      # Validate requested size
      if ! [[ $size =~ ^[1-9][0-9]*$ ]] ||
         (( ${#size} > ${#limit} || size > limit )) ||
         # Bail if something exists at mount
         [[ -e $mountpoint || -L $mountpoint ]]; then
        echo "ERROR: use 1-${limit} GiB and ensure $mountpoint does not already exist" >&2
        return 1
      fi
      # Create RAM block device and store metadata
      plist=$(command diskutil image --plist attach --noMount "ram://$((size * 2097152))") || return 1
      [[ $(ramdisk_plist "$plist" system-entities array) == 1 ]] &&
        device=$(ramdisk_plist "$plist" system-entities.0.dev-entry) &&
        [[ $device =~ ^disk[0-9]+$ ]] || {
          # Show the untrusted response for diagnosis
          printf 'FATAL: invalid attach output; device may remain attached:\n%s\n' "$plist" >&2
          return 1
        }
      if [[ $(ramdisk_plist "$plist" system-entities.0.size integer) == "$((size * 1073741824))" ]] &&
         # Create APFS container, mount RAMDisk volume and error check
         command diskutil apfs create "/dev/$device" RAMDisk >/dev/null &&
         [[ ! -L $mountpoint ]] &&
         plist=$(command diskutil info -plist "$mountpoint") &&
         [[ $(ramdisk_plist "$plist" MountPoint) == "$mountpoint" ]] &&
         [[ $(ramdisk_plist "$plist" APFSPhysicalStores array) == 1 ]] &&
         [[ $(ramdisk_plist "$plist" APFSPhysicalStores.0.APFSPhysicalStore) == "$device" ]]; then
        echo "SUCCESS: ${size}GiB RAMDisk created at $mountpoint"
        # Return success and restore locals; leave the RAM disk attached and mounted
        return 0
      fi
      # Else clean up
      echo "FATAL: creation or verification failed; cleaning up /dev/$device" >&2
      command diskutil eject force "/dev/$device" >/dev/null || echo "ERROR: cleanup failed for /dev/$device" >&2
      return 1
      ;;
    destroy:1)
      # If RAMDisk !exist, do nothing
      if [[ ! -e $mountpoint && ! -L $mountpoint ]]; then
        echo "INFO: no RAMDisk at $mountpoint"
        return 0
      fi
      # Find backing, check and nuke
      [[ ! -L $mountpoint ]] &&
        plist=$(command diskutil info -plist "$mountpoint") &&
        [[ $(ramdisk_plist "$plist" MountPoint) == "$mountpoint" ]] &&
        [[ $(ramdisk_plist "$plist" BusProtocol) == 'Disk Image' ]] &&
        [[ $(ramdisk_plist "$plist" APFSPhysicalStores array) == 1 ]] &&
        backing=$(ramdisk_plist "$plist" APFSPhysicalStores.0.APFSPhysicalStore) &&
        [[ $backing =~ ^disk[0-9]+$ ]] &&
        command diskutil eject "/dev/$backing" >/dev/null || {
          echo "ERROR: RAMDisk destruction failed" >&2
          return 1
        }
      echo "SUCCESS: RAMDisk at $mountpoint destroyed"
      return 0
      ;;
    # Handle every unsupported command or argument count
    *)
      # Print the supported invocation forms to standard error
      echo "INFO: ramdisk create <GiB> | destroy" >&2
      return 1
      ;;
  esac
}
ramdisk_plist() {
  # Reads plists, arguments are plist text, key path, and optional expected type
  local value
  # <<< supplies argument 1 plus a newline, suppress plutil stderr, return failure before emitting data
  value=$(command plutil -extract "$2" raw -expect "${3:-string}" -n - <<< "$1" 2>/dev/null && printf '.') || return 1
  # Remove the appended dot from the local value, preserving any original trailing dots/newlines
  value=${value%.}
  # Reject control characters, including preserved newlines/tabs, return failure without output
  [[ $value != *[[:cntrl:]]* ]] || return 1
  # Print the value without a newline for the caller to capture, array extraction returns its count
  printf '%s' "$value"
}
