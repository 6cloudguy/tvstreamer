#!/bin/bash

set -euo pipefail

TV_IP="192.168.18.33"
LAP_IP="192.168.18.180"
PORT="8080"

STREAM_URL="http://${LAP_IP}:${PORT}/stream.mp3"

# Only needed if audio_server.py reads it from the environment
export MONITOR="alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink.monitor"

SERVER_PID=""

cleanup() {
    echo
    echo "Stopping stream server..."

    if [[ -n "${SERVER_PID}" ]]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

echo "Stopping any previous stream server..."
pkill -f "audio_server.py" 2>/dev/null || true

sleep 1

echo "🎵 Starting stream server..."
python3 ./audio_server.py &
SERVER_PID=$!

sleep 0.5

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "❌ audio_server.py failed to start."
    exit 1
fi

echo "Waiting for stream server..."

for i in {1..30}; do
    if curl -fs "$STREAM_URL" >/dev/null 2>&1; then
        echo "✅ Stream server is ready."
        break
    fi
    sleep 0.5
done

if ! curl -fs "$STREAM_URL" >/dev/null 2>&1; then
    echo "❌ Stream server never became reachable."
    exit 1
fi

echo "🔊 Setting TV volume..."

curl -fsS \
    -X POST \
    "http://${TV_IP}:2870/control/RenderingControl" \
    -H 'Content-Type: text/xml; charset="utf-8"' \
    -H 'SOAPAction: "urn:schemas-upnp-org:service:RenderingControl:1#SetVolume"' \
    --data-binary @- <<EOF
<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <u:SetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
      <InstanceID>0</InstanceID>
      <Channel>Master</Channel>
      <DesiredVolume>100</DesiredVolume>
    </u:SetVolume>
  </s:Body>
</s:Envelope>
EOF

echo "📺 Setting TV stream URL..."

curl -fsS \
    -X POST \
    "http://${TV_IP}:2870/control/AVTransport" \
    -H 'Content-Type: text/xml; charset="utf-8"' \
    -H 'SOAPAction: "urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"' \
    --data-binary @- <<EOF
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <CurrentURI>${STREAM_URL}</CurrentURI>
      <CurrentURIMetaData></CurrentURIMetaData>
    </u:SetAVTransportURI>
  </s:Body>
</s:Envelope>
EOF

echo "▶️ Starting playback..."

curl -fsS \
    -X POST \
    "http://${TV_IP}:2870/control/AVTransport" \
    -H 'Content-Type: text/xml; charset="utf-8"' \
    -H 'SOAPAction: "urn:schemas-upnp-org:service:AVTransport:1#Play"' \
    --data-binary @- <<EOF
<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <Speed>1</Speed>
    </u:Play>
  </s:Body>
</s:Envelope>
EOF

echo
echo "✅ Laptop audio is now playing on the TV."
echo "Press Ctrl+C to stop."

wait "$SERVER_PID"
