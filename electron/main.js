const {app, BrowserWindow, session, ipcMain} = require('electron');
const path = require('path');
const https = require('https');
const http = require('http');

app.commandLine.appendSwitch('disable-blink-features', 'AutomationControlled');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 400,
    minHeight: 600,
    title: 'FA Nexus',
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
      callback({requestHeaders: details.requestHeaders});
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

async function setCookiesInSession(cookiePairs) {
  const s = session.defaultSession;
  for (const [name, value] of cookiePairs) {
    try {
      await s.cookies.set({
        url: 'https://www.furaffinity.net',
        name,
        value,
        domain: '.furaffinity.net',
        secure: true,
        httpOnly: false,
      });
    } catch (e) {
      console.error('Cookie set error:', name, e.message);
    }
  }
}

ipcMain.handle('open-login-window', async () => {
  const {loginWithBrowser} = require('./browser-login');
  const result = await loginWithBrowser();

  if (result) {
    const pairs = JSON.parse(result.cookies || '[]');
    await setCookiesInSession(pairs);
    return result;
  }

  const loginWindow = new BrowserWindow({
    width: 500,
    height: 780,
    title: 'FA Nexus - Login',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
    },
  });

  return new Promise(resolve => {
    const interval = setInterval(async () => {
      try {
        const cookies = await loginWindow.webContents.session.cookies.get({
          domain: '.furaffinity.net',
        });
        const hasA = cookies.some(c => c.name === 'a');
        const hasB = cookies.some(c => c.name === 'b');

        if (hasA && hasB) {
          clearInterval(interval);

          const allCookies = cookies.map(c => [c.name, c.value]);

          let username = 'unknown';
          try {
            username =
              (await loginWindow.webContents.executeJavaScript(`
                (() => {
                  for (const a of document.querySelectorAll('a[href*="/user/"]')) {
                    const m = a.getAttribute('href').match(/\\/user\\/([^\\/]+)/);
                    if (m && m[1] !== '' && !m[1].includes('login') && !m[1].includes('register')) return m[1];
                  }
                  return 'unknown';
                })()
              `)) || 'unknown';
          } catch {}

          const avatarUrl = `https://a.furaffinity.net/${username}.gif`;

          await setCookiesInSession(allCookies);

          loginWindow.close();
          resolve({
            username,
            avatarUrl,
            isLoggedIn: true,
            cookies: JSON.stringify(allCookies),
          });
        }
      } catch (e) {
        console.error('Cookie check error:', e);
      }
    }, 1000);

    loginWindow.on('closed', () => {
      clearInterval(interval);
      resolve(null);
    });

    loginWindow.loadURL('https://www.furaffinity.net/login/');
  });
});

ipcMain.handle('fa-fetch', async (event, {url, cookieString}) => {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const mod = u.protocol === 'https:' ? https : http;
    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
    };
    if (cookieString) headers['Cookie'] = cookieString;

    const req = mod.get(
      u,
      {headers, rejectUnauthorized: false},
      (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => {
          if (res.statusCode >= 400) {
            resolve({error: `HTTP ${res.statusCode}: ${res.statusMessage || ''}`, statusCode: res.statusCode});
          } else {
            resolve({html: body, statusCode: res.statusCode});
          }
        });
      },
    );
    req.on('error', (e) => resolve({error: e.message}));
    req.setTimeout(15000, () => { req.destroy(); resolve({error: 'Timeout'}); });
  });
});

ipcMain.handle('restore-session-cookies', async (_, cookiesJson) => {
  try {
    const pairs = JSON.parse(cookiesJson || '[]');
    await setCookiesInSession(pairs);
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
