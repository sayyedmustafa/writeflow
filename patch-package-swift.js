const fs = require('fs');
const path = require('path');

function patchSwiftFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  let content = fs.readFileSync(filePath, 'utf8');
  let modified = false;

  // Fix: Swift 6 concurrency requires weak vars in Sendable classes to be marked nonisolated(unsafe)
  if (content.match(/weak\s+(let|var)\s+runtime/)) {
    const updated = content.replace(/(nonisolated\(unsafe\)\s*)?weak\s+(let|var)\s+runtime/g, 'nonisolated(unsafe) weak var runtime');
    if (updated !== content) {
      content = updated;
      modified = true;
    }
  }

  // Fix: Remove trailing comma in tuple parameter types for Swift 6.1
  if (content.includes('consuming JavaScriptValuesBuffer,')) {
    content = content.replace('consuming JavaScriptValuesBuffer,', 'consuming JavaScriptValuesBuffer');
    modified = true;
  }

  if (modified) {
    fs.writeFileSync(filePath, content, 'utf8');
    console.log('Successfully patched Swift file for Swift 6.1 concurrency:', filePath);
  }
}

function patchRuntimeScheduler(filePath) {
  if (!fs.existsSync(filePath)) return;
  let content = fs.readFileSync(filePath, 'utf8');
  if (content.includes('SWIFT_RETURNS_RETAINED')) {
    content = content.replace(/SWIFT_RETURNS_RETAINED\s+/g, '');
    fs.writeFileSync(filePath, content, 'utf8');
    console.log('Successfully patched RuntimeScheduler.h (removed SWIFT_RETURNS_RETAINED):', filePath);
  }
}

function walk(dir) {
  if (!fs.existsSync(dir)) return;
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath);
    } else if (entry.name.endsWith('.swift')) {
      patchSwiftFile(fullPath);
    } else if (entry.name === 'RuntimeScheduler.h') {
      patchRuntimeScheduler(fullPath);
    }
  }
}

console.log('Running patch-package-swift for Xcode 16.4 / Swift 6.1...');
walk(path.join(__dirname, 'node_modules'));
console.log('Patch complete.');
