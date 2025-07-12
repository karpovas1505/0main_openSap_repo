# Server-Sent Events в ABAP разработке

## Общая информация

**Server-Sent Events (SSE)** - это стандарт HTML5, который позволяет серверу отправлять данные клиенту через HTTP в реальном времени без необходимости постоянного опроса (polling).

## Прямая поддержка SSE в ABAP

❌ **ABAP не поддерживает SSE напрямую** из коробки.

Однако, SAP предлагает более мощные альтернативы:

## 1. ABAP Channels - Рекомендуемый подход

### ABAP Push Channels (APC)
ABAP Push Channels используют **WebSocket** - более современную технологию для real-time коммуникации:

```abap
" Пример APC класса для WebSocket коммуникации
CLASS zcl_apc_sse_demo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM cl_apc_wsp_extension.

  PUBLIC SECTION.
    METHODS: if_apc_wsp_extension~on_start
               REDEFINITION,
             if_apc_wsp_extension~on_message  
               REDEFINITION.

  PRIVATE SECTION.
    METHODS: send_sse_like_message
               IMPORTING
                 iv_data TYPE string
                 iv_event_type TYPE string DEFAULT 'message'.

ENDCLASS.

CLASS zcl_apc_sse_demo IMPLEMENTATION.

  METHOD if_apc_wsp_extension~on_start.
    " Подключение к AMC каналу для получения событий
    TRY.
        i_context->get_binding_manager( )->bind_amc_message_consumer(
          i_application_id = 'SSE_DEMO'
          i_channel_id = '/events'
        ).
      CATCH cx_apc_error INTO DATA(lx_error).
        " Обработка ошибок
        MESSAGE lx_error->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_message.
    " Обработка входящих сообщений от клиента
    DATA: lv_message TYPE string.
    
    lv_message = i_message->get_text( ).
    
    " Отправка ответа в формате SSE
    send_sse_like_message( 
      iv_data = |Echo: { lv_message }|
      iv_event_type = 'echo'
    ).
  ENDMETHOD.

  METHOD send_sse_like_message.
    " Формирование сообщения в SSE-подобном формате
    DATA: lv_sse_message TYPE string,
          lo_message TYPE REF TO if_apc_wsp_message.

    " Формат SSE: event: eventType\ndata: messageData\n\n
    lv_sse_message = |event: { iv_event_type }{ cl_abap_char_utilities=>cr_lf }| &&
                     |data: { iv_data }{ cl_abap_char_utilities=>cr_lf }| &&
                     |{ cl_abap_char_utilities=>cr_lf }|.

    TRY.
        lo_message = i_message_manager->create_message( ).
        lo_message->set_text( lv_sse_message ).
        i_message_manager->send( lo_message ).
      CATCH cx_apc_error INTO DATA(lx_error).
        " Обработка ошибок
        MESSAGE lx_error->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
```

### ABAP Messaging Channels (AMC)
Для отправки событий из ABAP сессий:

```abap
" Класс для отправки событий через AMC
CLASS zcl_sse_event_sender DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS: send_event
               IMPORTING
                 iv_event_type TYPE string
                 iv_data TYPE string
                 iv_channel TYPE string DEFAULT '/events'.

  PRIVATE SECTION.
    DATA: mo_producer TYPE REF TO if_amc_message_producer_text.

ENDCLASS.

CLASS zcl_sse_event_sender IMPLEMENTATION.

  METHOD send_event.
    " Отправка события через AMC
    TRY.
        mo_producer = CAST if_amc_message_producer_text(
          cl_amc_channel_manager=>create_message_producer(
            i_application_id = 'SSE_DEMO'
            i_channel_id = iv_channel
          )
        ).

        DATA(lv_message) = |{ iv_event_type }:{ iv_data }|.
        mo_producer->send( i_message = lv_message ).

      CATCH cx_amc_error INTO DATA(lx_error).
        MESSAGE lx_error->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
```

## 2. Создание Custom SSE HTTP-сервиса

Можно создать собственный HTTP-сервис, который эмулирует SSE:

