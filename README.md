# MCP Java Client Example

Пример Java приложения для работы с **Model Context Protocol (MCP)** - протоколом для обмена контекстом между моделями ИИ и внешними системами.

## Описание

Этот проект демонстрирует:
- Подключение к MCP серверу через WebSocket
- Отправку запросов и получение ответов
- Обработку уведомлений от сервера
- Работу с ресурсами, инструментами и промптами
- Интерактивный режим для тестирования

## Архитектура

### Компоненты

- **`MCPClient`** - WebSocket клиент для низкоуровневого общения с MCP сервером
- **`MCPService`** - Высокоуровневый сервис для работы с MCP операциями
- **`MCPMessage`** - Базовый класс для всех MCP сообщений
- **`MCPRequest`** - Класс для запросов к серверу
- **`MCPResponse`** - Класс для ответов от сервера
- **`MCPNotification`** - Класс для уведомлений
- **`JsonUtil`** - Утилиты для работы с JSON

### Структура проекта

```
src/
├── main/java/com/example/mcp/
│   ├── MCPApplication.java          # Главное приложение
│   ├── client/
│   │   └── MCPClient.java           # WebSocket клиент
│   ├── service/
│   │   └── MCPService.java          # Высокоуровневый сервис
│   ├── model/
│   │   ├── MCPMessage.java          # Базовый класс сообщений
│   │   ├── MCPRequest.java          # Класс запросов
│   │   ├── MCPResponse.java         # Класс ответов
│   │   └── MCPNotification.java     # Класс уведомлений
│   └── util/
│       └── JsonUtil.java            # JSON утилиты
└── test/java/com/example/mcp/
    └── MCPApplicationTest.java      # Тесты
```

## Требования

- Java 11 или выше
- Maven 3.6 или выше
- MCP сервер (для тестирования)

## Установка и запуск

### 1. Сборка проекта

```bash
mvn clean compile
```

### 2. Запуск тестов

```bash
mvn test
```

### 3. Создание JAR файла

```bash
mvn clean package
```

### 4. Запуск приложения

```bash
# Запуск с Maven
mvn exec:java -Dexec.mainClass="com.example.mcp.MCPApplication"

# Или запуск JAR файла
java -jar target/mcp-java-example-1.0.0.jar

# Запуск с указанием адреса сервера
java -jar target/mcp-java-example-1.0.0.jar ws://localhost:8080/mcp
```

## Использование

### Интерактивный режим

После запуска приложения вы попадете в интерактивный режим:

```
=== Interactive MCP Client ===
Available commands:
  1. list-resources - List available resources
  2. list-tools - List available tools  
  3. list-prompts - List available prompts
  4. read-resource <uri> - Read a resource
  5. call-tool <name> - Call a tool
  6. get-prompt <name> - Get a prompt
  7. custom <method> - Send custom request
  8. demo - Run demo examples
  9. exit - Exit application

mcp> 
```

### Примеры команд

```bash
# Список доступных ресурсов
mcp> list-resources

# Список доступных инструментов
mcp> list-tools

# Список доступных промптов
mcp> list-prompts

# Чтение ресурса
mcp> read-resource file:///path/to/file.txt

# Вызов инструмента
mcp> call-tool calculator

# Получение промпта
mcp> get-prompt code-review

# Демонстрация возможностей
mcp> demo

# Выход из приложения
mcp> exit
```

### Программное использование

```java
import com.example.mcp.service.MCPService;
import java.net.URI;

// Создание сервиса
MCPService mcpService = new MCPService(URI.create("ws://localhost:8080/mcp"));

// Подключение к серверу
if (mcpService.connect(10)) {
    // Инициализация
    MCPResponse response = mcpService.initialize("MyApp", "1.0.0").get();
    
    // Получение списка ресурсов
    response = mcpService.listResources().get();
    
    // Чтение ресурса
    response = mcpService.readResource("file:///example.txt").get();
    
    // Отключение
    mcpService.disconnect();
}
```

## MCP Protocol Support

Этот клиент поддерживает следующие MCP операции:

### Основные операции
- ✅ `initialize` - Инициализация соединения
- ✅ `ping` - Проверка соединения

### Ресурсы
- ✅ `resources/list` - Список доступных ресурсов
- ✅ `resources/read` - Чтение ресурса
- ✅ `resources/subscribe` - Подписка на изменения ресурсов

