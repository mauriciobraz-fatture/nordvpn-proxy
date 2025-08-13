#!/bin/bash

. /app/date.sh --source-only

echo "$(adddate) WARNING: OpenVPN will be restarted!"
pgrep openvpn | xargs kill -15
