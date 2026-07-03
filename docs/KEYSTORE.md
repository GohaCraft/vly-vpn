# Ключ подписи Android — статус и ротация

## ⚠️ Статус: старый ключ СКОМПРОМЕТИРОВАН

Ранее в истории git (коммит `15af2de`) были закоммичены `android/app/vly.keystore`
и пароль `vlyvpn2026` (в `build.gradle.kts`). Репозиторий публичный → **считать этот
ключ и пароль мёртвыми.** Переписывание истории задним числом их НЕ развидит (уже
могли быть склонированы/проиндексированы).

Текущее состояние (проверено):
- keystore **не отслеживается** git и в `.gitignore`;
- `build.gradle.kts` читает подпись из `key.properties` / CI-секретов, пароля в
  коде нет.

## ✅ Реальный фикс = РОТАЦИЯ (обязательно перед релизом)

Старый ключ ещё **не подписывал** опубликованное приложение (релиза не было),
поэтому ротация сейчас безболезненна и закрывает утечку.

### 1. Сгенерировать НОВЫЙ прод-keystore (никогда не коммитить)
```bash
keytool -genkeypair -v \
  -keystore vly-release.jks -alias vly \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -storetype PKCS12
# Задать НОВЫЕ сильные пароли (store и key). Сохранить keystore и пароли
# в надёжном менеджере паролей — при утере ключа обновление приложения в
# сторе станет невозможным.
```

### 2. Локальная сборка: `android/key.properties` (в .gitignore)
```properties
storeFile=/абсолютный/путь/vly-release.jks
storePassword=НОВЫЙ_ПАРОЛЬ_ХРАНИЛИЩА
keyAlias=vly
keyPassword=НОВЫЙ_ПАРОЛЬ_КЛЮЧА
```

### 3. CI: секреты GitHub (workflow уже умеет их читать)
```bash
base64 -w0 vly-release.jks   # → значение секрета KEYSTORE_BASE64
```
Secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
Workflow (`.github/workflows/build.yml`) сам соберёт из них `key.properties`.

## Опционально: вычистить старый ключ из истории git

Это **косметика** (ключ всё равно ротируется и считается мёртвым), но если хочешь
убрать его из истории перед тем как делать репо более публичным — делай **осознанно**
(перепишет коммиты и потребует force-push):
```bash
pip install git-filter-repo
git filter-repo --force \
  --path android/app/vly.keystore --invert-paths \
  --replace-text <(echo 'vlyvpn2026==>REDACTED')
git push --force-with-lease origin claude/vpn-service-review-anad2r
```
⚠️ Перепишет SHA коммитов ветки и повлияет на PR. Форки/клоны сохранят старую
историю. Поэтому: **ротация ключа обязательна в любом случае**, а чистка истории —
по желанию.
