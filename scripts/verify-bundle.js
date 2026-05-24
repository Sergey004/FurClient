const fs = require('fs');
const path = require('path');

const bundlePath = path.resolve(__dirname, '..', 'electron', 'bundle.js');
const webBuildPath = path.resolve(__dirname, '..', 'web-build', 'bundle.js');

let bundle;
if (fs.existsSync(bundlePath)) {
  bundle = fs.readFileSync(bundlePath, 'utf8');
} else if (fs.existsSync(webBuildPath)) {
  console.log('electron/bundle.js not found, checking web-build/bundle.js...');
  bundle = fs.readFileSync(webBuildPath, 'utf8');
} else {
  console.error('ERROR: No bundle.js found at electron/bundle.js or web-build/bundle.js');
  console.error('Run "npm run web:build" first.');
  process.exit(1);
}

const checks = [
  { name: 'NavigationContainer', pattern: /NavigationContainer/g },
  { name: 'TabNavigator', pattern: /tabBarLabel|tabBarStyle|tabBarActiveTintColor/g },
  { name: 'HeaderConfig', pattern: /headerShown|headerTitle|headerBack/g },
  { name: 'AppScreens', pattern: /"Gallery"|"Search"|"Alerts"|"Settings"/g },
  { name: 'TabRouter', pattern: /backBehavior|JUMP_TO|preloadedRouteKeys/g },
];

let allPassed = true;
for (const check of checks) {
  const count = (bundle.match(check.pattern) || []).length;
  const status = count > 0 ? 'PASS' : 'FAIL';
  if (status === 'FAIL') allPassed = false;
  console.log(`  [${status}] ${check.name}: ${count} matches`);
}

if (allPassed) {
  console.log('\nBundle verification PASSED - all navigation modules present.');
  process.exit(0);
} else {
  console.log('\nBundle verification FAILED - some navigation modules missing!');
  console.log('Try rebuilding: npm run web:build && npm run electron:copy-bundle');
  process.exit(1);
}
