#!/bin/bash
# Run on the Jetson: starts rosbridge + a Cloudflare quick tunnel and prints the dashboard link.
# Needs once: sudo apt install ros-jazzy-rosbridge-server   (cloudflared is downloaded automatically)
# Stop with Ctrl+C.

PORT=9090
PAGE="https://usn-argentum.github.io/dashboard/"
CLOUDFLARED="$HOME/.local/bin/cloudflared"

# Only these topics are reachable through the tunnel; services and params are blocked.
TOPICS="[/camera/camera/color/image_raw/compressed,/lidar_scan]"

source /opt/ros/jazzy/setup.bash

if [ ! -x "$CLOUDFLARED" ]; then
    echo "Downloading cloudflared..."
    mkdir -p "$(dirname "$CLOUDFLARED")"
    curl -fsSL -o "$CLOUDFLARED" \
        https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 || exit 1
    chmod +x "$CLOUDFLARED"
fi

LOG=$(mktemp)
trap 'kill $BRIDGE $TUNNEL 2>/dev/null; rm -f "$LOG"; exit' INT TERM EXIT

# Inner single quotes keep launch from parsing the globs as YAML lists (rosbridge wants a string)
ros2 launch rosbridge_server rosbridge_websocket_launch.xml \
    port:=$PORT topics_glob:="'$TOPICS'" services_glob:="'[/none]'" params_glob:="'[/none]'" \
    > /tmp/rosbridge.log 2>&1 &
BRIDGE=$!

"$CLOUDFLARED" tunnel --no-autoupdate --url http://localhost:$PORT > "$LOG" 2>&1 &
TUNNEL=$!

echo "Waiting for tunnel..."
for _ in $(seq 30); do
    # api.trycloudflare.com also shows up in the log (incl. error lines); it is not the tunnel
    URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOG" | grep -v '//api\.' | head -1)
    [ -n "$URL" ] && break
    kill -0 $TUNNEL 2>/dev/null || break
    sleep 1
done

if [ -z "$URL" ]; then
    echo "Tunnel did not come up. cloudflared output:"; cat "$LOG"
    grep -q 'no such host' "$LOG" && echo "DNS lookup failed: the phone hotspot blocks trycloudflare.com, see README."
    exit 1
fi

echo
echo "Tunnel:    $URL"
echo "Dashboard: ${PAGE}?url=${URL}"
echo
# The URL changes on every start; keep the current one findable when running as a service
echo "${PAGE}?url=${URL}" > "$HOME/stream_url.txt"
echo "Streaming. Ctrl+C to stop. (rosbridge log: /tmp/rosbridge.log)"
wait $TUNNEL
