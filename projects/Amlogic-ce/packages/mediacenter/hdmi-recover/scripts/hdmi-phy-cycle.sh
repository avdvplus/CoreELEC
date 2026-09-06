#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

PHY="/sys/class/amhdmitx/amhdmitx0/phy"

[ -e "$PHY" ] || exit 1

echo 0 > "$PHY"
sleep 1
echo 1 > "$PHY"
sleep 4
