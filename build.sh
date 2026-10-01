#!/bin/sh
# Builds Alpine's mesa aport, as patch.sh changes it, for the architecture this
# runs on. Inside an alpine container of the release in BRANCH, as root, with
# this repository at /src:
#
#   build.sh COMMIT OUT
#
# COMMIT is the commit of Alpine's aports the aport is taken from; the sources
# it names are pinned by the sha512sums in that APKBUILD, which abuild checks
# as it fetches them. OUT gets the packages.
#
# The key abuild signs with here is made for this build and trusted by nobody.
# What installed systems trust is the repository index, which the publish job
# signs with the guest key; this job never sees that key.
set -eu

commit=${1:?usage: build.sh COMMIT OUT}
out=${2:?usage: build.sh COMMIT OUT}

apk add --no-cache -q alpine-sdk doas
adduser -D -G abuild builder
echo 'permit nopass :abuild' > /etc/doas.d/abuild.conf

mkdir -p /home/builder/ap
wget -q -O /tmp/aport.tar.gz \
	"https://gitlab.alpinelinux.org/alpine/aports/-/archive/$commit/aports-$commit.tar.gz?path=main/mesa"
tar -xzf /tmp/aport.tar.gz -C /home/builder/ap --strip-components=2
version=$(/src/patch.sh /home/builder/ap/mesa/APKBUILD)
echo "building mesa $version from aports $commit"
chown -R builder:abuild /home/builder/ap

su builder -c '
	set -eu
	abuild-keygen -a -i -n >/dev/null 2>&1
	cd ~/ap/mesa
	abuild -r
'

arch=$(apk --print-arch)
mkdir -p "$out"
# Everything but the debug symbols, which are most of the bytes and nothing an
# installed desktop asks for.
for apk in /home/builder/packages/ap/"$arch"/*.apk; do
	case "$apk" in
	*/mesa-dbg-*) ;;
	*) cp "$apk" "$out"/ ;;
	esac
done
ls -l "$out"