### Инструменты
- ✅ `tools/list` - Список доступных инструментов
- ✅ `tools/call` - Вызов инструмента

### Промпты
- ✅ `prompts/list` - Список доступных промптов
- ✅ `prompts/get` - Получение промпта

### Уведомления
- ✅ `notifications/initialized` - Инициализация завершена
- ✅ `notifications/resources/list_changed` - Изменился список ресурсов
- ✅ `notifications/tools/list_changed` - Изменился список инструментов

## Конфигурация

### Настройки логирования

Создайте файл `src/main/resources/simplelogger.properties`:

```properties
org.slf4j.simpleLogger.defaultLogLevel=INFO
org.slf4j.simpleLogger.log.com.example.mcp=DEBUG
org.slf4j.simpleLogger.showDateTime=true
org.slf4j.simpleLogger.dateTimeFormat=yyyy-MM-dd HH:mm:ss
```

### Настройки подключения

По умолчанию приложение подключается к `ws://localhost:8080/mcp`. Вы можете изменить это:

```bash
java -jar target/mcp-java-example-1.0.0.jar ws://your-server:port/mcp
```

## Разработка

### Добавление новых операций

1. Добавьте метод в `MCPService`:

```java
public CompletableFuture<MCPResponse> newOperation(String param) {
    Map<String, Object> params = new HashMap<>();
    params.put("parameter", param);
    return client.sendRequest("new/operation", params);
}
```

2. Добавьте обработчик в `MCPApplication`:

```java
case "new-operation":
    handleNewOperation(mcpService, parts[1]);
    break;
```

### Обработка уведомлений

Переопределите метод `onNotification` в `MCPService`:

```java
@Override
public void onNotification(MCPNotification notification) {
    super.onNotification(notification);
    
    switch (notification.getMethod()) {
        case "custom/notification":
            handleCustomNotification(notification);
            break;
    }
}
```

## Тестирование

### Запуск всех тестов

```bash
mvn test
```

### Запуск конкретного теста

```bash
mvn test -Dtest=MCPApplicationTest#testMCPRequestSerialization
```

### Создание mock сервера для тестов

```java
// Пример создания mock MCP сервера
public class MockMCPServer {
    // Реализация mock сервера
}
```

## Примеры использования

### Подключение к Claude Desktop MCP

```java
// Подключение к MCP серверу Claude Desktop
MCPService mcpService = new MCPService(
    URI.create("ws://localhost:3000/mcp")
);
```

### Работа с файловой системой

```java
// Чтение файла через MCP
MCPResponse response = mcpService.readResource("file:///path/to/file.txt").get();
if (!response.isError()) {
    System.out.println("File content: " + response.getResult());
}
```

### Вызов инструментов

```java
// Вызов калькулятора
Map<String, Object> args = new HashMap<>();
args.put("expression", "2 + 2");
MCPResponse response = mcpService.callTool("calculator", args).get();
```

## Устранение проблем

### Проблемы с подключением

1. **Проверьте адрес сервера**: Убедитесь, что MCP сервер запущен и доступен
2. **Проверьте порт**: Убедитесь, что порт не заблокирован
3. **Проверьте логи**: Включите DEBUG логирование для диагностики

### Проблемы с сериализацией

1. **Проверьте JSON**: Используйте `JsonUtil.prettyPrint()` для отладки
2. **Проверьте аннотации**: Убедитесь, что Jackson аннотации правильно настроены

## Содействие

1. Форкните репозиторий
2. Создайте ветку для фичи (`git checkout -b feature/amazing-feature`)
3. Закоммитьте изменения (`git commit -m 'Add amazing feature'`)
4. Отправьте в ветку (`git push origin feature/amazing-feature`)
5. Создайте Pull Request

## Лицензия

Этот проект распространяется под лицензией MIT. См. файл `LICENSE` для подробностей.

## Полезные ссылки

- [MCP Specification](https://modelcontextprotocol.io/docs/specification)
- [Claude Desktop MCP](https://claude.ai/docs/mcp)
- [Jackson Documentation](https://github.com/FasterXML/jackson)
- [Java WebSocket](https://github.com/TooTallNate/Java-WebSocket)
