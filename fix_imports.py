#!/usr/bin/env python3
"""
Запусти в корне проекта:
  cd C:\\vpn\\aura_temp
  python fix_imports.py
  
Добавит flutter_svg import в main.dart
"""
import re, os

# 1. Fix main.dart - add flutter_svg import
path = 'lib/main.dart'
if os.path.exists(path):
    content = open(path, encoding='utf-8').read()
    
    if 'flutter_svg' not in content:
        content = content.replace(
            "import 'package:flutter/material.dart';",
            "import 'package:flutter/material.dart';\nimport 'package:flutter_svg/flutter_svg.dart';"
        )
        open(path, 'w', encoding='utf-8').write(content)
        print(f"OK main.dart: flutter_svg import added")
    else:
        print(f"  main.dart: flutter_svg already present")
else:
    print(f"X main.dart not found")

print("\nDone! Now: git add . && git commit -m \"fix imports\" && git push")
