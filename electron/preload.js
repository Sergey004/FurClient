const {contextBridge, ipcRenderer} = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  openLoginWindow: () => ipcRenderer.invoke('open-login-window'),
  restoreSessionCookies: (cookies) => ipcRenderer.invoke('restore-session-cookies', cookies),
  faFetch: (url, cookieString) => ipcRenderer.invoke('fa-fetch', {url, cookieString}),
});
