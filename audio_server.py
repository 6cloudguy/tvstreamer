import flask
import subprocess

app = flask.Flask(__name__)

@app.route('/stream.mp3')
def stream():
    def generate():
        proc = subprocess.Popen([
            'ffmpeg', '-f', 'pulse',
            '-i', 'alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink.monitor',
            '-acodec', 'libmp3lame', '-ab', '128k', '-ar', '44100',
            '-f', 'mp3', 'pipe:1'
        ], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        
        while True:
            data = proc.stdout.read(4096)
            if not data:
                break
            yield data

    response = flask.Response(generate(), mimetype='audio/mpeg')
    response.headers['Content-Type'] = 'audio/mpeg'
    response.headers['transferMode.dlna.org'] = 'Streaming'
    response.headers['contentFeatures.dlna.org'] = 'DLNA.ORG_PN=MP3;DLNA.ORG_OP=01;DLNA.ORG_FLAGS=0170000'
    return response

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
