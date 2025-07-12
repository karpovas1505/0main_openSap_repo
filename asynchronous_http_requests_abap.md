# Асинхронные HTTP-запросы в ABAP

## Введение

В SAP ABAP существует несколько способов выполнения асинхронных HTTP-запросов. Асинхронные запросы позволяют выполнять HTTP-вызовы без блокировки основного потока выполнения программы.

## Методы реализации асинхронных HTTP-запросов

### 1. Использование функциональных модулей с STARTING NEW TASK

#### Создание RFC-функции для HTTP-запроса

Первым делом создайте RFC-функцию, которая будет выполнять HTTP-запрос:

```abap
FUNCTION Z_HTTP_REQUEST_ASYNC
  IMPORTING
    VALUE(IV_URL) TYPE STRING
    VALUE(IV_METHOD) TYPE STRING DEFAULT 'GET'
    VALUE(IV_HEADERS) TYPE STRING_TABLE OPTIONAL
    VALUE(IV_DATA) TYPE STRING OPTIONAL
  EXPORTING
    VALUE(EV_RESPONSE) TYPE STRING
    VALUE(EV_HTTP_CODE) TYPE I
    VALUE(EV_SUCCESS) TYPE ABAP_BOOL.

  DATA: lo_http_client TYPE REF TO if_http_client,
        lv_response TYPE string,
        lv_http_code TYPE i.

  " Создание HTTP-клиента
  cl_http_client=>create_by_url(
    EXPORTING
      url = iv_url
    IMPORTING
      client = lo_http_client
    EXCEPTIONS
      argument_not_found = 1
      plugin_not_active = 2
      internal_error = 3
      OTHERS = 4
  ).

  IF sy-subrc <> 0.
    ev_success = abap_false.
    RETURN.
  ENDIF.

  " Установка метода
  lo_http_client->request->set_method( iv_method ).

  " Установка заголовков
  IF lines( iv_headers ) > 0.
    LOOP AT iv_headers INTO DATA(lv_header).
      SPLIT lv_header AT ':' INTO DATA(lv_name) DATA(lv_value).
      lo_http_client->request->set_header_field(
        name = lv_name
        value = lv_value
      ).
    ENDLOOP.
  ENDIF.

  " Установка данных для POST/PUT запросов
  IF iv_data IS NOT INITIAL.
    lo_http_client->request->set_cdata( iv_data ).
  ENDIF.

  " Отправка запроса
  lo_http_client->send(
    EXCEPTIONS
      http_communication_failure = 1
      http_invalid_state = 2
      OTHERS = 3
  ).

  IF sy-subrc <> 0.
    ev_success = abap_false.
    lo_http_client->close( ).
    RETURN.
  ENDIF.

  " Получение ответа
  lo_http_client->receive(
    EXCEPTIONS
      http_communication_failure = 1
      http_invalid_state = 2
      http_processing_failed = 3
      OTHERS = 4
  ).

  IF sy-subrc <> 0.
    ev_success = abap_false.
    lo_http_client->close( ).
    RETURN.
  ENDIF.

  " Получение статуса и данных ответа
  lo_http_client->response->get_status(
    IMPORTING
      code = lv_http_code
  ).

  lv_response = lo_http_client->response->get_cdata( ).

  " Возврат результатов
  ev_response = lv_response.
  ev_http_code = lv_http_code.
  ev_success = abap_true.

  lo_http_client->close( ).

ENDFUNCTION.
```

#### Основной класс для асинхронных запросов

