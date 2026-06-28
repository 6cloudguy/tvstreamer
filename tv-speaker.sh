#!/bin/bash

TV_IP="192.168.18.33"
LAP_IP="192.168.18.180"
PORT="8080"
STREAM_URL="http://$LAP_IP:$PORT/stream.mp3"
MONITOR="alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink.monitor"

# Kill any previous instance
pkill -f "audio_server.py" 2>/dev/null
sleep 1

echo "🎵 Starting stream server..."
python3 ./audio_server.py &
SERVER_PID=$!
sleep 2

echo "Stopping any activity if any"
curl -X POST http://$TV_IP:2870/control/RenderingControl \
-H 'Content-Type: text/xml; charset="utf-8"' \
-H 'SOAPAction: "urn:schemas-upnp-org:service:RenderingControl:1#SetVolume"' \
-d '<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
<s:Body>
<u:SetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
<InstanceID>0</InstanceID>
<Channel>Master</Channel>
<DesiredVolume>100</DesiredVolume>
</u:SetVolume>
</s:Body>
</s:Envelope>'

echo "📺 Telling TV to tune in..."
curl -v -X POST \
http://$TV_IP:2870/control/AVTransport \
-H 'Content-Type: text/xml; charset="utf-8"' \
-H 'SOAPAction: "urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"' \
--data-binary @- <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
<s:Body>
<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
<InstanceID>0</InstanceID>
<CurrentURI>http://$STREAM_URL</CurrentURI>
<CurrentURIMetaData></CurrentURIMetaData>
</u:SetAVTransportURI>
</s:Body>
</s:Envelope>
EOF

sleep 1

echo "▶️  Sending play command..."
curl -s -X POST http://$TV_IP:2870/control/AVTransport \
  -H 'Content-Type: text/xml; charset="utf-8"' \
  -H 'SOAPAction: "urn:schemas-upnp-org:service:AVTransport:1#Play"' \
  -d '<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <Speed>1</Speed>
    </u:Play>
  </s:Body>
</s:Envelope>' > /dev/null

echo "✅ Done! Laptop audio is now playing on TV."
echo "   Run 'tvstop' to stop playback."
echo "   Press Ctrl+C to kill the stream server."

# Keep script running so stream server stays alive
wait $SERVER_PID
