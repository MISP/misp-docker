from flask import Flask, jsonify # type: ignore
from pymisp import PyMISP # type: ignore
import os

MISP_URL = os.getenv("MISP_URL")  # MISP 서버 주소
MISP_KEY = os.getenv("MISP_KEY")  # MISP API 키
MISP_VERIFY_CERT = False  # SSL 인증서 검증 여부

app = Flask(__name__)
misp = PyMISP(MISP_URL, MISP_KEY, MISP_VERIFY_CERT, debug=True)

@app.route('/health')
def health():
    resp = jsonify()
    resp.status_code = 200
    return resp

@app.route('/events', methods=['GET'])
def get_events():
    """MISP 이벤트 목록 가져오기"""
    try:
        events = misp.search()
        return jsonify(events)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/getWebShellListSHA265', methods=['POST'])
def getWebShellListSHA265():
    try:
        result = misp.search(
            controller="attributes",
            return_format='text',
            type_attribute="md5",
            tags=["malware", "php", "webshell"]
        )
        return result, 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/getMalwareUrlList', methods=['POST'])
def getMalwareUrlList():
    try:
        result = misp.search(
            controller="attributes",
            return_format='text',
            type_attribute="url",
        )
        return result, 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/search_attributes', methods=['POST'])
def search_attributes():
    """MISP에서 속성 검색"""
    try:
        result = misp.search()
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=8080)