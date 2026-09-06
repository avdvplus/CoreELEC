#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

JRE="/storage/.kodi/addons/tools.jre.zulu/jre"
ADDON="/storage/.kodi/addons/tools.jre.zulu"
SHIPPED_JARS="/usr/share/coreelec/bdj"

[ -d "$JRE" ] || exit 0

if [ -d "$JRE/lib/arm" ] && [ ! -d "$JRE/lib/aarch32" ]; then
  ln -sfn arm "$JRE/lib/aarch32" 2>/dev/null
fi
if [ -d "$JRE/lib/arm/server" ] && [ ! -d "$JRE/lib/arm/client" ]; then
  ln -sfn server "$JRE/lib/arm/client" 2>/dev/null
fi
if [ -d "$JRE/bin" ] && [ ! -d "$ADDON/bin" ]; then
  ln -sfn jre/bin "$ADDON/bin" 2>/dev/null
fi
chmod -R +x "$JRE/bin" 2>/dev/null

if [ -d "$SHIPPED_JARS" ]; then
  for src in "$SHIPPED_JARS"/*.jar; do
    [ -f "$src" ] || continue
    name="${src##*/}"
    src_md5=$(md5sum "$src" 2>/dev/null | awk '{print $1}')
    dst_md5=$(md5sum "$ADDON/$name" 2>/dev/null | awk '{print $1}')
    if [ -z "$dst_md5" ] || [ "$src_md5" != "$dst_md5" ]; then
      rm -f "$ADDON"/libbluray-*.jar 2>/dev/null
      cp "$SHIPPED_JARS"/*.jar "$ADDON"/ 2>/dev/null
      break
    fi
  done
fi

XML="$ADDON/addon.xml"
if [ -f "$XML" ] && ! grep -q 'version="21\.3\.99"' "$XML" 2>/dev/null; then
  sed -i 's/version="21\.[0-9][^"]*"/version="21.3.99"/' "$XML" 2>/dev/null
fi

exit 0
