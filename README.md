# TweakLab

Учебный rootless-твик для iOS 15.x (palera1n / Dopamine, пути `/var/jb`) плюс минимальное
демо-приложение, на котором он отрабатывает. Цель — освоить и отладить три вещи, из которых
состоит почти любой UI-твик:

1. обход иерархии вью и вставка своих элементов в чужой контроллер;
2. подмена текста/цвета существующих `UILabel`/`UIView`;
3. перехват `NSURLSession` и подстановка своего JSON вместо ответа сервера.

Твик отфильтрован по `com.example.tweaklabdemo` (см. `TweakLab.plist`), то есть в сторонние
приложения не грузится вообще.

## Состав

```
tweak-lab/
├── Makefile                    # TARGET iphone:clang:latest:15.0, THEOS_PACKAGE_SCHEME = rootless
├── control                     # Architecture: iphoneos-arm64
├── TweakLab.plist              # Filter -> только демо-бандл
├── Tweak.x                     # сами хуки
├── DemoApp/
│   ├── Makefile                # отдельный Theos-проект: приложение-цель
│   ├── control
│   ├── Info.plist
│   ├── Resources/Info.plist     # копия: разные версии Theos ищут Info.plist в разных местах
│   └── DemoApp.m               # экран + запрос на несуществующий API
└── .github/
    ├── workflows/build.yml     # сборка двух .deb на macOS-раннере
    └── scripts/install-sdk.sh  # установка iOS SDK в Theos
```

## Сборка через GitHub Actions

Готовые пакеты: **<https://github.com/procuroroff/tweak-lab/releases/latest>**.

Собирать локально на Windows нельзя: Theos требует macOS либо Linux с кросс-тулчейном. Сборка
живёт в CI на `ubuntu-latest` — это дешевле и доступнее macOS-раннеров (у macOS-образов бывают
ограничения по аккаунту), а результат тот же: clang из тулчейна + iOS SDK.

### 1. Залить проект в репозиторий

```bash
cd tweak-lab
git init -b main
git add .
git commit -m "TweakLab: учебный твик + демо-приложение"
gh repo create tweak-lab --public --source=. --push
# без gh: git remote add origin git@github.com:<user>/tweak-lab.git && git push -u origin main
```

### 2. Дождаться сборки

Workflow `.github/workflows/build.yml` запускается на `push`, `pull_request`, вручную
(`workflow_dispatch`) и на тег `v*`. Что он делает:

1. клонирует `theos/theos` с сабмодулями в `.theos` и кэширует каталог между запусками;
2. ставит системные зависимости (`build-essential`, `fakeroot`, `perl`, `xz-utils`, ...) и
   `ldid` — в ubuntu-26.04 пакета нет, поэтому бинарник берётся из релиза Procursus;
3. распаковывает кросс-тулчейн `iOSToolchain-x86_64` в `$THEOS/toolchain/` (Theos ищет clang
   именно в `toolchain/linux/iphone/bin`);
4. ставит iOS SDK из `theos/sdks` (sparse-клон, только 15.x/16.x — полный репозиторий весит
   слишком много);
5. собирает твик: `make package FINALPACKAGE=1` -> `packages/com.example.tweaklab_*.deb`;
6. собирает демо-приложение в `DemoApp/` -> `DemoApp/packages/com.example.tweaklabdemo_*.deb`;
7. проверяет, что в `.deb` dylib лежит по пути `/var/jb/...`;
8. складывает оба `.deb` в артефакт `deb-packages`, а на теге ещё и в GitHub Release.

Ручной запуск и выпуск версии:

```bash
gh workflow run build
gh run watch
gh run download --name deb-packages --dir out

git tag -a v0.0.1 -m "v0.0.1" && git push --follow-tags   # соберёт и опубликует Release
```

### 3. Установить на iPhone

В PowerShell на Windows (OpenSSH встроен), устройство и ПК в одной сети:

```powershell
scp .\out\com.example.tweaklab_0.0.1_iphoneos-arm64.deb root@<iphone-ip>:/var/mobile/
scp .\out\com.example.tweaklabdemo_0.0.1_iphoneos-arm64.deb root@<iphone-ip>:/var/mobile/
ssh root@<iphone-ip>
```

Дальше на устройстве:

```bash
dpkg -i /var/mobile/com.example.tweaklabdemo_0.0.1_iphoneos-arm64.deb
dpkg -i /var/mobile/com.example.tweaklab_0.0.1_iphoneos-arm64.deb
uicache -a          # из ellekit/procursus: регистрирует приложение в SpringBoard
killall -9 SpringBoard
```

Если `uicache` нет — `killall SpringBoard` обычно достаточно, приложение появится после
перезапуска SpringBoard.

Проверка, что dylib встал по rootless-пути:

```
/var/jb/Library/MobileSubstrate/DynamicLibraries/TweakLab.dylib
/var/jb/Library/MobileSubstrate/DynamicLibraries/TweakLab.plist
```

Логи — в реальном времени:

```bash
idevicesyslog | grep TweakLab
# или Console.app на Mac, фильтр по subsystem com.example.tweaklab
```

### Если что-то упало

- **`SDK not found` / ошибка на шаге Install iOS SDK** — проверьте имя каталога в
  `theos/sdks` (скрипт берёт `iPhoneOS15.*`, иначе `iPhoneOS16.*`). Лог шага печатает, что
  именно склонировалось.
- **`ldid: command not found`** — brew на раннере иногда обновляется; добавьте
  `brew update --quiet` перед `brew install`.
- **Приложение не появилось после установки** — почти всегда `uicache`; либо
  `.app` лёг не туда, проверьте `dpkg -L com.example.tweaklabdemo`.
