# Интеграция с LLM моделями в ABAP: выбор подхода

## Сравнение подходов для LLM интеграции

| Критерий | WebSocket (APC) | HTTP SSE | Async HTTP | Polling |
|----------|-----------------|----------|------------|---------|
| **Streaming ответов** | ✅ Отлично | ✅ Отлично | ❌ Нет | ❌ Нет |
| **Прерывание генерации** | ✅ Да | ❌ Сложно | ❌ Нет | ❌ Нет |
| **Латентность** | 🚀 Минимальная | 🟡 Низкая | 🟡 Средняя | 🔴 Высокая |
| **Сложность реализации** | 🟡 Средняя | 🟡 Средняя | ✅ Простая | ✅ Простая |
| **Обработка больших ответов** | ✅ Отлично | ✅ Хорошо | 🟡 Средне | 🔴 Плохо |
| **Real-time прогресс** | ✅ Да | ✅ Да | ❌ Нет | 🟡 Ограниченно |

## Рекомендации по выбору

### 🎯 **Для Conversational AI / Chatbots**
**Выбор: ABAP Push Channels (WebSocket)**

```abap
" Класс для интеграции с ChatGPT через WebSocket
CLASS zcl_chatgpt_websocket DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM cl_apc_wsp_extension.

  PUBLIC SECTION.
    METHODS: if_apc_wsp_extension~on_start REDEFINITION,
             if_apc_wsp_extension~on_message REDEFINITION.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_chat_message,
             role TYPE string,
             content TYPE string,
           END OF ty_chat_message,
           tt_chat_messages TYPE TABLE OF ty_chat_message.

    DATA: mv_api_key TYPE string,
          mt_conversation TYPE tt_chat_messages.

    METHODS: call_openai_streaming
               IMPORTING
                 iv_user_message TYPE string
                 iv_session_id TYPE string,
             send_streaming_chunk
               IMPORTING
                 iv_chunk TYPE string
                 iv_session_id TYPE string
                 iv_is_final TYPE abap_bool DEFAULT abap_false.

ENDCLASS.

CLASS zcl_chatgpt_websocket IMPLEMENTATION.

  METHOD if_apc_wsp_extension~on_start.
    " Инициализация сессии
    TRY.
        " Привязка к AMC каналу для получения ответов от LLM
        i_context->get_binding_manager( )->bind_amc_message_consumer(
          i_application_id = 'LLM_CHAT'
          i_channel_id = '/openai/responses'
        ).

        " Отправка приветственного сообщения
        DATA(lo_message) = i_message_manager->create_message( ).
        lo_message->set_text( '{"type":"connected","message":"AI Assistant готов к работе"}' ).
        i_message_manager->send( lo_message ).

      CATCH cx_apc_error INTO DATA(lx_error).
        MESSAGE lx_error->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD if_apc_wsp_extension~on_message.
    " Обработка сообщений от пользователя
    DATA: lv_user_input TYPE string,
          lv_session_id TYPE string.

    TRY.
        " Парсинг входящего сообщения
        DATA(lv_message_text) = i_message->get_text( ).
        
        " Простой JSON парсинг (в реальности лучше использовать /UI2/CL_JSON)
        FIND REGEX '"message":"([^"]*)"' IN lv_message_text SUBMATCHES lv_user_input.
        FIND REGEX '"sessionId":"([^"]*)"' IN lv_message_text SUBMATCHES lv_session_id.

        IF lv_user_input IS NOT INITIAL.
          " Добавление сообщения пользователя в историю
          APPEND VALUE #( role = 'user' content = lv_user_input ) TO mt_conversation.

          " Вызов OpenAI API в streaming режиме
          call_openai_streaming( 
            iv_user_message = lv_user_input
            iv_session_id = lv_session_id
          ).
        ENDIF.

      CATCH cx_apc_error INTO DATA(lx_error).
        " Отправка ошибки клиенту
        DATA(lo_error_msg) = i_message_manager->create_message( ).
        lo_error_msg->set_text( |{{"type":"error","message":"{ lx_error->get_text( ) }"}}| ).
        i_message_manager->send( lo_error_msg ).
    ENDTRY.
  ENDMETHOD.

  METHOD call_openai_streaming.
    " Асинхронный вызов OpenAI API с streaming
    DATA: lo_http_client TYPE REF TO if_http_client,
          lv_request_body TYPE string,
          lv_response TYPE string.

    " Формирование JSON запроса
    lv_request_body = |{| &&
                      |"model": "gpt-4",| &&
                      |"messages": [| &&
                      |{"role": "user", "content": "{ lv_user_input }"}| &&
                      |],| &&
                      |"stream": true,| &&
                      |"max_tokens": 1000| &&
                      |}|.

    TRY.
        " Создание HTTP клиента
        cl_http_client=>create_by_url(
          EXPORTING
            url = 'https://api.openai.com/v1/chat/completions'
          IMPORTING
            client = lo_http_client
        ).

        " Настройка заголовков
        lo_http_client->request->set_method( 'POST' ).
        lo_http_client->request->set_header_field( 
          name = 'Authorization' 
          value = |Bearer { mv_api_key }| 
        ).
        lo_http_client->request->set_header_field( 
          name = 'Content-Type' 
          value = 'application/json' 
        ).
        lo_http_client->request->set_cdata( lv_request_body ).

        " Отправка в асинхронной задаче для streaming обработки
        CALL FUNCTION 'Z_PROCESS_OPENAI_STREAM'
          STARTING NEW TASK 'OPENAI_STREAM'
          CALLING process_streaming_response ON END OF TASK
          EXPORTING
            client = lo_http_client
            session_id = iv_session_id.

      CATCH cx_root INTO DATA(lx_error).
        send_streaming_chunk( 
          iv_chunk = |Error: { lx_error->get_text( ) }|
          iv_session_id = iv_session_id
          iv_is_final = abap_true
        ).
    ENDTRY.
  ENDMETHOD.

  METHOD send_streaming_chunk.
    " Отправка частичного ответа клиенту
    DATA: lv_chunk_message TYPE string,
          lo_message TYPE REF TO if_apc_wsp_message.

    lv_chunk_message = |{| &&
                       |"type": "{ COND string( WHEN iv_is_final = abap_true THEN 'final' ELSE 'chunk' ) }",| &&
                       |"content": "{ iv_chunk }",| &&
                       |"sessionId": "{ iv_session_id }"| &&
                       |}|.

    TRY.
        lo_message = i_message_manager->create_message( ).
        lo_message->set_text( lv_chunk_message ).
        i_message_manager->send( lo_message ).
      CATCH cx_apc_error.
        " Обработка ошибок отправки
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
```

