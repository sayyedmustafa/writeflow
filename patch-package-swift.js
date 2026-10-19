const fs = require('fs');
const path = require('path');

function patchFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  let content = fs.readFileSync(filePath, 'utf8');
  content = content.replace(/\/\/\s*swift-tools-version:\s*6\.2/g, '// swift-tools-version: 6.0');
  // Remove trailing commas before closing parentheses and brackets
  content = content.replace(/,(\s*[\)\]])/g, '$1');
  fs.writeFileSync(filePath, content, 'utf8');
  console.log('Successfully patched Package.swift:', filePath);
}

function walk(dir) {
  if (!fs.existsSync(dir)) return;
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath);
    } else if (entry.name === 'Package.swift') {
      patchFile(fullPath);
    }
  }
}

walk(path.join(__dirname, 'node_modules'));
