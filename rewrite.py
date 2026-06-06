import re

with open('lib/core/l10n/app_strings.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'static const' in line and '//' in line:
        match = re.search(r"static const\s+(\w+)\s*=\s*'([^']+)';\s*//\s*(.*)", line)
        if match:
            name = match.group(1)
            amh = match.group(2)
            eng = match.group(3).strip()
            # Handle cases where the english translation is just descriptive and not an exact translation,
            # or where we need to escape quotes.
            eng = eng.replace("'", "\\'")
            new_lines.append(f"  static String get {name} => isAmharic ? '{amh}' : '{eng}';\n")
            continue
    new_lines.append(line)

new_lines.insert(6, "  static bool isAmharic = true;\n\n")

with open('lib/core/l10n/app_strings.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
