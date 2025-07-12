# Быстрая установка ABAP Package Explorer

## Шаг 1: Создание программ в SE80

### Базовая версия
1. SE80 → Create → Program → `ZPP_PACKAGE_EXPLORER`
2. Скопируйте код из `ZPP_PACKAGE_EXPLORER.abap`
3. Сохраните и активируйте

### Расширенная версия
1. SE80 → Create → Program → `ZPP_PACKAGE_EXPLORER_ADVANCED`
2. Скопируйте код из `ZPP_PACKAGE_EXPLORER_ADVANCED.abap`
3. Сохраните и активируйте

## Шаг 2: Создание Include
1. SE80 → Create → Include → `ZPP_PACKAGE_EXPLORER_DESCRIPTIONS`
2. Скопируйте код из `ZPP_PACKAGE_EXPLORER_DESCRIPTIONS.abap`
3. Сохраните и активируйте

## Шаг 3: Создание экранов

### Экран 9000 (базовая версия)
```
1. В SE80 в программе ZPP_PACKAGE_EXPLORER
2. Правый клик → Create → Screen → 9000
3. Добавьте Custom Container:
   - Name: CONTAINER
   - Resizing: Both
   - Position: (1,1) Size: (131,26)
4. Flow Logic:
   PROCESS BEFORE OUTPUT.
     MODULE status_9000.
     MODULE create_container.
   
   PROCESS AFTER INPUT.
     MODULE user_command_9000.
```

### Экран 9001 (расширенная версия)
```
1. В SE80 в программе ZPP_PACKAGE_EXPLORER_ADVANCED
2. Правый клик → Create → Screen → 9001
3. Добавьте Custom Containers:
   - CONTAINER (основной) - Position: (1,1) Size: (131,26)
   - TOOLBAR (тулбар) - Position: (1,1) Size: (131,3)
   - SEARCH (поиск) - Position: (1,4) Size: (131,2)
4. Flow Logic:
   PROCESS BEFORE OUTPUT.
     MODULE status_9001.
     MODULE create_containers.
   
   PROCESS AFTER INPUT.
     MODULE user_command_9001.
```

## Шаг 4: GUI Status и Title

### GUI Status
```
1. В SE80 в программе → Правый клик → Create → GUI Status
2. Создайте MAIN для базовой версии
3. Создайте MAIN_ADVANCED для расширенной версии
4. Добавьте Function Keys:
   - F3 = BACK
   - F12 = CANC
   - F15 = EXIT
   - F5 = REFRESH (для расширенной версии)
```

### Title
```
1. В SE80 в программе → Правый клик → Create → GUI Title
2. Создайте TITLE: "Исследователь пакетов разработки"
3. Создайте TITLE_ADVANCED: "Расширенный исследователь пакетов"
```

## Шаг 5: Текстовые элементы

```
1. В SE80 в программе → Goto → Text Elements → Text Symbols
2. Добавьте:
   - TEXT-001: Параметры выбора
   - TEXT-002: Фильтр по типам объектов
   - TEXT-003: Поиск объектов
```

## Быстрый тест

1. Запустите программу: SE38 → `ZPP_PACKAGE_EXPLORER` → F8
2. Введите пакет разработки (например, `BASIS`)
3. Нажмите F8
4. Проверьте отображение дерева объектов
5. Двойной клик по объекту для редактирования

## Возможные ошибки

### "Include не найден"
- Убедитесь, что создали include `ZPP_PACKAGE_EXPLORER_DESCRIPTIONS`
- Проверьте правильность имени include в программе

### "Экран не найден"
- Проверьте создание экрана 9000/9001
- Убедитесь в правильности flow logic

### "GUI Status не найден"
- Создайте GUI Status согласно инструкции
- Проверьте имена status в коде программы

### "Пакет не найден"
- Введите существующий пакет разработки
- Проверьте права доступа к таблице TDEVC

## Минимальные права доступа

```
- Таблицы: TADIR, TDEVC, TRDIRT, SEOCLASS, TLIBG
- Транзакции: SE80, SE11, SE93 (для редактирования)
- Функции: RS_EU_CROSSREF (для анализа использования)
```

## Готово!

После выполнения всех шагов программа готова к использованию. Для детальной информации см. `README.md`.