### 🎯 **Для Document Analysis / Batch Processing**
**Выбор: Асинхронные HTTP запросы**

```abap
" Класс для анализа документов с помощью LLM
CLASS zcl_document_analyzer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_analysis_result,
             document_id TYPE string,
             summary TYPE string,
             key_points TYPE string_table,
             sentiment TYPE string,
             confidence TYPE p DECIMALS 2,
             processing_time TYPE i,
             status TYPE string,
           END OF ty_analysis_result.

    METHODS: analyze_document_async
               IMPORTING
                 iv_document_id TYPE string
                 iv_document_text TYPE string
                 iv_analysis_type TYPE string DEFAULT 'full'
               RETURNING
                 VALUE(rv_task_id) TYPE string,
             get_analysis_status
               IMPORTING
                 iv_task_id TYPE string
               RETURNING
                 VALUE(rv_status) TYPE string,
             get_analysis_result
               IMPORTING
                 iv_task_id TYPE string
               RETURNING
                 VALUE(rs_result) TYPE ty_analysis_result.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_task_info,
             task_id TYPE string,
             document_id TYPE string,
             status TYPE string,
             result TYPE ty_analysis_result,
             started_at TYPE timestamp,
           END OF ty_task_info,
           tt_task_info TYPE HASHED TABLE OF ty_task_info WITH UNIQUE KEY task_id.

    DATA: mt_tasks TYPE tt_task_info,
          mv_api_key TYPE string.

    METHODS: call_llm_analysis
               IMPORTING
                 iv_task_id TYPE string
                 iv_document_text TYPE string
                 iv_analysis_type TYPE string,
             parse_llm_response
               IMPORTING
                 iv_response TYPE string
               RETURNING
                 VALUE(rs_result) TYPE ty_analysis_result.

ENDCLASS.

CLASS zcl_document_analyzer IMPLEMENTATION.

  METHOD analyze_document_async.
    " Создание асинхронной задачи для анализа документа
    DATA: ls_task TYPE ty_task_info.

    " Генерация уникального ID задачи
    rv_task_id = |TASK_{ sy-datum }_{ sy-uzeit }_{ cl_system_uuid=>create_uuid_c22_static( ) }|.

    " Сохранение информации о задаче
    ls_task-task_id = rv_task_id.
    ls_task-document_id = iv_document_id.
    ls_task-status = 'STARTED'.
    GET TIME STAMP FIELD ls_task-started_at.
    INSERT ls_task INTO TABLE mt_tasks.

    " Запуск асинхронной обработки
    CALL FUNCTION 'Z_ANALYZE_DOCUMENT_LLM'
      STARTING NEW TASK rv_task_id
      CALLING task_completed ON END OF TASK
      EXPORTING
        task_id = rv_task_id
        document_text = iv_document_text
        analysis_type = iv_analysis_type
      EXCEPTIONS
        communication_failure = 1
        system_failure = 2
        OTHERS = 3.

    IF sy-subrc <> 0.
      ls_task-status = 'ERROR'.
      MODIFY TABLE mt_tasks FROM ls_task.
    ENDIF.
  ENDMETHOD.

  METHOD get_analysis_status.
    " Получение статуса анализа
    READ TABLE mt_tasks INTO DATA(ls_task) WITH KEY task_id = iv_task_id.
    IF sy-subrc = 0.
      rv_status = ls_task-status.
    ELSE.
      rv_status = 'NOT_FOUND'.
    ENDIF.
  ENDMETHOD.

  METHOD get_analysis_result.
    " Получение результата анализа
    READ TABLE mt_tasks INTO DATA(ls_task) WITH KEY task_id = iv_task_id.
    IF sy-subrc = 0 AND ls_task-status = 'COMPLETED'.
      rs_result = ls_task-result.
    ENDIF.
  ENDMETHOD.

  METHOD call_llm_analysis.
    " Вызов LLM для анализа текста
    DATA: lo_http_client TYPE REF TO if_http_client,
          lv_request_body TYPE string,
          lv_response TYPE string.

    " Формирование промпта в зависимости от типа анализа
    DATA(lv_prompt) = SWITCH string( iv_analysis_type
      WHEN 'summary' THEN 'Provide a concise summary of the following document:'
      WHEN 'sentiment' THEN 'Analyze the sentiment of the following text:'
      WHEN 'key_points' THEN 'Extract key points from the following document:'
      ELSE 'Provide a comprehensive analysis including summary, key points, and sentiment:'
    ).

    lv_request_body = |{| &&
                      |"model": "gpt-4",| &&
                      |"messages": [| &&
                      |{"role": "system", "content": "{ lv_prompt }"},| &&
                      |{"role": "user", "content": "{ iv_document_text }"}| &&
                      |],| &&
                      |"max_tokens": 2000,| &&
                      |"temperature": 0.3| &&
                      |}|.

    TRY.
        cl_http_client=>create_by_url(
          EXPORTING
            url = 'https://api.openai.com/v1/chat/completions'
          IMPORTING
            client = lo_http_client
        ).

        lo_http_client->request->set_method( 'POST' ).
        lo_http_client->request->set_header_field( 
          name = 'Authorization' 
          value = |Bearer { mv_api_key }| 
        ).
        lo_http_client->request->set_header_field( 
          name = 'Content-Type' 
          value = 'application/json' 
        ).
        lo_http_client->request->set_cdata( lv_request_body ).

        lo_http_client->send( ).
        lo_http_client->receive( ).

        lv_response = lo_http_client->response->get_cdata( ).
        
        " Обновление результата задачи
        READ TABLE mt_tasks ASSIGNING FIELD-SYMBOL(<ls_task>) WITH KEY task_id = iv_task_id.
        IF sy-subrc = 0.
          <ls_task>-result = parse_llm_response( lv_response ).
          <ls_task>-status = 'COMPLETED'.
        ENDIF.

        lo_http_client->close( ).

      CATCH cx_root INTO DATA(lx_error).
        " Обработка ошибок
        READ TABLE mt_tasks ASSIGNING <ls_task> WITH KEY task_id = iv_task_id.
        IF sy-subrc = 0.
          <ls_task>-status = 'ERROR'.
        ENDIF.
    ENDTRY.
  ENDMETHOD.

  METHOD parse_llm_response.
    " Парсинг ответа от LLM (упрощенная версия)
    DATA: lv_content TYPE string.

    " Извлечение контента из JSON ответа
    FIND REGEX '"content":"([^"]*)"' IN iv_response SUBMATCHES lv_content.
    
    rs_result-summary = lv_content.
    rs_result-confidence = '0.85'.
    rs_result-sentiment = 'neutral'.
    rs_result-status = 'completed'.
  ENDMETHOD.

ENDCLASS.
```

