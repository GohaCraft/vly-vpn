#!/usr/bin/env python3
"""
Запусти в корне проекта ПОСЛЕ fix_all_warnings.py:
  cd C:\\vpn\\aura_temp
  python fix_duplicates.py
"""
import re, os

def remove_class(content, class_name):
    """Remove a class definition from dart content"""
    pattern = rf'\n// [^\n]*\nclass {class_name}[\s\S]*?^}}'
    # Try to find and remove the class
    lines = content.splitlines()
    in_class = False
    depth = 0
    start_idx = None
    result_lines = []
    i = 0
    while i < len(lines):
        l = lines[i]
        if f'class {class_name}' in l and not in_class:
            in_class = True
            depth = 0
            start_idx = i
            # Also remove preceding comment lines
            while result_lines and result_lines[-1].strip().startswith('//'):
                result_lines.pop()
        if in_class:
            depth += l.count('{') - l.count('}')
            if depth <= 0 and start_idx is not None and i > start_idx:
                in_class = False
                start_idx = None
                depth = 0
        else:
            result_lines.append(l)
        i += 1
    return '\n'.join(result_lines)

# Fix networking.dart - remove duplicate classes
net_path = 'lib/networking.dart'
if os.path.exists(net_path):
    content = open(net_path, encoding='utf-8').read()
    original_len = len(content)
    
    for cls in ['WhitelistBypassEngine', 'TspuBypassWindowDetector']:
        if f'class {cls}' in content:
            content = remove_class(content, cls)
            print(f'✓ Removed {cls} from networking.dart')
    
    if len(content) != original_len:
        open(net_path, 'w', encoding='utf-8').write(content)
        print(f'✓ networking.dart saved ({len(content.splitlines())} lines)')
    else:
        print(f'  networking.dart: no duplicates found')

print('\nDone!')
