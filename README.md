# alpymist-mesa

Alpine's Mesa with the virgl driver, for [Alpymist](https://alpymist.org) in a
virtual machine.

Alpine 3.24 builds Mesa without `virgl`, the driver for the 3D that QEMU and
UTM offer a guest through virtio-gpu. Without it every frame is drawn on the
processor by llvmpipe: Hyprland at 1280x800 took four cores to animate a
workspace switch, and 5% of one with the driver. Alpine has since put the
driver back (aports [!107536](https://gitlab.alpinelinux.org/alpine/aports/-/merge_requests/107536)),
but only on its development branch, so it arrives with Alpine 3.25.

Until then this repository builds Alpine's own aport with that one word added,
and publishes the result as an apk repository that only a system which asks
for it follows.

## What it is

Not a fork. There is no copy of Mesa or of Alpine's aport here to keep in
step. Each night [`nightly.yml`](.github/workflows/nightly.yml):

1. reads the last commit to `main/mesa` on Alpine's `3.24-stable`, and stops if
   the published packages were built from it;
2. fetches the aport at that commit and runs [`patch.sh`](patch.sh) over it:
   `virgl` added to `_gallium_drivers`, and `pkgrel` raised by 100, so that
   `26.1.6-r100` is preferred to Alpine's `26.1.6-r0` and to any rebuild of it;
3. builds it for x86_64 and aarch64 in an `alpine:3.24` container, on native
   runners ([`build.sh`](build.sh));
4. signs the index with the guest key and publishes
   ([`publish.sh`](publish.sh)).

The sources are the ones Alpine's APKBUILD names, pinned by its `sha512sums`.

When Alpine ships a newer Mesa, apk prefers Alpine's until the next night's
build is out. Nothing breaks in between: the guest draws on the processor
again for those hours.

## Following it

On Alpymist, the installer offers it when it finds itself in a virtual
machine, and afterwards:

```sh
doas alpymist guest on     # follow this repository, trust its key, upgrade
doas alpymist guest off    # stop, distrust it, back to Alpine's Mesa
```

By hand, on any Alpine 3.24:

```sh
doas cp alpymist-guest-2026.rsa.pub /etc/apk/keys/
echo https://guest.pkgs.alpymist.org/v3.24/guest | doas tee -a /etc/apk/repositories
doas apk upgrade --update-cache
```

## Trust

The index is signed with a key that exists for this repository alone,
`alpymist-guest-2026.rsa`, whose public half is [here](alpymist-guest-2026.rsa.pub)
and in Alpymist's `alpymist-keys`. apk trusts every key in `/etc/apk/keys`
for every repository, so it is put there only on a system that turns this on.

The key is a secret of the `guest-channel` environment, which only `main` may
deploy to. The build jobs, which run Alpine's APKBUILD and Mesa's build
system, never see it; the job that signs runs nothing but `apk index` and
`abuild-sign`.

## When it ends

`patch.sh` exits 3 when Alpine's APKBUILD already builds virgl, which fails
the nightly run and sends its mail. That is the day to turn the schedule off
and archive this repository: Alpine's Mesa then sorts above nothing of ours
that matters, and `alpymist guest off` — or doing nothing — leaves a system on
it. To follow a new Alpine release instead, change `release.conf`.

## Running it by hand

Actions → Nightly → Run workflow builds only if Alpine's mesa has moved;
tick *force* to build regardless. A run on any branch but `main` builds and
publishes nothing.