### 🎯 **Для Real-time Code Generation**
**Выбор: HTTP SSE (Server-Sent Events)**

```abap
" HTTP Handler для code generation с streaming
CLASS zcl_code_generator_sse DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM cl_rest_resource.

  PUBLIC SECTION.
    METHODS: if_rest_resource~post REDEFINITION.

  PRIVATE SECTION.
    METHODS: generate_code_streaming
               IMPORTING
                 io_request TYPE REF TO if_rest_request
                 io_response TYPE REF TO if_rest_response,
             send_sse_chunk
               IMPORTING
                 io_response TYPE REF TO if_rest_response
                 iv_chunk TYPE string
                 iv_event_type TYPE string DEFAULT 'code_chunk'.

ENDCLASS.

CLASS zcl_code_generator_sse IMPLEMENTATION.

  METHOD if_rest_resource~post.
    " Настройка SSE заголовков
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

    generate_code_streaming( 
      io_request = io_request
      io_response = io_response
    ).
  ENDMETHOD.

  METHOD generate_code_streaming.
    DATA: lv_request_body TYPE string,
          lv_programming_language TYPE string,
          lv_requirements TYPE string,
          lv_prompt TYPE string.

    " Парсинг запроса
    lv_request_body = io_request->get_entity( ).
    
    " Извлечение параметров
    FIND REGEX '"language":"([^"]*)"' IN lv_request_body SUBMATCHES lv_programming_language.
    FIND REGEX '"requirements":"([^"]*)"' IN lv_request_body SUBMATCHES lv_requirements.

    " Формирование промпта для генерации кода
    lv_prompt = |Generate { lv_programming_language } code for the following requirements: { lv_requirements }. | &&
                |Provide the code with detailed comments and follow best practices.|.

    " Отправка начального события
    send_sse_chunk( 
      io_response = io_response
      iv_chunk = 'Starting code generation...'
      iv_event_type = 'status'
    ).

    " Здесь должен быть вызов LLM API с streaming
    " Для примера имитируем постепенную генерацию кода
    DATA: lt_code_chunks TYPE string_table.
    
    " Пример chunks для демонстрации
    APPEND 'class ExampleClass {' TO lt_code_chunks.
    APPEND '  constructor() {' TO lt_code_chunks.
    APPEND '    this.data = [];' TO lt_code_chunks.
    APPEND '  }' TO lt_code_chunks.
    APPEND '}' TO lt_code_chunks.

    LOOP AT lt_code_chunks INTO DATA(lv_chunk).
      send_sse_chunk( 
        io_response = io_response
        iv_chunk = lv_chunk
        iv_event_type = 'code_chunk'
      ).
      
      " Имитация задержки генерации
      WAIT UP TO 1 SECONDS.
    ENDLOOP.

    " Отправка финального события
    send_sse_chunk( 
      io_response = io_response
      iv_chunk = 'Code generation completed!'
      iv_event_type = 'completed'
    ).
  ENDMETHOD.

  METHOD send_sse_chunk.
    DATA: lv_sse_message TYPE string.

    lv_sse_message = |event: { iv_event_type }{ cl_abap_char_utilities=>cr_lf }| &&
                     |data: { iv_chunk }{ cl_abap_char_utilities=>cr_lf }| &&
                     |{ cl_abap_char_utilities=>cr_lf }|.

    io_response->get_entity( )->append_cdata( lv_sse_message ).
  ENDMETHOD.

ENDCLASS.
```