```abap
" HTTP Handler для SSE
CLASS zcl_sse_http_handler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM cl_rest_resource.

  PUBLIC SECTION.
    METHODS: if_rest_resource~post REDEFINITION,
             if_rest_resource~get REDEFINITION.

  PRIVATE SECTION.
    METHODS: handle_sse_connection
               IMPORTING
                 io_request TYPE REF TO if_rest_request
                 io_response TYPE REF TO if_rest_response,
             send_sse_event
               IMPORTING
                 io_response TYPE REF TO if_rest_response
                 iv_event TYPE string
                 iv_data TYPE string
                 iv_id TYPE string OPTIONAL.

ENDCLASS.

CLASS zcl_sse_http_handler IMPLEMENTATION.

  METHOD if_rest_resource~get.
    " Обработка GET запроса для SSE подключения
    handle_sse_connection( 
      io_request = io_request
      io_response = io_response
    ).
  ENDMETHOD.

  METHOD if_rest_resource~post.
    " Обработка POST запросов для отправки событий
    DATA: lv_body TYPE string,
          lv_event TYPE string,
          lv_data TYPE string.

    lv_body = io_request->get_entity( ).
    
    " Парсинг JSON данных
    CALL TRANSFORMATION sjson2abap
      SOURCE JSON lv_body
      RESULT event = lv_event
             data = lv_data.

    " Отправка события всем подключенным клиентам
    send_sse_event( 
      io_response = io_response
      iv_event = lv_event
      iv_data = lv_data
    ).
  ENDMETHOD.

  METHOD handle_sse_connection.
    " Установка заголовков для SSE
    io_response->set_header_field( 
      iv_name = 'Content-Type'
      iv_value = 'text/event-stream'
    ).
    io_response->set_header_field( 
      iv_name = 'Cache-Control'
      iv_value = 'no-cache'
    ).
    io_response->set_header_field( 
      iv_name = 'Connection'
      iv_value = 'keep-alive'
    ).
    io_response->set_header_field( 
      iv_name = 'Access-Control-Allow-Origin'
      iv_value = '*'
    ).

    " Отправка начального сообщения
    send_sse_event( 
      io_response = io_response
      iv_event = 'connected'
      iv_data = 'Connection established'
    ).

    " Здесь можно добавить логику для поддержания соединения
    " и отправки событий в реальном времени
  ENDMETHOD.

  METHOD send_sse_event.
    DATA: lv_sse_message TYPE string.

    " Формирование SSE сообщения
    lv_sse_message = |event: { iv_event }{ cl_abap_char_utilities=>cr_lf }|.
    
    IF iv_id IS NOT INITIAL.
      lv_sse_message = lv_sse_message && |id: { iv_id }{ cl_abap_char_utilities=>cr_lf }|.
    ENDIF.
    
    lv_sse_message = lv_sse_message && 
                     |data: { iv_data }{ cl_abap_char_utilities=>cr_lf }| &&
                     |{ cl_abap_char_utilities=>cr_lf }|.

    io_response->get_entity( )->set_string_data( lv_sse_message ).
  ENDMETHOD.

ENDCLASS.
```

## 3. Интеграция с UI5/Fiori

### JavaScript клиент для WebSocket (APC):

```javascript
// Подключение к ABAP Push Channel
class AbapSSEClient {
    constructor(url) {
        this.url = url;
        this.ws = null;
        this.eventHandlers = {};
    }

    connect() {
        this.ws = new WebSocket(this.url);
        
        this.ws.onopen = () => {
            console.log('Connected to ABAP Push Channel');
            this.dispatchEvent('connected', {});
        };

        this.ws.onmessage = (event) => {
            this.handleSSEMessage(event.data);
        };

        this.ws.onclose = () => {
            console.log('Disconnected from ABAP Push Channel');
            this.dispatchEvent('disconnected', {});
        };

        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
            this.dispatchEvent('error', { error: error });
        };
    }

    handleSSEMessage(message) {
        // Парсинг SSE-подобного сообщения
        const lines = message.split('\n');
        let eventType = 'message';
        let data = '';

        for (const line of lines) {
            if (line.startsWith('event: ')) {
                eventType = line.substring(7);
            } else if (line.startsWith('data: ')) {
                data = line.substring(6);
            }
        }

        this.dispatchEvent(eventType, { data: data });
    }

    addEventListener(eventType, handler) {
        if (!this.eventHandlers[eventType]) {
            this.eventHandlers[eventType] = [];
        }
        this.eventHandlers[eventType].push(handler);
    }

    dispatchEvent(eventType, eventData) {
        if (this.eventHandlers[eventType]) {
            this.eventHandlers[eventType].forEach(handler => {
                handler(eventData);
            });
        }
    }

    send(message) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(message);
        }
    }

    disconnect() {
        if (this.ws) {
            this.ws.close();
        }
    }
}

// Использование
const sseClient = new AbapSSEClient('wss://your-server:port/sap/bc/apc/sap/sse_demo');

sseClient.addEventListener('connected', (event) => {
    console.log('Connected to server');
});

sseClient.addEventListener('dataUpdate', (event) => {
    console.log('Data updated:', event.data);
    // Обновление UI
});

sseClient.addEventListener('notification', (event) => {
    console.log('Notification:', event.data);
    // Показать уведомление
});

sseClient.connect();
```

### Традиционный SSE клиент (если используется HTTP подход):

```javascript
// Традиционный EventSource для SSE
class TraditionalSSEClient {
    constructor(url) {
        this.url = url;
        this.eventSource = null;
    }

    connect() {
        this.eventSource = new EventSource(this.url);

        this.eventSource.onopen = () => {
            console.log('SSE connection opened');
        };

        this.eventSource.onmessage = (event) => {
            console.log('Message received:', event.data);
        };

        this.eventSource.onerror = (error) => {
            console.error('SSE error:', error);
        };

        // Пользовательские события
        this.eventSource.addEventListener('dataUpdate', (event) => {
            console.log('Data update:', event.data);
        });

        this.eventSource.addEventListener('notification', (event) => {
            console.log('Notification:', event.data);
        });
    }

    disconnect() {
        if (this.eventSource) {
            this.eventSource.close();
        }
    }
}
```

## 4. Практический пример: Monitoring Dashboard

