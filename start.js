#!/usr/bin/env node

/**
 * FA Nexus - Cross-Platform Start Script
 * Works on Windows, macOS, and Linux
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const isWindows = os.platform() === 'win32';
const isMac = os.platform() === 'darwin';
const isLinux = os.platform() === 'linux';

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
  gray: '\x1b[90m',
};

const log = (message, color = colors.reset) => {
  console.log(`${color}${message}${colors.reset}`);
};

const run = (command, options = {}) => {
  try {
    execSync(command, {
      stdio: 'inherit',
      shell: true,
      ...options,
    });
    return true;
  } catch (error) {
    return false;
  }
};

// Main script
(async () => {
  log('\n🚀 FA Nexus - Fur Affinity Client', colors.green);
  log('==================================', colors.green);
  
  const platform = isWindows ? 'Windows' : isMac ? 'macOS' : 'Linux';
  const arch = process.arch;
  const nodeVersion = process.version;
  
  log(`Platform: ${platform} (${arch})`, colors.cyan);
  log(`Node.js:  ${nodeVersion}`, colors.cyan);
  log('');

  // Step 1: Install dependencies if needed
  if (!fs.existsSync(path.join(__dirname, 'node_modules'))) {
    log('📦 Installing dependencies...', colors.yellow);
    if (!run('npm install')) {
      log('❌ Failed to install dependencies', colors.red);
      process.exit(1);
    }
    log('');
  }

  // Step 2: Create .env if it doesn't exist
  if (!fs.existsSync(path.join(__dirname, '.env'))) {
    log('⚙️  Creating .env file...', colors.yellow);
    const envContent = `PORT=3001
CLIENT_URL=http://localhost:3000
NODE_ENV=development
REACT_APP_API_URL=http://localhost:3001/api
`;
    fs.writeFileSync(path.join(__dirname, '.env'), envContent);
    log('✅ .env file created', colors.green);
    log('');
  }

  // Step 3: Create .env.local template if it doesn't exist
  if (!fs.existsSync(path.join(__dirname, '.env.local'))) {
    const envLocalTemplate = `# Local environment overrides
# Copy and uncomment to customize for your machine

# PORT=3001
# CLIENT_URL=http://localhost:3000
# NODE_ENV=development
# REACT_APP_API_URL=http://localhost:3001/api
`;
    fs.writeFileSync(path.join(__dirname, '.env.local.example'), envLocalTemplate);
  }

  // Step 4: TypeScript check
  log('🔍 Running TypeScript check...', colors.yellow);
  if (!run('npm run lint')) {
    log('❌ TypeScript errors found!', colors.red);
    process.exit(1);
  }
  log('✅ TypeScript OK', colors.green);
  log('');

  // Step 5: Start dev servers
  log('🟢 Starting dev servers...', colors.green);
  log('   Frontend: http://localhost:3000', colors.cyan);
  log('   Backend:  http://localhost:3001/api', colors.cyan);
  log('');
  log('Press Ctrl+C to stop', colors.gray);
  log('');

  // Run dev server
  run('npm run dev');
})();