## JavaScript клиенты для различных сценариев

### WebSocket клиент для Chatbot:

```javascript
class ABAPChatClient {
    constructor(websocketUrl) {
        this.ws = null;
        this.url = websocketUrl;
        this.sessionId = this.generateSessionId();
        this.messageHandlers = {};
    }

    connect() {
        this.ws = new WebSocket(this.url);
        
        this.ws.onopen = () => {
            console.log('Connected to ABAP Chat AI');
        };

        this.ws.onmessage = (event) => {
            const message = JSON.parse(event.data);
            this.handleMessage(message);
        };

        this.ws.onclose = () => {
            console.log('Disconnected from ABAP Chat AI');
        };
    }

    sendMessage(userMessage) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            const message = {
                type: 'user_message',
                message: userMessage,
                sessionId: this.sessionId,
                timestamp: new Date().toISOString()
            };
            this.ws.send(JSON.stringify(message));
        }
    }

    handleMessage(message) {
        switch(message.type) {
            case 'chunk':
                this.appendToCurrentResponse(message.content);
                break;
            case 'final':
                this.finalizeResponse(message.content);
                break;
            case 'error':
                this.handleError(message.message);
                break;
        }
    }

    appendToCurrentResponse(chunk) {
        const responseElement = document.getElementById('ai-response');
        responseElement.textContent += chunk;
    }

    generateSessionId() {
        return 'session_' + Math.random().toString(36).substr(2, 9);
    }
}
```

