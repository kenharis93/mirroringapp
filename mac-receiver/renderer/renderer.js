(() => {
  const infoEl = document.getElementById('info');
  const qrImg = document.getElementById('qrImg');
  const video = document.getElementById('remoteVideo');
  const aot = document.getElementById('aot');
  const showQRBtn = document.getElementById('showQRBtn');
  const regenBtn = document.getElementById('regenBtn');
  const fitToggle = document.getElementById('fitToggle');
  const dimLabel = document.getElementById('dimLabel');

  let pc = null;
  let ws = null;
  let session = null;

  async function init() {
    await refreshQR();
    aot.addEventListener('change', () => {
      window.app.setAlwaysOnTop(aot.checked);
    });
    showQRBtn.addEventListener('click', () => setQRVisible(true));
    regenBtn.addEventListener('click', async () => {
      await window.app.regenerateSession();
      await refreshQR();
      reconnectWS();
    });
    window.app.onServerReady(async () => {
      await refreshQR();
      reconnectWS();
    });
    fitToggle.addEventListener('change', applyLayout);
    document.querySelectorAll('input[name="zoom"]').forEach(el => {
      el.addEventListener('change', applyLayout);
    });
    window.addEventListener('resize', applyLayout);
    connectWS();
  }

  function connectWS() {
    ws = new WebSocket(`ws://${session.host}:${session.port}`);
    ws.addEventListener('open', () => {
      ws.send(JSON.stringify({ type: 'hello', role: 'viewer', sid: session.sid }));
    });
    ws.addEventListener('message', onWSMessage);
    ws.addEventListener('close', () => {
      if (pc) { pc.close(); pc = null; }
      video.srcObject = null;
    });
  }

  function reconnectWS() {
    try { ws?.close(); } catch {}
    connectWS();
  }

  async function onWSMessage(ev) {
    let msg; try { msg = JSON.parse(ev.data); } catch { return; }
    if (msg.type === 'offer') {
      await ensurePC();
      await pc.setRemoteDescription(new RTCSessionDescription(msg.sdp));
      const answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      ws.send(JSON.stringify({ type: 'answer', sid: session.sid, sdp: pc.localDescription }));
    } else if (msg.type === 'ice') {
      if (pc && msg.candidate) {
        try { await pc.addIceCandidate(new RTCIceCandidate(msg.candidate)); } catch {}
      }
    } else if (msg.type === 'bye') {
      if (pc) { pc.close(); pc = null; }
      video.srcObject = null;
    }
  }

  async function ensurePC() {
    if (pc) return pc;
    pc = new RTCPeerConnection({ iceServers: [] });
    pc.onicecandidate = (e) => {
      if (e.candidate) {
        ws?.send(JSON.stringify({ type: 'ice', sid: session.sid, candidate: e.candidate }));
      }
    };
    pc.ontrack = (e) => {
      const stream = e.streams && e.streams[0] ? e.streams[0] : new MediaStream([e.track]);
      video.srcObject = stream;
      setQRVisible(false);
      video.onloadedmetadata = () => {
        updateDimLabel();
        applyLayout();
      };
    };
    return pc;
  }

  async function refreshQR() {
    session = await window.app.getSessionInfo();
    if (!session.port || session.port === 0) {
      infoEl.textContent = 'Starting local server…';
      qrImg.removeAttribute('src');
      return;
    }
    const payload = JSON.stringify({ h: session.host, p: session.port, sid: session.sid });
    infoEl.textContent = payload;
    try {
      const dataUrl = await window.app.generateQR(payload);
      if (!dataUrl) throw new Error('QR IPC returned null');
      qrImg.src = dataUrl;
    } catch (e) {
      console.error('QR generation failed', e);
      infoEl.textContent += '\n[Failed to render QR]';
    }
  }

  function setQRVisible(v) {
    document.getElementById('qrArea').style.display = v ? 'block' : 'none';
  }

  function updateDimLabel() {
    if (!video.videoWidth) { dimLabel.textContent = ''; return; }
    dimLabel.textContent = `${video.videoWidth}×${video.videoHeight}`;
  }

  function applyLayout() {
    if (!video) return;
    const wrap = document.getElementById('videoWrap');
    const fit = fitToggle.checked;
    const selectedZoom = Number((document.querySelector('input[name="zoom"]:checked')||{}).value || 1);
    video.style.transformOrigin = 'top left';
    if (fit) {
      // compute scale to fit container
      const vw = video.videoWidth || 1080;
      const vh = video.videoHeight || 1920;
      const cw = wrap.clientWidth;
      const ch = wrap.clientHeight;
      const scale = Math.min(cw / vw, ch / vh);
      video.style.transform = `scale(${scale})`;
      video.style.width = `${vw}px`;
      video.style.height = `${vh}px`;
      wrap.style.overflow = 'hidden';
    } else {
      video.style.transform = `scale(${selectedZoom})`;
      video.style.width = `${video.videoWidth || 1080}px`;
      video.style.height = `${video.videoHeight || 1920}px`;
      wrap.style.overflow = 'auto';
    }
  }

  init();
})();
