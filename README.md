sartools
========

Arch Linux ISO build tooling, re-branded from **artix / artools** to **sarchy / sartools**.

`sartools` is the package that provides the build-time tools used to build the
Sarchy Linux ISO: `buildiso`, `sarchy-chroot`, `basestrap`, `buildpkg`, and the
supporting libraries/config files that live under `/etc/sartools` and
`/usr/share/sartools`.

This document covers:

1. [Re-branding summary](#re-branding-summary)
2. [What changed](#what-changed)
3. [What did NOT change](#what-did-not-change)
4. [Installation](#installation)
5. [Configuration paths](#configuration-paths)
6. [Binaries provided](#binaries-provided)
7. [Usage examples](#usage-examples)
8. [Sarchy-iso integration](#sarchy-iso-integration)
9. [Verification](#verification)

## Re-branding summary

| From (artools / artix) | To (sartools / sarchy) |
|------------------------|------------------------|
| Binary `artix-chroot`  | `sarchy-chroot`        |
| Binary `basestrap`     | `basestrap` (unchanged — generic, not Artix-specific) |
| Binary `buildiso`      | `buildiso` (unchanged) |
| Dir `/var/lib/artools/buildiso/` | `/var/lib/sartools/buildiso/` |
| Dir `/etc/artools/`    | `/etc/sartools/` |
| Dir `/usr/share/artools/` | `/usr/share/sartools/` |
| User config dir `~/.config/artools/` | `~/.config/sartools/` |
| User workspace `artools-workspace` | `sartools-workspace` |
| String "Artix Linux"   | "Sarchy Linux" |
| String "artix" (lowercase, path/branding) | "sarchy" |
| `make_grub()` theme `/usr/share/grub/themes/artix` | `/usr/share/grub/themes/sarchy` |
| EFI volume label `ARTIX_EFI` | `SARCHY_EFI` |
| ISO volume label `ARTIX_YYYYMM` | `SARCHY_YYYYMM` |
| ISO root marker `.artix` | `.sarchy` |
| ISO filename prefix `"artix"` | `"sarchy"` |

## What changed

### `Makefile`
- `TOOLS = artools` → `TOOLS = sartools`
  - This drives `DATADIR`, `LIBDIR`, `SYSCONFDIR`, so install destinations become
    `/usr/local/share/sartools`, `/usr/local/share/sartools/lib`, `/etc/sartools`.
- Internal staging directories renamed `$(BUILDDIR)/artools` → `$(BUILDDIR)/$(TOOLS)`.

### Binary rename
- `src/base/artix-chroot.in` → `src/base/sarchy-chroot.in`
  - Function `artix-chroot()` → `sarchy-chroot()`
  - Internal recursive calls and usage text updated.

### ISO build tooling
- `src/iso/buildiso.in`
  - `SYSCONFDIR` default `@sysconfdir@/artools` → `@sysconfdir@/sartools`
  - ISO filename prefix `"artix"` → `"sarchy"`
  - Volume label `ARTIX_$(date +%Y%m)` → `SARCHY_$(date +%Y%m)`
  - ISO root marker `.artix` → `.sarchy`
  - `work_dir` kept as `.../profile/artix` to match `build.sh`'s `chroot_dir`
    (`/var/lib/sartools/buildiso/sarchy/artix/rootfs`).
- `src/lib/iso/grub.sh`
  - Theme path `themes/artix` → `themes/sarchy`
  - EFI label `ARTIX_EFI` → `SARCHY_EFI`
- `src/lib/iso/initcpio.sh` / `dracut.sh`
  - `artix-chroot` call → `sarchy-chroot`
- `src/lib/iso/config.sh`
  - `$fs/etc/artools` → `$fs/etc/sartools` (live.conf written inside ISO rootfs)

### Library config paths
- `src/lib/iso/util.sh` and `src/lib/pkg/util.sh`
  - `USER_CONF_DIR` `.config/artools` → `.config/sartools`
  - `CHROOTS_DIR` default `/var/lib/artools` → `/var/lib/sartools`
  - `WORKSPACE_DIR` default `artools-workspace` → `sartools-workspace`

### Config defaults
- `config/conf/artools-iso.conf` / `artools-pkg.conf`
  - Commented defaults updated to `/var/lib/sartools` / `sartools-workspace`.

## What did NOT change

Per scope, the following were intentionally left alone:

- Build logic, dependency handling, squashfs/xorriso steps.
- Package names of Artix repos: `system`, `world`, `galaxy`, `multilib` stay as-is.
- `buildiso` binary name kept.
- `basestrap` kept (it is a generic `pacman -r` installer, not Artix-specific).
- `pacman-key --populate artix` inside `build.sh`'s rootfs — still needed to populate
  the Artix keyring inside the chroot.
- The `artixpkg` tooling and its `ARTIX_TEAMS`/gitea infrastructure (package
  repository management, not ISO building).
- Root-overlay contents and `config/artools/pacman-default.conf` (owned by Sarchy-iso).

## Installation

Build from source and install:

```bash
git clone https://github.com/gt-ayush/sartools.git
cd sartools
make
sudo make install
```

Install targets:

- `make install_base` — `sarchy-chroot`, `basestrap`, `fstabgen`, base libraries
- `make install_pkg` — `buildpkg`, `artixpkg`, and the rest of the pkg tooling
- `make install_iso` — `buildiso` and ISO libraries
- `make install` — everything (`all` + all install targets)

Uninstall:

```bash
sudo make uninstall
```

Make flags:

| Flag | Default | Meaning |
|------|---------|---------|
| `PREFIX` | `/usr/local` | Install prefix |
| `SYSCONFDIR` | `/etc` | System configuration directory |
| `DESTDIR` | (empty) | Staging dir for packaging |

## Configuration paths

System-wide config is installed to `/etc/sartools/artools-{pkg,iso}.conf`.
User config overrides go in `~/.config/sartools/artools-{pkg,iso}.conf`.

Default locations:

| Setting | Default |
|---------|---------|
| Config dir | `/etc/sartools/` |
| User config dir | `~/.config/sartools/` |
| Data dir | `/usr/share/sartools/` |
| Chroots dir | `/var/lib/sartools` |
| Workspace dir | `~/sartools-workspace` |
| Pacman conf snippets | `/usr/share/sartools/pacman.conf.d/` |
| Makepkg conf snippets | `/usr/share/sartools/makepkg.conf.d/` |

Example `buildiso` invocation:

```bash
buildiso -p sarchy -x          # build chroot only
buildiso -p sarchy -sc         # squash chroot only
buildiso -p sarchy -bc         # boot only
buildiso -p sarchy -zc         # generate ISO only
```

## Binaries provided

| Binary | Source | Purpose |
|--------|--------|---------|
| `sarchy-chroot` | `src/base/sarchy-chroot.in` | Enter an ISO build chroot (replaces `artix-chroot`) |
| `basestrap` | `src/base/basestrap.in` | Install packages into a new root with pacman |
| `fstabgen` | `src/base/fstabgen.in` | Generate fstab for a target root |
| `buildiso` | `src/iso/buildiso.in` | Build a Sarchy Linux ISO image |
| `buildpkg` | `src/pkg/buildpkg.in` | Build packages in a clean chroot |
| `artixpkg` | `src/pkg/artixpkg.in` | Artix repository management tooling |

## Usage examples

Enter a build chroot:

```bash
sudo sarchy-chroot /var/lib/sartools/buildiso/sarchy/artix/rootfs /bin/bash
```

Build the Sarchy ISO (chroot phase):

```bash
buildiso -i openrc -p sarchy -x
```

Build the full ISO:

```bash
buildiso -i openrc -p sarchy -zc
```

## Sarchy-iso integration

`sartools` is installed inside the Sarchy-ISO Docker container at build time
instead of `artools` from the Artix repos. See the `Sarchy-iso` repository for
the full pipeline.

### Dockerfile changes

- `pacman -S artools iso-profiles ...` → install sartools from source:
  ```dockerfile
  RUN pacman -S --noconfirm --needed archlinux-keyring archlinux-mirrorlist git base-devel && \
      git clone https://github.com/gt-ayush/sartools.git /tmp/sartools && \
      cd /tmp/sartools && make install
  ```
- `pacman-key --populate artix` → `pacman-key --populate sarchy`
- `WORKDIR /artix-iso` → `/sarchy-iso`
- Workspace symlink: `sarchyiso/artools-workspace` → `sarchyiso/sartools-workspace`
- `CMD cd /root/sartools-workspace/iso-profiles ; ./build.sh`

### docker-build.sh changes

- Bind target `/root/artools-workspace/iso` → `/root/sartools-workspace/iso`
- tmpfs `/var/lib/artools` → `/var/lib/sartools`

### build.sh changes (inside `sarchyiso/sartools-workspace/iso-profiles/build.sh`)

- `chroot_dir="/var/lib/artools/buildiso/sarchy/artix/rootfs"` →
  `chroot_dir="/var/lib/sartools/buildiso/sarchy/artix/rootfs"`
- All `artix-chroot` calls → `sarchy-chroot` (9 occurrences)

## Verification

After installation, confirm the re-branded tooling works:

```bash
# 1. sarchy-chroot exists and is functional
which sarchy-chroot
sarchy-chroot --help   # or just confirm the binary runs

# 2. buildiso uses sartools paths, no "artix" path errors
buildiso -p sarchy -x
# Expected: completes chroot build under /var/lib/sartools/buildiso/sarchy/artix/
# with no references to /var/lib/artools, /etc/artools, or /usr/share/artools

# 3. Confirm install destinations
ls /usr/local/bin/sarchy-chroot
ls /usr/local/share/sartools/lib/iso/grub.sh
ls /etc/sartools/

# 4. Confirm grub theme path points to sarchy
grep themes/sarchy /usr/local/share/sartools/lib/iso/grub.sh
```

### Expected result

`buildiso -p sarchy -x` runs without "artix" path errors, `sarchy-chroot` works
in place of `artix-chroot`, and all ISO-build data lives under
`/var/lib/sartools`, `/etc/sartools`, and `/usr/share/sartools`.