```abap
CLASS zcl_async_http_client DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_http_result,
             task_id TYPE char32,
             url TYPE string,
             response TYPE string,
             http_code TYPE i,
             success TYPE abap_bool,
             finished TYPE abap_bool,
           END OF ty_http_result,
           tt_http_results TYPE TABLE OF ty_http_result.

    DATA: mt_results TYPE tt_http_results,
          mv_timeout TYPE i VALUE 120,
          mv_finished_count TYPE i.

    METHODS: constructor,
             add_request
               IMPORTING
                 iv_task_id TYPE char32
                 iv_url TYPE string
                 iv_method TYPE string DEFAULT 'GET'
                 it_headers TYPE string_table OPTIONAL
                 iv_data TYPE string OPTIONAL,
             execute_all_async,
             wait_for_completion,
             get_results
               RETURNING VALUE(rt_results) TYPE tt_http_results,
             task_finished
               IMPORTING p_task TYPE char32.

  PRIVATE SECTION.
    METHODS: check_task_completion.
ENDCLASS.

CLASS zcl_async_http_client IMPLEMENTATION.

  METHOD constructor.
    CLEAR: mt_results, mv_finished_count.
  ENDMETHOD.

  METHOD add_request.
    DATA: ls_result TYPE ty_http_result.
    
    ls_result-task_id = iv_task_id.
    ls_result-url = iv_url.
    ls_result-finished = abap_false.
    
    APPEND ls_result TO mt_results.
  ENDMETHOD.

  METHOD execute_all_async.
    DATA: lv_task_id TYPE char32.

    LOOP AT mt_results INTO DATA(ls_result).
      lv_task_id = ls_result-task_id.
      
      CALL FUNCTION 'Z_HTTP_REQUEST_ASYNC'
        STARTING NEW TASK lv_task_id
        CALLING task_finished ON END OF TASK
        EXPORTING
          iv_url = ls_result-url
          iv_method = 'GET'
        EXCEPTIONS
          communication_failure = 1
          system_failure = 2
          resource_failure = 3
          OTHERS = 4.

      IF sy-subrc <> 0.
        " Обработка ошибки запуска задачи
        ls_result-success = abap_false.
        ls_result-finished = abap_true.
        MODIFY mt_results FROM ls_result INDEX sy-tabix.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD wait_for_completion.
    DATA: lv_start_time TYPE timestampl,
          lv_current_time TYPE timestampl,
          lv_elapsed_seconds TYPE i.

    GET TIME STAMP FIELD lv_start_time.

    " Ждем завершения всех задач или таймаута
    WHILE mv_finished_count < lines( mt_results ).
      WAIT FOR ASYNCHRONOUS TASKS UNTIL mv_finished_count >= lines( mt_results ) UP TO 1 SECONDS.
      
      " Проверка таймаута
      GET TIME STAMP FIELD lv_current_time.
      lv_elapsed_seconds = cl_abap_tstmp=>subtract(
        tstmp1 = lv_current_time
        tstmp2 = lv_start_time
      ).
      
      IF lv_elapsed_seconds > mv_timeout.
        " Таймаут - прерываем ожидание
        EXIT.
      ENDIF.
    ENDWHILE.
  ENDMETHOD.

  METHOD task_finished.
    DATA: lv_response TYPE string,
          lv_http_code TYPE i,
          lv_success TYPE abap_bool.

    " Получение результатов задачи
    RECEIVE RESULTS FROM FUNCTION 'Z_HTTP_REQUEST_ASYNC'
      IMPORTING
        ev_response = lv_response
        ev_http_code = lv_http_code
        ev_success = lv_success
      EXCEPTIONS
        communication_failure = 1
        system_failure = 2
        OTHERS = 3.

    " Обновление результатов
    READ TABLE mt_results INTO DATA(ls_result) 
      WITH KEY task_id = p_task.
    
    IF sy-subrc = 0.
      ls_result-response = lv_response.
      ls_result-http_code = lv_http_code.
      ls_result-success = lv_success.
      ls_result-finished = abap_true.
      
      MODIFY mt_results FROM ls_result INDEX sy-tabix.
      ADD 1 TO mv_finished_count.
    ENDIF.
  ENDMETHOD.

  METHOD get_results.
    rt_results = mt_results.
  ENDMETHOD.

ENDCLASS.
```

#### Пример использования

```abap
DATA: lo_async_client TYPE REF TO zcl_async_http_client,
      lt_results TYPE zcl_async_http_client=>tt_http_results.

" Создание клиента
CREATE OBJECT lo_async_client.

" Добавление запросов
lo_async_client->add_request(
  iv_task_id = 'TASK_001'
  iv_url = 'https://api.example.com/data1'
).

lo_async_client->add_request(
  iv_task_id = 'TASK_002'
  iv_url = 'https://api.example.com/data2'
).

lo_async_client->add_request(
  iv_task_id = 'TASK_003'
  iv_url = 'https://api.example.com/data3'
).

" Выполнение всех запросов асинхронно
lo_async_client->execute_all_async( ).

" Ожидание завершения всех запросов
lo_async_client->wait_for_completion( ).

" Получение результатов
lt_results = lo_async_client->get_results( ).

" Обработка результатов
LOOP AT lt_results INTO DATA(ls_result).
  IF ls_result-success = abap_true.
    WRITE: / 'Task:', ls_result-task_id, 
           'HTTP Code:', ls_result-http_code,
           'Response:', ls_result-response(100).
  ELSE.
    WRITE: / 'Task:', ls_result-task_id, 'FAILED'.
  ENDIF.
ENDLOOP.
```

