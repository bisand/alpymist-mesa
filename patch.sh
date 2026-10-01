#!/bin/sh
# Turns Alpine's mesa APKBUILD into the guest build: the virgl gallium driver
# added, and a pkgrel a hundred above Alpine's so that apk prefers this build
# of a version to Alpine's own, whichever of Alpine's rebuilds it is.
#
#   patch.sh APKBUILD          edit it in place, print <pkgver>-r<pkgrel>
#
# Exits 3 when Alpine's file already builds virgl: there is nothing left for
# this repository to do, and it should be retired rather than keep shipping a
# second Mesa. Exits 1 when the file is not shaped as expected, so a change
# upstream stops the build instead of producing an unpatched Mesa under this
# repository's name.
set -eu

file=${1:?usage: patch.sh APKBUILD}
BUMP=100

if grep -q '^[[:space:]]*_gallium_drivers=.*virgl' "$file"; then
	echo "Alpine's mesa already builds virgl: retire this repository" >&2
	exit 3
fi

[ "$(grep -c '^_gallium_drivers="[^"]*llvmpipe[^"]*"$' "$file")" = 1 ] || {
	echo "expected one _gallium_drivers=\"…llvmpipe…\" line in $file" >&2
	exit 1
}
sed -i.orig 's/^\(_gallium_drivers="[^"]*llvmpipe\)/\1,virgl/' "$file"
grep -q '^_gallium_drivers="[^"]*llvmpipe,virgl' "$file" || {
	echo "could not add virgl to _gallium_drivers" >&2
	exit 1
}

rel=$(sed -n 's/^pkgrel=\([0-9][0-9]*\)$/\1/p' "$file")
[ -n "$rel" ] || { echo "no pkgrel in $file" >&2; exit 1; }
sed -i.orig "s/^pkgrel=$rel\$/pkgrel=$((rel + BUMP))/" "$file"
rm -f "$file.orig"

ver=$(sed -n 's/^pkgver=\(.*\)$/\1/p' "$file")
[ -n "$ver" ] || { echo "no pkgver in $file" >&2; exit 1; }
echo "$ver-r$((rel + BUMP))"
