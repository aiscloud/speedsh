#!/bin/bash
echo "🚀 正在部署云清网络测速面板（玻璃UI）..."

mkdir -p /opt/net_speed_panel/{templates,static}
cd /opt/net_speed_panel || exit

# 写入 app.py
cat > app.py << 'PY'
from flask import Flask, render_template, jsonify
import subprocess, re, threading

app = Flask(__name__)
result = {"status": "idle", "download": "-", "upload": "-", "avg": "-", "loss": "-"}

def run_speedtest():
    global result
    result["status"] = "testing"
    try:
        spd = subprocess.check_output(["speedtest-cli", "--simple"], universal_newlines=True)
        result["download"] = re.search(r"Download: (.+?) Mbit/s", spd).group(1)
        result["upload"] = re.search(r"Upload: (.+?) Mbit/s", spd).group(1)
    except:
        result["download"], result["upload"] = "错误", "错误"

    try:
        ping = subprocess.check_output(["ping", "-c", "4", "8.8.8.8"], universal_newlines=True)
        result["loss"] = re.search(r"(\d+)% packet loss", ping).group(1)
        result["avg"] = re.search(r"min/avg/max.*? = [\d\.]+/([\d\.]+)", ping).group(1)
    except:
        result["loss"], result["avg"] = "100", "0"

    result["status"] = "done"

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/ping")
def ping():
    return "pong"

@app.route("/start")
def start():
    thread = threading.Thread(target=run_speedtest)
    thread.start()
    return jsonify({"status": "started"})

@app.route("/result")
def get_result():
    return jsonify(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
PY

# 写入 HTML
cat > templates/index.html << 'HTML'
<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="UTF-8">
  <title>网络测速面板</title>
  <link rel="stylesheet" href="/static/style.css">
</head>
<body>
  <div class="glass">
    <h1>🌐 网络状态</h1>
    <p>下载速度：<span id="download">-</span> Mbps</p>
    <p>上传速度：<span id="upload">-</span> Mbps</p>
    <p>延迟：<span id="avg">-</span> ms</p>
    <p>丢包率：<span id="loss">-</span> %</p>
    <p id="progress"></p>
    <button onclick="startTest()">开始测速</button>
  </div>

  <script>
    function startTest() {
      document.getElementById("progress").textContent = "测速中...";
      fetch("/start");

      let timer = setInterval(() => {
        fetch("/result").then(res => res.json()).then(data => {
          document.getElementById("download").textContent = data.download;
          document.getElementById("upload").textContent = data.upload;
          document.getElementById("avg").textContent = data.avg;
          document.getElementById("loss").textContent = data.loss;
          if (data.status === "done") {
            document.getElementById("progress").textContent = "测速完成 ✅";
            clearInterval(timer);
          }
        });
      }, 1000);
    }
  </script>
</body>
</html>
HTML

# 写入 CSS
cat > static/style.css << 'CSS'
body {
  margin: 0;
  padding: 0;
  font-family: 'Segoe UI', sans-serif;
  height: 100vh;
  background: url('https://picsum.photos/1600/900?blur=10') no-repeat center center fixed;
  background-size: cover;
  display: flex;
  align-items: center;
  justify-content: center;
}

.glass {
  background: rgba(255, 255, 255, 0.12);
  padding: 30px 40px;
  border-radius: 20px;
  backdrop-filter: blur(12px);
  box-shadow: 0 8px 32px rgba(0,0,0,0.3);
  color: #fff;
  text-align: center;
  border: 1px solid rgba(255,255,255,0.2);
}

button {
  padding: 10px 25px;
  margin-top: 20px;
  border: none;
  border-radius: 10px;
  background: rgba(255,255,255,0.2);
  color: #fff;
  font-size: 16px;
  cursor: pointer;
}

button:hover {
  background: rgba(255,255,255,0.35);
}
CSS

# 安装依赖
apt update
apt install -y python3-pip
pip3 install flask speedtest-cli

# 启动服务
echo "✅ 部署完成！请访问：http://<你的服务器IP>:8080"
cd /opt/net_speed_panel && python3 app.py
