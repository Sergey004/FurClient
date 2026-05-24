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

ipcMain.handle('open-login-window', async () => {
  const {loginWithBrowser} = require('./browser-login');
  const result = await loginWithBrowser();

  if (result) return result;

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
