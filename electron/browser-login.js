const CDP = require('chrome-remote-interface');
const {launch} = require('chrome-launcher');
const path = require('path');
const os = require('os');
const fs = require('fs');

const LOGIN_URL = 'https://www.furaffinity.net/login/';
const CHECK_INTERVAL = 1500;
const LOGIN_TIMEOUT = 300000;

async function loginWithBrowser() {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fanexus-'));

  const launcher = await launch({
    chromeFlags: [
      LOGIN_URL,
      '--app=' + LOGIN_URL,
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-extensions',
      '--disable-sync',
      '--disable-translate',
      '--disable-background-networking',
      '--disable-default-apps',
      '--disable-prompt-on-repost',
      '--user-data-dir=' + tempDir,
    ],
    port: 0,
    ignoreDefaultFlags: true,
  }).catch(() => null);

  if (!launcher) {
    return null;
  }

  return new Promise(resolve => {
    let resolved = false;
    let clientRef = null;
    let intervalRef = null;

    const cleanup = () => {
      if (intervalRef) clearInterval(intervalRef);
      try { if (clientRef) clientRef.close(); } catch {}
      try { launcher.kill(); } catch {}
      try { fs.rmSync(tempDir, {recursive: true, force: true}); } catch {}
    };

    const connect = async () => {
      try {
        const client = await CDP({port: launcher.port});
        clientRef = client;
        const {Network, Runtime} = client;

        await Network.enable();

        intervalRef = setInterval(async () => {
          try {
            const urlResult = await Runtime.evaluate({
              expression: 'window.location.href',
              returnByValue: true,
            });
            const url = (urlResult.result || {}).value || '';

            if (url.includes('/login/') || !url.includes('furaffinity.net')) return;

            const cookieData = await Network.getAllCookies();
            const faCookies = (cookieData.cookies || [])
              .filter(c => c.domain.includes('furaffinity.net') || c.domain.includes('fa'))
              .map(c => [c.name, c.value]);

            const hasA = faCookies.some(c => c[0] === 'a');
            const hasB = faCookies.some(c => c[0] === 'b');
            if (!hasA || !hasB) return;

            resolved = true;
            clearInterval(intervalRef);

            let username = 'unknown';
            try {
              const nameResult = await Runtime.evaluate({
                expression: `(() => {
                  for (const a of document.querySelectorAll('a[href*="/user/"]')) {
                    const m = a.getAttribute('href').match(/\\/user\\/([^\\/]+)/);
                    if (m && m[1] && !m[1].includes('login') && !m[1].includes('register') && !m[1].includes('signup')) return m[1];
                  }
                  return 'unknown';
                })()`,
                returnByValue: true,
              });
              username = (nameResult.result || {}).value || 'unknown';
            } catch {}

            cleanup();
            resolve({
              username,
              avatarUrl: 'https://a.furaffinity.net/' + username + '.gif',
              isLoggedIn: true,
              cookies: JSON.stringify(faCookies),
            });
          } catch {}
        }, CHECK_INTERVAL);

        client.on('disconnect', () => {
          if (!resolved) {
            cleanup();
            resolve(null);
          }
        });
      } catch (err) {
        if (!resolved) {
          cleanup();
          resolve(null);
        }
      }
    };

    connect();

    setTimeout(() => {
      if (!resolved) {
        cleanup();
        resolve(null);
      }
    }, LOGIN_TIMEOUT);
  });
}

module.exports = {loginWithBrowser};
