const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('app', {
  getSessionInfo: () => ipcRenderer.invoke('session-info'),
  regenerateSession: () => ipcRenderer.invoke('regenerate-session'),
  setAlwaysOnTop: (on) => ipcRenderer.invoke('setAlwaysOnTop', on),
  onServerReady: (cb) => ipcRenderer.on('server-ready', cb),
  generateQR: (text) => ipcRenderer.invoke('generate-qr', text)
});
