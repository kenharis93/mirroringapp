const { contextBridge, ipcRenderer } = require('electron');
const QRCode = require('qrcode');

contextBridge.exposeInMainWorld('app', {
  getSessionInfo: () => ipcRenderer.invoke('session-info'),
  regenerateSession: () => ipcRenderer.invoke('regenerate-session'),
  setAlwaysOnTop: (on) => ipcRenderer.invoke('setAlwaysOnTop', on),
  generateQR: (text) => QRCode.toDataURL(text),
  onServerReady: (cb) => ipcRenderer.on('server-ready', cb)
});
