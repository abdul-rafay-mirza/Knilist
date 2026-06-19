# Maintainer: Abdul Rafay <abdulrafayaneesmirza@gmail.com>
pkgname=knilist-git
pkgver=r1.0000000
pkgrel=1
pkgdesc="An AniList desktop client written in Kirigami QML + Python"
arch=('any')
url="https://github.com/abdul-rafay-mirza/Knilist"
license=('GPL-3.0-or-later')
depends=(
    'python'
    'python-requests'
    'python-keyring'
    'python-secretstorage'
    'pyside6'
    'kirigami'
    'kirigami-addons'
    'qt6-declarative'
    'kwallet'
)
makedepends=(
    'git'
    'python-build'
    'python-installer'
    'python-setuptools'
    'python-wheel'
)
provides=('knilist')
conflicts=('knilist')
source=("knilist::git+https://github.com/abdul-rafay-mirza/Knilist.git")
sha256sums=('SKIP')
install=knilist.install

pkgver() {
    cd "$srcdir/knilist"
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

build() {
    cd "$srcdir/knilist"
    python -m build --wheel --no-isolation
}

package() {
    cd "$srcdir/knilist"

    # Install the Python package
    python -m installer --destdir="$pkgdir" dist/*.whl

    # Install the .desktop file to the system-wide applications directory
    # so it appears in every user's app launcher automatically
    install -Dm644 com.github.abdul-rafay-mirza.knilist.desktop \
        "$pkgdir/usr/share/applications/com.github.abdul-rafay-mirza.knilist.desktop"
}
