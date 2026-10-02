# [RAMDisk for macOS]

### A minimal ZSH function to create and destroy APFS-formatted RAM disks on macOS.

## Features
💾 Create APFS RAM disks up to system's total installed RAM 

✅ Safe teardown - unmounts & detaches cleanly

👮🏼‍♂️ Input validation - enforces valid size and context, supports macOS 27 Golden Gate, no longer uses `hdiutil` 

⚡ Fast - great for builds, testing, and temp data


## Usage
Copy the `ramdisk` functions from `/src`, paste into `.zshrc` or equivalent

```
ramdisk create <size_in_GiB>
ramdisk destroy
```

## Example
```
ramdisk create 8
→ Creates /Volumes/RAMDisk backed by 8 GiB of RAM

ramdisk destroy
→ Unmounts and detaches the RAM disk cleanly, reclaiming all RAM used
```

Mount path is always: `/Volumes/RAMDisk`

Format is always: `APFS`

Utilises: `diskutil` only, supports macOS 27 Golden Gate (on which `hdiutil` is deprecated)