### 2. Использование ABAP Channels для асинхронных HTTP-запросов

ABAP Channels позволяют создавать event-driven архитектуру для асинхронных HTTP-запросов:

```abap
CLASS zcl_async_http_with_channels DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS: start_async_request
               IMPORTING
                 iv_url TYPE string
                 iv_channel TYPE string,
             handle_response
               FOR EVENT message_received OF if_amc_message_receiver_text
               IMPORTING
                 sender
                 message.

  PRIVATE SECTION.
    DATA: mo_producer TYPE REF TO if_amc_message_producer_text,
          mo_consumer TYPE REF TO if_amc_message_consumer_text.

    METHODS: setup_channels,
             send_http_request
               IMPORTING
                 iv_url TYPE string
                 iv_channel TYPE string.

ENDCLASS.

CLASS zcl_async_http_with_channels IMPLEMENTATION.

  METHOD start_async_request.
    setup_channels( ).
    send_http_request( iv_url = iv_url iv_channel = iv_channel ).
  ENDMETHOD.

  METHOD setup_channels.
    " Настройка AMC каналов
    TRY.
        mo_producer = cl_amc_channel_manager=>create_message_producer(
          i_application_id = 'HTTP_ASYNC'
          i_channel_id = '/async_http'
        ).
        
        mo_consumer = cl_amc_channel_manager=>create_message_consumer(
          i_application_id = 'HTTP_ASYNC'
          i_channel_id = '/async_http'
        ).
        
        mo_consumer->start_message_delivery( ).
        
        SET HANDLER handle_response FOR mo_consumer.
        
      CATCH cx_amc_error INTO DATA(lx_error).
        " Обработка ошибок
        MESSAGE lx_error->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD send_http_request.
    " Отправка HTTP-запроса в отдельной задаче
    " с последующей отправкой результата через AMC
    DATA: lv_message TYPE string.
    
    " Здесь будет логика отправки HTTP-запроса
    " и формирования сообщения с результатом
    
    TRY.
        lv_message = |{ iv_url }:SUCCESS:Response Data|.
        mo_producer->send( lv_message ).
        
      CATCH cx_amc_error INTO DATA(lx_error).
        " Обработка ошибок
        MESSAGE lx_error->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD handle_response.
    " Обработка полученного ответа
    DATA: lt_parts TYPE string_table,
          lv_url TYPE string,
          lv_status TYPE string,
          lv_response TYPE string.
    
    SPLIT message AT ':' INTO TABLE lt_parts.
    
    IF lines( lt_parts ) >= 3.
      READ TABLE lt_parts INTO lv_url INDEX 1.
      READ TABLE lt_parts INTO lv_status INDEX 2.
      READ TABLE lt_parts INTO lv_response INDEX 3.
      
      WRITE: / 'URL:', lv_url, 'Status:', lv_status, 'Response:', lv_response.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
```

### 3. Использование ABAP Daemons для длительных асинхронных операций

