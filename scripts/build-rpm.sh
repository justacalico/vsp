#!/usr/bin/env bash
# Build a minimal .rpm for the Flutter linux bundle without a spec-file
# toolchain — rpm -bb via a generated spec. Args:
#   $1 bundle dir  $2 version  $3 rpm arch (x86_64|aarch64)  $4 output path  $5 release
set -euo pipefail

BUNDLE="$1"; VERSION="$2"; RPM_ARCH="$3"; OUT="$4"; RELEASE="${5:-1}"

TOPDIR="$(mktemp -d)"
trap 'rm -rf "$TOPDIR"' EXIT
mkdir -p "$TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS,BUILDROOT}

# Stage payload under BUILDROOT/opt/vsp.
ROOT="$TOPDIR/BUILDROOT/vsp-${VERSION}-${RELEASE}.${RPM_ARCH}"
mkdir -p "$ROOT/opt/vsp" "$ROOT/usr/bin" \
  "$ROOT/usr/share/applications" "$ROOT/usr/share/icons/hicolor/256x256/apps"
cp -r "$BUNDLE/." "$ROOT/opt/vsp/"
ln -sf /opt/vsp/vsp "$ROOT/usr/bin/vsp"
cp "$(dirname "$0")/../packaging/linux/vsp.desktop" "$ROOT/usr/share/applications/vsp.desktop"
cp "$(dirname "$0")/../assets/icon-1024.png" "$ROOT/usr/share/icons/hicolor/256x256/apps/vsp.png"

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
mkdir -p %{buildroot}
cp -r "$ROOT"/* %{buildroot}/

%files
/opt/vsp
/usr/bin/vsp
/usr/share/applications/vsp.desktop
/usr/share/icons/hicolor/256x256/apps/vsp.png
EOF

rpmbuild -bb --buildroot "$ROOT" --define "_topdir $TOPDIR" \
  --target "$RPM_ARCH" "$TOPDIR/SPECS/vsp.spec"
cp "$TOPDIR/RPMS/$RPM_ARCH/vsp-${VERSION}-${RELEASE}.${RPM_ARCH}.rpm" "$OUT"
echo "Wrote $OUT"
