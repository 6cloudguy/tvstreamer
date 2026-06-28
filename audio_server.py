#!/usr/bin/env python3

import os
import subprocess
import flask
from flask import stream_with_context

app = flask.Flask(__name__)

MONITOR = os.environ.get(
    "MONITOR",
    "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink.monitor"
)

FFMPEG_CMD = [
    "ffmpeg",
    "-nostdin",

    "-f", "pulse",
    "-i", MONITOR,

    "-ac", "2",
    "-ar", "44100",

    "-codec:a", "libmp3lame",
    "-b:a", "192k",

    "-fflags", "+genpts",
    "-flush_packets", "1",

    "-f", "mp3",
    "pipe:1",
]


@app.route("/stream.mp3")
def stream():

    def generate():

        proc = subprocess.Popen(
            FFMPEG_CMD,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=0,
        )

        try:
            while True:
                chunk = proc.stdout.read(16384)

                if not chunk:
                    break

                yield chunk

        except GeneratorExit:
            pass

        finally:
            if proc.poll() is None:
                proc.kill()

            proc.wait()

    response = flask.Response(
        stream_with_context(generate()),
        mimetype="audio/mpeg",
        direct_passthrough=True,
    )

    response.headers["Content-Type"] = "audio/mpeg"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["Pragma"] = "no-cache"
    response.headers["Connection"] = "keep-alive"

    # DLNA headers
    response.headers["transferMode.dlna.org"] = "Streaming"
    response.headers["contentFeatures.dlna.org"] = (
        "DLNA.ORG_PN=MP3;"
        "DLNA.ORG_OP=01;"
        "DLNA.ORG_FLAGS=01700000000000000000000000000000"
    )

    return response


@app.route("/")
def index():
    return "Audio streaming server is running.\n"


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=8080,
        threaded=False,
        debug=False,
        use_reloader=False,
    )
