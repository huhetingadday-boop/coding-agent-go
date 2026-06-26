// Coding Agent — Electron shell.
//
// Like Comet, this is a real desktop app: a native Chromium window, not a
// browser tab. The actual install logic lives in the existing Python server
// (server.py), which we run as a SIDECAR child process in serve-only mode
// (CAG_SERVE_ONLY=1, so it never opens its own window/browser). We pick a free
// port, wait for the server to come up, then load it into a BrowserWindow.
// Closing the window kills the sidecar and quits cleanly — no orphan server.

const { app, BrowserWindow, shell } = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const http = require('http');
const net = require('net');

let sidecar = null;
let win = null;

// Ask the OS for an unused localhost port so two launches never collide.
function freePort() {
  return new Promise((resolve, reject) => {
    const s = net.createServer();
    s.unref();
    s.on('error', reject);
    s.listen(0, '127.0.0.1', () => {
      const { port } = s.address();
      s.close(() => resolve(port));
    });
  });
}

// Spawn the Python install server. Packaged: a frozen binary bundled under
// resources/sidecar (no Python needed on the user's machine). Dev: the repo's
// server.py via the system python3.
function startSidecar(port) {
  const env = { ...process.env, CAG_SERVE_ONLY: '1' };
  if (app.isPackaged) {
    const exe = process.platform === 'win32' ? 'server.exe' : 'server';
    const bin = path.join(process.resourcesPath, 'sidecar', exe);
    sidecar = spawn(bin, ['--port', String(port)], { env });
  } else {
    const serverPy = path.join(__dirname, '..', 'server.py');
    const py = process.platform === 'win32' ? 'python' : 'python3';
    sidecar = spawn(py, [serverPy, '--port', String(port)], { env });
  }
  sidecar.stdout.on('data', (d) => process.stdout.write(`[sidecar] ${d}`));
  sidecar.stderr.on('data', (d) => process.stderr.write(`[sidecar] ${d}`));
  sidecar.on('exit', (code) => {
    sidecar = null;
    // If the server dies unexpectedly, there's nothing to show — quit.
    if (win) app.quit();
  });
}

// Poll the local server until it answers, then run cb(). Bounded so a broken
// sidecar surfaces instead of hanging forever.
function waitForServer(port, cb, triesLeft = 80) {
  const ping = () => {
    const req = http.get({ host: '127.0.0.1', port, path: '/', timeout: 1500 }, (res) => {
      res.destroy();
      cb(null);
    });
    req.on('error', () => retry());
    req.on('timeout', () => { req.destroy(); retry(); });
  };
  const retry = () => {
    if (--triesLeft <= 0) cb(new Error('sidecar did not start in time'));
    else setTimeout(ping, 250);
  };
  ping();
}

function createWindow(port) {
  win = new BrowserWindow({
    width: 980,
    height: 760,
    minWidth: 720,
    minHeight: 600,
    title: 'Coding Agent',
    backgroundColor: '#141009', // matches the page so there's no white flash
    show: false,
    webPreferences: { contextIsolation: true, nodeIntegration: false },
  });
  win.loadURL(`http://127.0.0.1:${port}/`);
  win.once('ready-to-show', () => win.show());
  // Provider key pages etc. should open in the user's real browser, not inside
  // the app window.
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:\/\//.test(url)) { shell.openExternal(url); return { action: 'deny' }; }
    return { action: 'deny' };
  });
  win.on('closed', () => { win = null; });
}

app.whenReady().then(async () => {
  const port = await freePort();
  startSidecar(port);
  waitForServer(port, (err) => {
    if (err) console.error(err);
    createWindow(port); // still open the window; it'll show the server's own error if any
  });
});

// Quitting / closing the window must take the sidecar down with it.
function killSidecar() {
  if (sidecar) { try { sidecar.kill(); } catch (e) {} sidecar = null; }
}
app.on('window-all-closed', () => app.quit());
app.on('before-quit', killSidecar);
app.on('quit', killSidecar);
process.on('exit', killSidecar);