```abap
" Класс для мониторинга системы с отправкой событий
CLASS zcl_system_monitor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS: start_monitoring,
             stop_monitoring,
             send_system_status.

  PRIVATE SECTION.
    DATA: mo_event_sender TYPE REF TO zcl_sse_event_sender,
          mv_monitoring_active TYPE abap_bool.

    METHODS: check_system_status,
             get_cpu_usage RETURNING VALUE(rv_cpu) TYPE i,
             get_memory_usage RETURNING VALUE(rv_memory) TYPE i,
             get_active_sessions RETURNING VALUE(rv_sessions) TYPE i.

ENDCLASS.

CLASS zcl_system_monitor IMPLEMENTATION.

  METHOD start_monitoring.
    CREATE OBJECT mo_event_sender.
    mv_monitoring_active = abap_true.

    " Запуск мониторинга в фоновом режиме
    DO.
      IF mv_monitoring_active = abap_false.
        EXIT.
      ENDIF.

      check_system_status( ).
      WAIT UP TO 5 SECONDS.
    ENDDO.
  ENDMETHOD.

  METHOD stop_monitoring.
    mv_monitoring_active = abap_false.
  ENDMETHOD.

  METHOD check_system_status.
    DATA: lv_cpu TYPE i,
          lv_memory TYPE i,
          lv_sessions TYPE i,
          lv_status_data TYPE string.

    lv_cpu = get_cpu_usage( ).
    lv_memory = get_memory_usage( ).
    lv_sessions = get_active_sessions( ).

    lv_status_data = |{{ "cpu": { lv_cpu }, "memory": { lv_memory }, "sessions": { lv_sessions }, "timestamp": "{ sy-datum }{ sy-uzeit }" }}|.

    " Отправка события о статусе системы
    mo_event_sender->send_event(
      iv_event_type = 'systemStatus'
      iv_data = lv_status_data
      iv_channel = '/system/monitoring'
    ).

    " Отправка предупреждений
    IF lv_cpu > 80.
      mo_event_sender->send_event(
        iv_event_type = 'alert'
        iv_data = |{{ "type": "cpu", "value": { lv_cpu }, "message": "High CPU usage detected" }}|
        iv_channel = '/system/alerts'
      ).
    ENDIF.

    IF lv_memory > 90.
      mo_event_sender->send_event(
        iv_event_type = 'alert'
        iv_data = |{{ "type": "memory", "value": { lv_memory }, "message": "High memory usage detected" }}|
        iv_channel = '/system/alerts'
      ).
    ENDIF.
  ENDMETHOD.

  METHOD get_cpu_usage.
    " Получение использования CPU
    " Здесь должна быть реальная логика получения данных
    rv_cpu = 45. " Пример значения
  ENDMETHOD.

  METHOD get_memory_usage.
    " Получение использования памяти
    rv_memory = 67. " Пример значения
  ENDMETHOD.

  METHOD get_active_sessions.
    " Получение количества активных сессий
    rv_sessions = 25. " Пример значения
  ENDMETHOD.

ENDCLASS.
```

## 5. Настройка в системе

### Создание APC приложения:

1. Перейдите в транзакцию **SAPC**
2. Создайте новое APC приложение "SSE_DEMO"
3. Настройте соответствующий класс обработчик
4. Активируйте сервис в **SICF**

### Создание AMC приложения:

1. Перейдите в транзакцию **SAMC**
2. Создайте приложение "SSE_DEMO"
3. Настройте каналы "/events", "/system/monitoring", "/system/alerts"
4. Укажите авторизованные программы

## Сравнение подходов

| Технология | Преимущества | Недостатки |
|------------|-------------|-----------|
| **ABAP Push Channels (WebSocket)** | ✅ Двунаправленная связь<br>✅ Высокая производительность<br>✅ Встроенная поддержка в ABAP<br>✅ Поддержка PCP протокола | ❌ Требует WebSocket поддержку<br>❌ Более сложная настройка |
| **Custom HTTP SSE** | ✅ Стандартный SSE протокол<br>✅ Простая интеграция с браузерами<br>✅ Односторонняя связь от сервера | ❌ Ограниченная функциональность<br>❌ Сложность поддержания соединения |
| **Polling** | ✅ Простота реализации<br>✅ Совместимость | ❌ Высокая нагрузка на сервер<br>❌ Задержки в получении данных |

## Рекомендации

### Для новых проектов:
🎯 **Используйте ABAP Push Channels (APC)** - это современный и эффективный подход

### Для интеграции с существующими системами:
🎯 **Создавайте custom HTTP сервисы** для эмуляции SSE

### Для простых случаев:
🎯 **Используйте polling** с разумными интервалами

## Заключение

Хотя ABAP не поддерживает Server-Sent Events напрямую, есть несколько эффективных способов достичь аналогичной функциональности:

1. **ABAP Channels** - рекомендуемый подход для новых проектов
2. **Custom HTTP сервисы** - для интеграции с существующими системами
3. **Гибридные решения** - комбинация различных подходов

Выбор подхода зависит от ваших конкретных требований, существующей архитектуры и целевой аудитории приложения.