- **Демо-приложение собралось, твик — нет** — смотрите лог шага `Build tweak`; чаще всего
  это расхождение сигнатуры метода с SDK.
- **`Application Info.plist not found`** — версия Theos ищет его не там, где ожидалось.
  Поэтому файл лежит и в `DemoApp/Info.plist`, и в `DemoApp/Resources/Info.plist`: сработает
  любой из вариантов, лишний просто не попадёт в бандл.

### Локальная сборка (альтернатива)

На macOS/Linux с уже установленным Theos:

```bash
export THEOS=~/theos
make clean && make package
cd DemoApp && make clean && make package
```

Либо в Docker (образ `theos/theos`, актуальность проверьте сами):

```bash
docker run --rm -it -v "$PWD:/work" -w /work theos/theos make package FINALPACKAGE=1
```

## Что где лежит: техника -> код

| Техника | Где в `Tweak.x` |
| --- | --- |
| Логирование в `os_log` с subsystem | `%ctor`, макрос `TLLOG` |
| Рекурсивный обход вью | `TLDumpView()` |
| Сборка карточки кодом (Auto Layout) | `TLMakeBanner()` |
| Подмена текста по маркеру | `%hook UILabel -setText:` |
| Вставка своего вью в чужой VC | `%hook TLDemoViewController -viewDidLoad` |
| Дамп иерархии после появления экрана | `-viewDidAppear:` |
| Перехват запроса и подмена тела | `%hook NSURLSession -dataTaskWithURL:completionHandler:` |
| Тот же перехват для `NSURLRequest` | `-dataTaskWithRequest:completionHandler:` |

Точки для экспериментов помечены маркерами: `__TL_REPLACE_ME__` в демо-приложении и
`api.example.test/debts` в URL. Меняйте их и смотрите, как ведёт себя хук.

## Как искать классы и методы

Порядок, который экономит больше всего времени:

1. **FLEX** (`FLEXing` / `FLEXLoader` из Cydia/Sileo). Открываете экран приложения, заходите в
   иерархию вью, тапаете нужную плашку — сразу видно класс, фрейм, `text` у `UILabel`, а по
   `responder chain` — контроллер. Это самый быстрый способ получить имена для `%hook`.
2. **class-dump** на компьютере:
   ```bash
   class-dump -H -o headers Payload/App.app/App
   grep -rn "Debt\|Restrict\|Banner" headers/ | head
   ```
   Даёт объявления классов и методов, но не тела.
3. **cycript / frida / objection** на устройстве — уже живой процесс:
   ```bash
   cycript -p App
   UIApp.keyWindow.recursiveDescription().toString()
   ```
   Позволяет не только смотреть, но и вызывать методы: `[#0x14f0a2c00 setText:@"test"]`.
4. **`otool -ov` / `nm -m` / `strings`** по бинарю — когда нужны селекторы и строки, например
   путь эндпоинта или ключи JSON.
5. Если приложение на Swift — `class-dump` почти бесполезен, смотрите `nm` и demangle:
   `nm -m App | xcrun swift-demangle | grep -i debt`. Хуки на Swift-классы работают, но имя
   класса нужно брать с префиксом модуля (`_TtC6Module11SomeClass`).

Дальше цикл такой: нашли класс -> `%hook` -> `os_log` в начале метода -> перезапуск -> смотрите,
вызывается ли вообще -> ужесточаете условие.

## Про jailbreak detection

Если приложение падает или показывает заглушку сразу после инжекта, причины обычно три, и
разбирать их надо по порядку:

1. **Твик вообще не должен грузиться в это приложение.** Часто самое правильное решение —
   ограничить `Filter` своим бандлом, а не бороться с детектом. Если твик нужен только для
   отладки собственного приложения, `TweakLab.plist` уже это делает.
2. **Проверки файловой системы и окружения.** Стандартный набор: `-[NSFileManager fileExistsAtPath:]`
   по путям вроде `/Applications/Cydia.app`, `/var/jb/...`, `fork()`, `ptrace(PT_DENY_ATTACH)`,
   `sysctl` (`KERN_PROC_PID`), `canOpenURL:` со схемами `cydia://`, `sileo://`, `getenv("DYLD_INSERT_LIBRARIES")`.
   Все они перехватываются: ObjC-методы — через `%hook`, C-функции — через `%hookf` либо
   `fishhook`/`ellekit` rebind. Смотреть, что именно проверяется, удобно через Frida:
   `frida-trace -U -f com.example.app -m "-[NSFileManager fileExistsAtPath:]"`.
3. **Проверки целостности самого бинаря** (хеш `__TEXT`, наличие `LC_LOAD_DYLIB`, `csops`).
   Это уже тяжелее: иногда проще пропатчить саму проверку в бинаре, чем обходить её из твика.

Практический приём: сначала соберите твик, который **ничего не делает**, кроме `%ctor` с
`os_log`. Если приложение с ним не падает — дело не в инжекте, а в ваших хуках. Если падает —
детект срабатывает на факт загрузки dylib, и дальше ищется конкретная проверка.

## Ограничения

Код писался как референс: здесь нет iOS-SDK и Theos, поэтому `make` не запускался. Перед
сборкой проверьте имена классов демо-приложения и, при необходимости, сигнатуры методов под
свой SDK. В `%hook NSURLSession` возврат `nil` из `dataTaskWith...` — учебное упрощение: задача
не создаётся, потому что данные уже отданы в `completionHandler`. В реальном твике лучше
возвращать заглушку-задачу или хукать `-resume`.
