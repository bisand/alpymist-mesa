#!/bin/sh
# Lays the built packages out as an apk repository and signs its index with the
# guest key. Inside an alpine container, as root, with this repository at /src:
#
#   publish.sh PACKAGES SITE KEY VERSION COMMIT
#
# PACKAGES holds one directory of .apk files for each architecture, SITE is
# where the site is written, KEY is the private key, and VERSION and COMMIT
# are what was built and from which commit of Alpine's aports.
#
# Only the index is signed with the guest key. apk takes a package whose hash
# is in an index it trusts and refuses one whose hash is not, whatever key
# abuild signed the package itself with in the build job.
set -eu

packages=${1:?}
site=${2:?}
key=${3:?}
version=${4:?}
commit=${5:?}

. /src/release.conf

# The signature names the key it was made with, and apk looks for a public key
# of exactly that name in /etc/apk/keys.
[ "$(basename "$key")" = "$KEY_NAME" ] || {
	echo "the key file has to be called $KEY_NAME" >&2
	exit 1
}

apk add --no-cache -q abuild

repo="$site/$BRANCH/guest"
for dir in "$packages"/*/; do
	arch=$(basename "$dir")
	mkdir -p "$repo/$arch"
	cp "$dir"/*.apk "$repo/$arch"/
	(
		cd "$repo/$arch"
		apk index --allow-untrusted --no-warnings --quiet \
			--rewrite-arch "$arch" --output APKINDEX.tar.gz ./*.apk
		abuild-sign -q -k "$key" APKINDEX.tar.gz
	)
done

# What was built, for the nightly check to compare with Alpine's.
echo "$version $commit" > "$site/$BRANCH/VERSION"
touch "$site/.nojekyll"
[ -z "${DOMAIN:-}" ] || echo "$DOMAIN" > "$site/CNAME"
cat > "$site/index.html" <<EOF
<!doctype html>
<meta charset="utf-8">
<title>Alpymist guest packages</title>
<p>Mesa $version for Alpine $BRANCH with the virgl driver, for Alpymist in a
virtual machine. See <a href="https://github.com/bisand/alpymist-mesa">bisand/alpymist-mesa</a>.</p>
EOF

# Proof that a system trusting only the committed public key takes the index,
# and finds the driver package in it, for every architecture.
for dir in "$repo"/*/; do
	arch=$(basename "$dir")
	root=$(mktemp -d)
	mkdir -p "$root/etc/apk/keys"
	cp "/src/$KEY_NAME.pub" "$root/etc/apk/keys/"
	apk add --root "$root" --initdb --arch "$arch" --quiet \
		--repositories-file /dev/null --repository "$repo" --no-cache
	# apk only warns about an index it does not trust, and lists what is in
	# it all the same, so the warning is what has to be looked for.
	said=$(apk update --root "$root" --arch "$arch" \
		--repositories-file /dev/null --repository "$repo" --no-cache 2>&1) || {
		echo "$arch: $said" >&2
		exit 1
	}
	case "$said" in
	*WARNING* | *ERROR* | *signature* | *UNTRUSTED*)
		echo "$arch: the index is not trusted by $KEY_NAME.pub:" >&2
		echo "$said" >&2
		exit 1
		;;
	esac
	found=$(apk --root "$root" --arch "$arch" \
		--repositories-file /dev/null --repository "$repo" \
		--no-cache search --exact mesa-dri-gallium)
	[ "$found" = "mesa-dri-gallium-$version" ] || {
		echo "$arch: the signed index has '$found', not mesa-dri-gallium-$version" >&2
		exit 1
	}
	echo "$arch: mesa-dri-gallium-$version, index verified"
done
