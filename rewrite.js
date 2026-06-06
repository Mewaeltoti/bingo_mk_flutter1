const fs = require('fs');

const content = fs.readFileSync('lib/core/l10n/app_strings.dart', 'utf-8');
const lines = content.split('\n');

const newLines = [];
let inserted = false;

for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    if (!inserted && line.includes('abstract class S {')) {
        newLines.push(line);
        newLines.push('  static bool isAmharic = true;');
        newLines.push('');
        inserted = true;
        continue;
    }

    if (line.includes('static const') && line.includes('//')) {
        const match = line.match(/static const\s+(\w+)\s*=\s*'([^']+)';\s*\/\/\s*(.*)/);
        if (match) {
            const name = match[1];
            const amh = match[2];
            let eng = match[3].trim();
            eng = eng.replace(/'/g, "\\'");
            newLines.push(`  static String get ${name} => isAmharic ? '${amh}' : '${eng}';`);
            continue;
        }
    }
    newLines.push(line);
}

fs.writeFileSync('lib/core/l10n/app_strings.dart', newLines.join('\n'), 'utf-8');
