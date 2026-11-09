# apko-uki-template

Simple bootable Alpine Linux UKI composed with my `apko` fork that supports lockfiles.

Has a sample workload (see image) and just enough scaffolding to actually work, but nothing else.

![QEMU window showing the Nyancat binary running](image.png)

## Usage
This project is mostly for my own testing so is built to assume a Fedora host with `podman` and `qemu` installed.

Other distributions will work with only minor tweaks needed to ensure the right paths are used in the `justfile` for the various `qemu`-related paths.

### Run all build steps
Runs all of the individual steps as documented below, but automatically and in order:
```sh
just go
```

### Run individual steps
Build config overlay package using the contents of `/config`:
```sh
just config
```

Populate lockfile (`apko.lock`):
```sh
just lock
```

Generate EFI vars store populated with Secure Boot keys and example custom vars:
```sh
just efivars
```

Build image with lockfile as an input:
```sh
just initramfs
```

Build `initramfs` into UKI and sign it:
```sh
just uki
```

Test in QEMU (UEFI boot using UKI):
```sh
just qemu
```
