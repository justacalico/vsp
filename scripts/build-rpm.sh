#!/usr/bin/env bash
# Build a minimal .rpm for the Flutter linux bundle without a spec-file
# toolchain — rpmbuild via a generated spec. Args:
#   $1 bundle dir  $2 version  $3 rpm arch (x86_64|aarch64)  $4 output path  $5 release
set -euo pipefail

BUNDLE="$1"; VERSION="$2"; RPM_ARCH="$3"; OUT="$4"; RELEASE="${5:-1}"

TOPDIR="$(mktemp -d)"
trap 'rm -rf "$TOPDIR"' EXIT
mkdir -p "$TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS,BUILDROOT}

# Stage the payload outside the buildroot — rpmbuild wipes it at %install.
STAGE="$TOPDIR/stage"
BUILDROOT="$TOPDIR/BUILDROOT/vsp-${VERSION}-${RELEASE}.${RPM_ARCH}"
mkdir -p "$STAGE/opt/vsp" "$STAGE/usr/bin" \
  "$STAGE/usr/share/applications" "$STAGE/usr/share/icons/hicolor/256x256/apps"
cp -r "$BUNDLE/." "$STAGE/opt/vsp/"
ln -sf /opt/vsp/vsp "$STAGE/usr/bin/vsp"
cp "$(dirname "$0")/../packaging/linux/vsp.desktop" "$STAGE/usr/share/applications/vsp.desktop"
cp "$(dirname "$0")/../assets/icon-1024.png" "$STAGE/usr/share/icons/hicolor/256x256/apps/vsp.png"

cat > "$TOPDIR/SPECS/vsp.spec" <<EOF
Name: vsp
Version: $VERSION
Release: $RELEASE
Summary: VNC + SSH client — one window into every machine
License: AGPL-3.0
BuildArch: $RPM_ARCH

%description
One window into every machine: SSH terminals, VNC desktops, keys and
host fingerprints in one place.

%install
cp -r "$STAGE"/* %{buildroot}/

%files
/opt/vsp
/usr/bin/vsp
/usr/share/applications/vsp.desktop
/usr/share/icons/hicolor/256x256/apps/vsp.png
EOF

rpmbuild -bb --buildroot "$BUILDROOT" --define "_topdir $TOPDIR" \
  --target "$RPM_ARCH" "$TOPDIR/SPECS/vsp.spec"
cp "$TOPDIR/RPMS/$RPM_ARCH/vsp-${VERSION}-${RELEASE}.${RPM_ARCH}.rpm" "$OUT"
echo "Wrote $OUT"
