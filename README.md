artools
=============

#### Make flags


* PREFIX=/usr
* SYSCONFDIR=/etc

#### Dependencies

##### Buildtime:

* make
* shellcheck

##### Runtime:

- base:
  * awk
  * bash
  * coreutils
  * grep
  * pacman
  * util-linux
  * sed

- pkg:
  * artools-base
  * binutils
  * diffutils
  * findutils
  * go-yq
  * openssh
  * parallel
  * rsync

- iso:
  * artools-base
  * dosfstools
  * e2fsprogs
  * findutils
  * grub
  * libarchive
  * libisoburn
  * mtools
  * squashfs-tools
  * go-yq


#### Configuration

artools-{pkg,iso}.conf are the configuration files for artools.
By default, the config files are installed in

```bash
/etc/artools/artools-{pkg,iso}.conf
```

A user artools-{pkg,iso}.conf can be placed in

```bash
$HOME/.config/artools/artools-{pkg,iso}.conf
```

If the userconfig is present, artools will load the userconfig values, however, if variables have been set in the systemwide

These values take precedence over the userconfig.
Best practise is to leave systemwide file untouched.
By default it is commented and shows just initialization values done in code.

Tools configuration is done in artools-{pkg,iso}.conf or by args.
Specifying args will override artools-{pkg,iso}.conf settings.

Both, pacman.conf and makepkg.conf for chroots are loaded from

```bash
usr/share/artools/makepkg.conf.d/${arch}.conf
```

```bash
usr/share/artools/pacmanconf.d/${repo}-${arch}.conf
```

and can be overridden dropping them in

```bash
$HOME/.config/artools/makepkg.conf.d/
```

```bash
$HOME/.config/artools/pacman.conf.d/
```

artools-*.conf:

```bash
$HOME/.config/artools/
```
# sartools
