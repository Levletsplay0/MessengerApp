# Messenger App 📱

Кроссплатформенное мобильное приложение-мессенджер, разработанное на Flutter. Является фронтендом для [Messenger Backend](https://github.com/Levletsplay0/Messenger).

> ⚠️ **Внимание**: Приложение находится в активной разработке и еще не покрывает все эндпоинты бэкенда. Некоторые функции могут быть недоступны или работать некорректно.

## 📸 Скриншоты

![Login Screen](screenshots/login_screen.png)

![Register Screen](screenshots/register_screen.png)

![Chats List](screenshots/chats_list.png)

![Splash Screen](screenshots/profile_screen.png)

## 🌟 Возможности

### ✅ Реализовано
- 🔐 **Аутентификация**
  - Регистрация нового пользователя (имя, фамилия, email, username, пароль)
  - Вход в систему с сохранением токена
  - Splash screen с проверкой авторизации
  
- 👤 **Профиль пользователя**
  - Просмотр информации профиля (имя, email, username, описание)
  - Загрузка и изменение аватара
  - Удаление аватара
  - Редактирование описания профиля (до 100 символов)
  
- 💬 **Чаты**
  - Отображение списка групп/чатов
  - Показ аватаров чатов (или генерация цветных заглушек)
  - Отображение названия и описания чата
  
- ⚙️ **Настройки**
  - Базовый экран настроек (заготовка)
  - Переключатель уведомлений
  - Выбор темы и языка (UI-заготовки)
  
- 🎨 **Интерфейс**
  - Поддержка светлой и темной темы (системная)
  - Нижняя навигационная панель
  - Адаптивный дизайн
  - Индикаторы загрузки и обработки ошибок

## 🛠 Технологии

- **Flutter** - кроссплатформенный фреймворк
- **Dart** - язык программирования
- **HTTP** - работа с REST API
- **SharedPreferences** - локальное хранение данных (токен авторизации)
- **File Picker** - выбор файлов для загрузки аватара

## 📦 Зависимости

```yaml
dependencies:
  flutter: sdk: flutter
  http: ^1.6.0
  cupertino_icons: ^1.0.8
  shared_preferences: ^2.5.5
  file_picker: ^10.3.8

dev_dependencies:
  flutter_test: sdk: flutter
  flutter_lints: ^6.0.0
```

## 🏗 Структура проекта

```
lib/
├── main.dart                    # Точка входа, SplashScreen
├── screens/
│   ├── login_screen.dart        # Экран входа
│   ├── register_screen.dart     # Экран регистрации
│   ├── chats_screen.dart        # Главный экран с навигацией
│   ├── chats_page.dart          # Список чатов/групп
│   ├── profile_page.dart        # Профиль пользователя
│   ├── settings_page.dart       # Настройки
│   └── edit_description_page.dart # Редактирование описания
├── services/
│   └── api_service.dart         # Сервис для работы с API
└── theme/
    └── app_theme.dart           # Темы приложения
```

## 🚀 Установка и запуск

### Предварительные требования
- Flutter SDK (последняя стабильная версия)
- Dart SDK
- Android Studio / Xcode (для эмуляторов)
- Доступ к бэкенду: `http://45.132.255.102:8000`

### Шаги установки

1. Клонируйте репозиторий:
```bash
git clone https://github.com/Levletsplay0/MessengerApp.git
cd MessengerApp
```

2. Установите зависимости:
```bash
flutter pub get
```

3. Запустите приложение:
```bash
flutter run
```

Для запуска на конкретном устройстве:
```bash
flutter run -d <device_id>
```

Список доступных устройств:
```bash
flutter devices
```

## 📡 API Endpoints

Приложение взаимодействует со следующими эндпоинтами бэкенда:

| Метод | Endpoint | Описание | Статус |
|-------|----------|----------|--------|
| GET | `/` | Проверка сервера | ✅ |
| POST | `/login` | Авторизация | ✅ |
| POST | `/register` | Регистрация | ✅ |
| GET | `/groups` | Получение списка групп | ✅ |
| GET | `/users/me` | Получение данных профиля | ✅ |
| DELETE | `/users/me/avatar` | Удаление аватара | ✅ |
| POST | `/users/me/avatar` | Загрузка аватара | ✅ |
| PATCH | `/users/me/description` | Обновление описания | ✅ |

> ⚠️ **Примечание**: Не все эндпоинты бэкенда реализованы во фронтенде. Работа над интеграцией продолжается.


## 🗺 Roadmap

### В разработке
- [ ] Отправка и получение сообщений
- [ ] Создание новых чатов/групп
- [ ] Поиск пользователей
- [ ] Уведомления в реальном времени
- [ ] Голосовые и видеозвонки
- [ ] Полная реализация экрана настроек
- [ ] Offline режим
- [ ] Кэширование сообщений

## 🤝 Contributing

Проект находится в ранней стадии разработки. Если вы хотите помочь:

1. Форкните репозиторий
2. Создайте ветку для вашей фичи (`git checkout -b feature/AmazingFeature`)
3. Закоммитьте изменения (`git commit -m 'Add some AmazingFeature'`)
4. Запушьте в ветку (`git push origin feature/AmazingFeature`)
5. Откройте Pull Request


## 👨‍💻 Автор

**Levletsplay0** - [GitHub Profile](https://github.com/Levletsplay0)

## 🔗 Ссылки

- [Backend Repository](https://github.com/Levletsplay0/Messenger)
- [Документация Flutter](https://flutter.dev/docs)
- [Learn Flutter](https://flutter.dev/learn)

---

**Статус проекта**: 🚧 В активной разработке