```abap
CLASS zcl_http_daemon DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM cl_abap_daemon_ext_base.

  PUBLIC SECTION.
    METHODS: if_abap_daemon_extension~on_accept
               REDEFINITION,
             if_abap_daemon_extension~on_start
               REDEFINITION,
             if_abap_daemon_extension~on_restart
               REDEFINITION,
             if_abap_daemon_extension~on_stop
               REDEFINITION.

  PRIVATE SECTION.
    METHODS: process_http_queue,
             execute_http_request
               IMPORTING
                 iv_url TYPE string
                 iv_method TYPE string
                 iv_data TYPE string OPTIONAL
               RETURNING
                 VALUE(rv_response) TYPE string.

ENDCLASS.

CLASS zcl_http_daemon IMPLEMENTATION.

  METHOD if_abap_daemon_extension~on_start.
    " Инициализация daemon'а
    super->if_abap_daemon_extension~on_start( ).
    
    " Начало обработки очереди HTTP-запросов
    process_http_queue( ).
  ENDMETHOD.

  METHOD if_abap_daemon_extension~on_accept.
    " Принятие входящих запросов
    super->if_abap_daemon_extension~on_accept( ).
  ENDMETHOD.

  METHOD if_abap_daemon_extension~on_restart.
    " Перезапуск daemon'а
    super->if_abap_daemon_extension~on_restart( ).
  ENDMETHOD.

  METHOD if_abap_daemon_extension~on_stop.
    " Остановка daemon'а
    super->if_abap_daemon_extension~on_stop( ).
  ENDMETHOD.

  METHOD process_http_queue.
    " Обработка очереди HTTP-запросов
    " Здесь будет логика получения запросов из очереди
    " и их асинхронного выполнения
  ENDMETHOD.

  METHOD execute_http_request.
    " Выполнение HTTP-запроса
    DATA: lo_client TYPE REF TO if_http_client,
          lv_response TYPE string.

    cl_http_client=>create_by_url(
      EXPORTING
        url = iv_url
      IMPORTING
        client = lo_client
      EXCEPTIONS
        argument_not_found = 1
        plugin_not_active = 2
        internal_error = 3
        OTHERS = 4
    ).

    IF sy-subrc = 0.
      lo_client->request->set_method( iv_method ).
      
      IF iv_data IS NOT INITIAL.
        lo_client->request->set_cdata( iv_data ).
      ENDIF.
      
      lo_client->send( ).
      lo_client->receive( ).
      
      lv_response = lo_client->response->get_cdata( ).
      lo_client->close( ).
    ENDIF.

    rv_response = lv_response.
  ENDMETHOD.

ENDCLASS.
```

## Настройка RFC-соединения для HTTP-запросов

### Создание HTTP-соединения в SM59

1. Перейдите в транзакцию **SM59**
2. Выберите **HTTP Connections to External Server** (Type G)
3. Нажмите **Create**
4. Введите следующие параметры:
   - **Target Host**: URL внешнего сервера
   - **Service No**: 80 (для HTTP) или 443 (для HTTPS)
   - **Path Prefix**: путь к API (если необходимо)

### Настройка SSL для HTTPS

1. Перейдите в транзакцию **STRUST**
2. Выберите **SSL client SSL Client (Standard)**
3. Загрузите необходимые SSL-сертификаты
4. В SM59 установите **SSL** как **Active**
5. Выберите **ANONYM SSL**

## Лучшие практики

### 1. Обработка ошибок
```abap
" Всегда проверяйте sy-subrc после вызовов
IF sy-subrc <> 0.
  " Обработка ошибки
  MESSAGE 'HTTP request failed' TYPE 'E'.
ENDIF.
```

### 2. Таймауты
```abap
" Установка таймаута для задач
DATA: lv_timeout TYPE i VALUE 120. " 2 минуты

WAIT FOR ASYNCHRONOUS TASKS UNTIL condition UP TO lv_timeout SECONDS.
```

### 3. Управление ресурсами
```abap
" Всегда закрывайте HTTP-соединения
IF lo_http_client IS BOUND.
  lo_http_client->close( ).
ENDIF.
```

### 4. Логирование
```abap
" Логирование запросов и ответов
DATA: lo_log TYPE REF TO cl_log.

CREATE OBJECT lo_log
  EXPORTING
    object = 'HTTP_ASYNC'
    subobject = 'REQUEST'.

lo_log->info( 
  msg_id = 'Z_HTTP'
  msg_no = '001'
  msg_v1 = |URL: { iv_url }|
).
```

## Заключение

Асинхронные HTTP-запросы в ABAP можно реализовать несколькими способами:

1. **RFC с STARTING NEW TASK** - самый простой и распространенный способ
2. **ABAP Channels** - для event-driven архитектуры
3. **ABAP Daemons** - для длительных фоновых процессов

Выбор метода зависит от ваших конкретных требований:
- Для простых асинхронных запросов используйте RFC с STARTING NEW TASK
- Для комплексных систем с событиями используйте ABAP Channels
- Для постоянно работающих сервисов используйте ABAP Daemons

Всегда помните о правильной обработке ошибок, управлении ресурсами и логировании для обеспечения надежности вашего кода.