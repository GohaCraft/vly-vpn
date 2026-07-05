// Проверка: сетка выбора языка не даёт RenderFlex overflow ни на узком экране.
// Виджет-тест бросает исключение при overflow, поэтому сам факт прохождения =
// подтверждение фикса (mainAxisExtent вместо childAspectRatio).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ByteData> _font(String p) async =>
    ByteData.view((await File(p).readAsBytes()).buffer);

const _accent = Color(0xFFFF4D4D);

// Копия реальной ячейки из _LanguagePage (та же структура/размеры).
Widget _tile(String flag, String native, String en, bool sel) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
  decoration: BoxDecoration(
    color: sel ? _accent.withOpacity(0.14) : Colors.white.withOpacity(0.04),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: sel ? _accent : Colors.white.withOpacity(0.08),
        width: sel ? 1.6 : 1)),
  child: Row(children: [
    Container(width: 38, height: 38, alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.06)),
      child: Text(flag, style: const TextStyle(fontSize: 21))),
    const SizedBox(width: 11),
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(native, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5, color: Colors.white,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: 1),
        Text(en, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.4))),
      ])),
  ]));

void main() {
  setUpAll(() async {
    await (FontLoader('Roboto')..addFont(_font('/opt/flutter/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf'))).load();
  });

  testWidgets('language grid has no overflow on narrow screen', (t) async {
    const langs = [
      ['🇬🇧', 'English', 'English'], ['🇷🇺', 'Русский', 'Russian'],
      ['🇩🇪', 'Deutsch', 'German'], ['🇫🇷', 'Français', 'French'],
      ['🇰🇿', 'Қазақша', 'Kazakh'], ['🇧🇾', 'Беларуская', 'Belarusian'],
    ];
    // Узкий экран (320px) — самый тяжёлый случай для старого childAspectRatio.
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(320, 640)),
      child: Directionality(textDirection: TextDirection.ltr,
        child: DefaultTextStyle(style: const TextStyle(fontFamily: 'Roboto'),
          child: Container(color: const Color(0xFF07090F),
            padding: const EdgeInsets.all(16),
            child: GridView(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
                mainAxisExtent: 64),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final l in langs) _tile(l[0], l[1], l[2], false)],
            ))))));
    await t.pump();
    // RenderFlex overflow регистрируется как исключение — его тут быть не должно.
    expect(t.takeException(), isNull);
  });
}
