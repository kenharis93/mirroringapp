const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const http = require('http');
const { WebSocketServer } = require('ws');

let mainWindow;
let server;
let wss;
let serverPort = 0;
let localHost = '127.0.0.1';
let sessionId = '';
const QRCode = require('qrcode');

const sessions = new Map(); // sid -> { sender, viewer, qToSender, qToViewer }

function randomSid() {
  return crypto.randomBytes(8).toString('hex');
}

function getLocalIPv4() {
  const ifaces = os.networkInterfaces();
  // Prefer en0 (Wi-Fi) if present
  if (ifaces.en0) {
    for (const iface of ifaces.en0) {
      if (iface.family === 'IPv4' && !iface.internal) return iface.address;
    }
  }
  for (const name of Object.keys(ifaces)) {
    for (const iface of ifaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) return iface.address;
    }
  }
  return '127.0.0.1';
}

function getOrCreateSession(sid) {
  let s = sessions.get(sid);
  if (!s) {
    s = { sender: null, viewer: null, qToSender: [], qToViewer: [] };
    sessions.set(sid, s);
  }
  return s;
}

function createServer() {
  localHost = getLocalIPv4();
  sessionId = randomSid();

  server = http.createServer();
  wss = new WebSocketServer({ server });

  wss.on('connection', (ws) => {
    ws.on('message', (data) => {
      let msg;
      try { msg = JSON.parse(data); } catch (e) { return; }
      const sid = msg.sid || ws._sid;
      if (!sid) return;
      const sess = getOrCreateSession(sid);

      if (msg.type === 'hello') {
        ws._sid = sid;
        ws._role = msg.role;
        if (msg.role === 'sender') {
          sess.sender = ws;
          while (sess.qToSender.length) {
            try { ws.send(JSON.stringify(sess.qToSender.shift())); } catch {}
          }
          if (sess.viewer) {
            try { sess.viewer.send(JSON.stringify({ type: 'sender-joined', sid })); } catch {}
          }
        } else if (msg.role === 'viewer') {
          sess.viewer = ws;
          while (sess.qToViewer.length) {
            try { ws.send(JSON.stringify(sess.qToViewer.shift())); } catch {}
          }
          if (sess.sender) {
            try { sess.sender.send(JSON.stringify({ type: 'viewer-joined', sid })); } catch {}
          }
        }
        return;
      }

      const from = ws._role;
      if (from === 'sender') {
        if (msg.type === 'offer' || msg.type === 'ice') {
          if (sess.viewer) {
            try { sess.viewer.send(JSON.stringify(msg)); } catch {}
          } else {
            sess.qToViewer.push(msg);
          }
        }
      } else if (from === 'viewer') {
        if (msg.type === 'answer' || msg.type === 'ice') {
          if (sess.sender) {
            try { sess.sender.send(JSON.stringify(msg)); } catch {}
          } else {
            sess.qToSender.push(msg);
          }
        }
      }
    });

    ws.on('close', () => {
      const sid = ws._sid;
      const role = ws._role;
      if (!sid) return;
      const sess = sessions.get(sid);
      if (!sess) return;
      if (role === 'sender' && sess.sender === ws) {
        sess.sender = null;
        if (sess.viewer) {
          try { sess.viewer.send(JSON.stringify({ type: 'bye', sid })); } catch {}
        }
      }
      if (role === 'viewer' && sess.viewer === ws) {
        sess.viewer = null;
        if (sess.sender) {
          try { sess.sender.send(JSON.stringify({ type: 'bye', sid })); } catch {}
        }
      }
    });
  });

  server.listen(0, '0.0.0.0', () => {
    serverPort = server.address().port;
    if (mainWindow) mainWindow.webContents.send('server-ready');
  });
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 480,
    height: 740,
    minWidth: 360,
    minHeight: 480,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });
  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

app.whenReady().then(() => {
  createServer();
  createWindow();

  ipcMain.handle('session-info', () => {
    return { host: localHost, port: serverPort, sid: sessionId };
  });

  ipcMain.handle('regenerate-session', () => {
    sessionId = randomSid();
    return { host: localHost, port: serverPort, sid: sessionId };
  });

  ipcMain.handle('setAlwaysOnTop', (_evt, on) => {
    if (mainWindow) mainWindow.setAlwaysOnTop(!!on);
    return { on: !!on };
  });

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
  ipcMain.handle('generate-qr', async (_evt, text) => {
    try {
      return await QRCode.toDataURL(String(text || ''));
    } catch (e) {
      return null;
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
