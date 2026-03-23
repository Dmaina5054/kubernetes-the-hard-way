# 🛠️ Lab Resurrection: Chronological Post-Mortem

**Context:** Migrating Libvirt/Vagrant storage from a cramped `/var` (21GB) to a spacious LVM-backed `/home` on Debian 13.

---

## 🕒 Phase 1: The Migration & The "Busy" Lock

- **Goal:** Move VM images to `/home/libvirt-images` and symlink them back to `/var/lib/libvirt/images`.
- **Blocker:**  
    `rmdir /var/lib/libvirt/images` failed with `Device or resource busy`.
- **Discovery:**  
    `sudo fuser -v` revealed the directory was a Kernel Bind Mount point, not just a folder.
- **Aha! Moment:**  
    You cannot delete or symlink a path the kernel is actively using as a mount target.
- **Fix:**  
    Used `sudo umount -l` (lazy unmount) to force the kernel to detach the path without a reboot.

---

## 🕒 Phase 2: The fstab Conflict & The "Lying" Error

- **Goal:** Make the new storage persistent across reboots using `/etc/fstab`.
- **Blocker:**  
    `sudo mount -a` threw a cryptic `wrong fs type, bad option, bad superblock` error.
- **Discovery:**  
    The error was a "red herring." There were duplicate mount entries and a naming mismatch in `fstab` (referencing `libvirt-storage` vs the actual `libvirt-images`).
- **Aha! Moment:**  
    On Debian 13, `mount -a` fails if the source directory is missing or if multiple lines claim the same target.
- **Fix:**  
    Cleaned `fstab` to a single "Source of Truth" and ran `systemctl daemon-reload` to refresh systemd’s mount units.

---

## 🕒 Phase 3: The Path Mismatch (The Symlink Break)

- **Goal:** Point Libvirt to the new data.
- **Blocker:**  
    Vagrant reported `No such file or directory` even though the files were clearly on the disk.
- **Discovery:**  
    The symlink was pointing to `/home/libvirt-storage`, but the physical folder was named `/home/libvirt-images`.
- **Aha! Moment:**  
    Linux is literal. A "broken" symlink (pointing to a non-existent name) returns a "No such file" error that makes you think the target file is missing, when the path is just wrong.
- **Fix:**  
    Recreated the symlink with the exact matching directory name.

---

## 🕒 Phase 4: The Final Boss (Permissions & AppArmor)

- **Goal:** Start the VMs now that the paths are correct.
- **Blocker:**  
    `vagrant up` failed with `Permission denied (uid:64055)`.
- **Discovery:**  
    Even with `777` permissions, the `libvirt-qemu` user was blocked by AppArmor and standard ACLs.
- **Aha! Moment:**  
    1. AppArmor is a "path-based" guard; it didn't recognize `/home` as a valid place for VMs.  
    2. ACLs (`setfacl`) are needed to let the system user (`libvirt-qemu`) and the human user (`dm`) share the same files.
- **Final Fix:**  
    1. Added a local override to `/etc/apparmor.d/local/abstractions/libvirt-qemu`.  
    2. Ran `sudo setfacl -R -m u:libvirt-qemu:rwX /home/libvirt-images`.
