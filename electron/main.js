const {app, BrowserWindow, session, ipcMain} = require('electron');
const path = require('path');

app.commandLine.appendSwitch('disable-blink-features', 'AutomationControlled');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 400,
    minHeight: 600,
    title: 'FurClient',
    backgroundColor: '#090909',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      webSecurity: false,
      preload: path.join(__dirname, 'preload.js'),
    },
  });

  mainWindow.webContents.session.webRequest.onBeforeSendHeaders(
    {urls: ['https://www.furaffinity.net/*', 'https://a.furaffinity.net/*', 'https://t.furaffinity.net/*']},
    (details, callback) => {
      const headers = {...details.requestHeaders, 'User-Agent': ['ceylo.FurAffinityApp/1.0']}; // TEMP: borrowed UA, replace with FurClient/1.0 if FA approves
      callback({requestHeaders: headers});
    },
  );

  mainWindow.webContents.session.webRequest.onHeadersReceived(
    {urls: ['https://www.furaffinity.net/*', 'https://a.furaffinity.net/*', 'https://t.furaffinity.net/*']},
    (details, callback) => {
      const headers = {
        ...details.responseHeaders,
        'Access-Control-Allow-Origin': ['*'],
        'Access-Control-Allow-Credentials': ['true'],
      };
      callback({responseHeaders: headers});
    },
  );

  const isDev = process.env.NODE_ENV === 'development';

  if (isDev) {
    mainWindow.loadURL('http://localhost:5173');
    mainWindow.webContents.openDevTools({mode: 'detach'});
  } else {
    mainWindow.loadFile(path.join(__dirname, 'index.html'));
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

ipcMain.handle('open-login-window', () => {
  return new Promise(resolve => {
    let resolved = false;

    const loginWindow = new BrowserWindow({
      width: 460,
      height: 780,
      title: 'FurClient — Sign In',
      backgroundColor: '#090909',
      autoHideMenuBar: true,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true,
      },
    });

    loginWindow.webContents.setUserAgent('ceylo.FurAffinityApp/1.0');

    const tryCapture = async (url) => {
      if (resolved) return;

      let parsed;
      try { parsed = new URL(url); } catch { return; }

      const p = parsed.pathname;
      const isHome = /^\/?(\?.*)?$/.test(p);
      const isUserPage = /^\/user\//.test(p);
      if (!isHome && !isUserPage) return;

      const cookies = await loginWindow.webContents.session.cookies.get({
        domain: '.furaffinity.net',
      });
      if (!cookies.some(c => c.name === 'a')) return;

      resolved = true;

      for (const c of cookies) {
        try {
          await session.defaultSession.cookies.set({
            url: 'https://www.furaffinity.net',
            name: c.name,
            value: c.value,
            domain: '.furaffinity.net',
            path: '/',
            secure: true,
            httpOnly: !!c.httpOnly,
            sameSite: 'no_restriction',
          });
        } catch (e) {
          console.error('[auth] cookie copy error:', c.name, e.message);
        }
      }

      let username = 'unknown';
      try {
        username = await loginWindow.webContents.executeJavaScript(`
          (() => {
            for (const a of document.querySelectorAll('a[href*="/user/"]')) {
              const m = a.getAttribute('href').match(/\\/user\\/([^\\/]+)/);
              if (m && m[1] && !['login','register','logout'].includes(m[1])) {
                return m[1];
              }
            }
            return 'unknown';
          })()
        `);
      } catch {}

      loginWindow.close();
      resolve({
        username,
        avatarUrl: `https://a.furaffinity.net/${username}.gif`,
        isLoggedIn: true,
        cookies: JSON.stringify(cookies.map(c => [c.name, c.value])),
      });
    };

    loginWindow.webContents.on('did-navigate', (_, url) => tryCapture(url));
    loginWindow.webContents.on('did-navigate-in-page', (_, url) => tryCapture(url));

    loginWindow.on('closed', () => {
      if (!resolved) resolve(null);
    });

    loginWindow.loadURL('https://www.furaffinity.net/login/');
  });
});

ipcMain.handle('restore-session-cookies', async (_, cookiesJson) => {
  try {
    const pairs = JSON.parse(cookiesJson || '[]');
    for (const [name, value] of pairs) {
      await session.defaultSession.cookies.set({
        url: 'https://www.furaffinity.net',
        name,
        value,
        domain: '.furaffinity.net',
        path: '/',
        secure: true,
        httpOnly: true,
        sameSite: 'no_restriction',
      });
    }
    return true;
  } catch {
    return false;
  }
});

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (mainWindow === null) {
    createWindow();
  }
});