### SSE клиент для Code Generation:

```javascript
class CodeGenerationClient {
    constructor(sseUrl) {
        this.url = sseUrl;
    }

    generateCode(language, requirements) {
        const requestBody = {
            language: language,
            requirements: requirements
        };

        const eventSource = new EventSource(this.url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });

        eventSource.addEventListener('status', (event) => {
            this.updateStatus(event.data);
        });

        eventSource.addEventListener('code_chunk', (event) => {
            this.appendCode(event.data);
        });

        eventSource.addEventListener('completed', (event) => {
            this.onGenerationComplete();
            eventSource.close();
        });

        eventSource.onerror = (error) => {
            console.error('SSE Error:', error);
            eventSource.close();
        };
    }

    updateStatus(status) {
        document.getElementById('status').textContent = status;
    }

    appendCode(codeChunk) {
        const codeElement = document.getElementById('generated-code');
        codeElement.textContent += codeChunk + '\n';
    }

    onGenerationComplete() {
        document.getElementById('status').textContent = 'Generation completed!';
    }
}
```

## Итоговые рекомендации

### 🏆 **Для интерактивных AI ассистентов (ChatGPT-like)**
**Выбор: ABAP Push Channels (WebSocket)**
- ✅ Streaming ответов в реальном времени
- ✅ Возможность прерывания генерации
- ✅ Двунаправленная связь
- ✅ Поддержка длинных сессий

### 🏆 **Для batch обработки документов**
**Выбор: Асинхронные HTTP запросы**
- ✅ Простота реализации
- ✅ Надежность для длительных операций
- ✅ Возможность мониторинга прогресса
- ✅ Масштабируемость

### 🏆 **Для real-time генерации контента**
**Выбор: HTTP SSE**
- ✅ Стандартный подход для streaming
- ✅ Простая интеграция с браузерами
- ✅ Хорошая производительность для односторонней связи

### 🏆 **Для простых AI запросов**
**Выбор: Синхронные HTTP запросы**
- ✅ Максимальная простота
- ✅ Подходит для коротких ответов
- ✅ Легкое тестирование и отладка

## Специфика работы с различными LLM провайдерами

### OpenAI API
- Поддерживает streaming через WebSocket или SSE
- Использует параметр `"stream": true`
- Отправляет данные в формате Server-Sent Events

### Azure OpenAI
- Аналогично OpenAI API
- Дополнительная аутентификация через Azure AD
- Поддержка корпоративных функций безопасности

### AWS Bedrock
- Поддерживает streaming для некоторых моделей
- Использует AWS SDK для подключения
- Требует специфичной аутентификации

### Google PaLM/Gemini
- Поддержка streaming зависит от конкретной модели
- Использует Google Cloud Authentication
- Может требовать специальных заголовков

Выбор конкретного подхода должен основываться на ваших требованиях к латентности, объему данных, интерактивности и сложности интеграции.