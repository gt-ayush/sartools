# Maintainer: Sarchy <gt-ayush@outlook.com>
pkgname=sartools
pkgver=0.40.0
pkgrel=1
pkgdesc="Sarchy Linux ISO build tooling (re-branded from artools/artix)"
arch=('any')
url="https://github.com/gt-ayush/sartools"
license=('GPL-3.0')
depends=('awk' 'bash' 'coreutils' 'grep' 'pacman' 'util-linux' 'sed')
makedepends=('make' 'shellcheck')
optdepends=('dosfstools: ISO building'
            'e2fsprogs: ISO building'
            'grub: ISO building'
            'libarchive: ISO building'
            'libisoburn: ISO building'
            'mtools: ISO building'
            'squashfs-tools: ISO building'
            'go-yq: ISO building')
source=()
sha256sums=()

build() {
    cd "$startdir"
    make PREFIX=/usr SYSCONFDIR=/etc
}

package() {
    cd "$startdir"
    make DESTDIR="${pkgdir}" PREFIX=/usr SYSCONFDIR=/etc install
}
