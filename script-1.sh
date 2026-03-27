apt update -y && apt install -y python3-venv python3-pip python3-psutil ufw && ufw allow 8080/tcp && ufw --force enable
python3 -m venv /root/venv && source /root/venv/bin/activate && pip install flask requests psutil
cat >/root/proxy.py <<'PYTHON'
from flask import Flask, request, Response, jsonify, render_template_string
import requests, os, re, psutil, time
app = Flask(__name__)
HTML='''<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Proxy</title><style>body{background:#121212;color:#eee;font-family:sans-serif;padding:20px}input,button{padding:10px;margin:5px;width:100%;max-width:500px;background:#222;color:#eee;border:1px solid #444}button:hover{background:#333}.m{margin-top:20px}</style></head><body><h2>Proxy Downloader</h2><form action="/download"><input name="url" placeholder="File URL"><button>Download</button></form><div class="m"><h3>Monitor</h3><div id="cpu"></div><div id="ram"></div><div id="disk"></div><div id="net"></div><div id="total"></div></div><script>setInterval(()=>fetch('/status').then(r=>r.json()).then(d=>{cpu.innerText='CPU: '+d.cpu+'%';ram.innerText='RAM: '+d.ram+'%';disk.innerText='Disk: '+d.disk+'%';net.innerText='Net: '+d.net;total.innerText='Total BW: '+d.total;}),1000)</script></body></html>'''
p,pt=psutil.net_io_counters(),time.time()
def bw(): global p,pt; n,t=psutil.net_io_counters(),time.time(); d=t-pt or 1; s=(n.bytes_sent-p.bytes_sent)/d; r=(n.bytes_recv-p.bytes_recv)/d; p,pt=n,t; f=lambda b:f"{b/1024:.2f}KB/s"if b<1e6 else f"{b/1e6:.2f}MB/s"; return f"↑{f(s)} ↓{f(r)}"
def total(): n=psutil.net_io_counters(); f=lambda b:f"{b/1e6:.2f}MB"; return f"Sent:{f(n.bytes_sent)} Received:{f(n.bytes_recv)}"
def filename(r,u): cd=r.headers.get('Content-Disposition'); return re.search(r'filename="?(.*?)"',cd).group(1) if cd and re.search(r'filename="?(.*?)"',cd) else os.path.basename(u) or 'file'
@app.route('/') 
def index(): return render_template_string(HTML)
@app.route('/download') 
def download(): u=request.args.get('url'); h={'Range':request.headers.get('Range')} if request.headers.get('Range') else {}; r=requests.get(u,stream=True,headers=h); return Response(r.iter_content(8192),headers={'Content-Disposition':f'attachment; filename="{filename(r,u)}"','Content-Type':r.headers.get('Content-Type','application/octet-stream')})
@app.route('/status') 
def status(): return jsonify({'cpu':psutil.cpu_percent(),'ram':psutil.virtual_memory().percent,'disk':psutil.disk_usage('/').percent,'net':bw(),'total':total()})
app.run(host='0.0.0.0',port=8080)
PYTHON

cat >/etc/systemd/system/proxy.service <<'SERVICE'
[Unit]
Description=Proxy
After=network.target
[Service]
ExecStart=/root/venv/bin/python /root/proxy.py
Restart=always
[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload && systemctl enable proxy && systemctl restart proxy
