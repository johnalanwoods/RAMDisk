# [RAMDisk for macOS]

### A minimal ZSH function to create and destroy APFS-formatted RAM disks on macOS.

## Features
💾 Create APFS RAM disks up to 128 GiB

✅ Safe teardown - unmounts & detaches cleanly

👮🏼‍♂️ Input validation - enforces valid size and context 

⚡ Fast - great for builds, testing, and temp data


## Usage
Copy the `ramdisk` function from `/src`, paste into `.zshrc` or equivalent

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

Created with: `hdiutil` and `diskutil`
