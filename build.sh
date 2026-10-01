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

# From GitHub's mirror of aports, which is the one the runners can reach, and
# only the one directory of it.
mkdir -p /home/builder/ap /tmp/aports
(
	cd /tmp/aports
	git init -q
	git remote add origin https://github.com/alpinelinux/aports
	git sparse-checkout set main/mesa
	git fetch -q --depth 1 --filter=blob:none origin "$commit"
	git checkout -q FETCH_HEAD
	[ "$(git rev-parse HEAD)" = "$commit" ]
)
cp -r /tmp/aports/main/mesa /home/builder/ap/mesa
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
