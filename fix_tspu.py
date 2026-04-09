#!/usr/bin/env python3
"""
Запусти в корне проекта:
  cd C:\vpn\aura_temp
  python fix_tspu.py
"""
import os

def remove_class_from_file(path, class_names):
    if not os.path.exists(path):
        print(f"✗ {path} not found")
        return
    
    content = open(path, encoding='utf-8').read()
    lines   = content.splitlines()
    removed = []
    
    for cls in class_names:
        if f'class {cls}' not in content:
            continue
        
        result = []
        in_cls = False
        depth  = 0
        
        for i, l in enumerate(lines):
            if f'class {cls}' in l and not in_cls:
                in_cls = True
                depth  = 0
                # Remove preceding comment block
                while result and result[-1].strip().startswith('//'):
                    result.pop()
                while result and result[-1].strip() == '':
                    result.pop()
            
            if in_cls:
                depth += l.count('{') - l.count('}')
                if depth <= 0 and i > 0:
                    in_cls = False
                continue
            
            result.append(l)
        
        lines   = result
        content = '\n'.join(lines)
        removed.append(cls)
    
    if removed:
        open(path, 'w', encoding='utf-8').write(content)
        print(f"✓ {path}: removed {removed}")
    else:
        print(f"  {path}: nothing to remove")

CLASSES = ['WhitelistBypassEngine', 'TspuBypassWindowDetector']

# Remove from tspu_2026.dart (keep in ai_bypass.dart)
remove_class_from_file('lib/tspu_2026.dart', CLASSES)

# Also clean networking.dart just in case
remove_class_from_file('lib/networking.dart', CLASSES)

print('\nDone! Now run: git add . && git commit -m "fix: remove duplicate classes" && git push')
