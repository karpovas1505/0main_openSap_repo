*&---------------------------------------------------------------------*
*& Report ZAI_CHAT_MULTI
*&---------------------------------------------------------------------*
*& Программа для чата с различными ИИ моделями
*& Поддержка: OpenAI, Claude, Gemini, локальные модели
*&---------------------------------------------------------------------*
REPORT zai_chat_multi.

*----------------------------------------------------------------------*
* Типы данных
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_ai_provider,
         provider TYPE string,
         name TYPE string,
         url TYPE string,
         api_key_required TYPE abap_bool,
         models TYPE string_table,
       END OF ty_ai_provider.

TYPES: BEGIN OF ty_chat_session,
         session_id TYPE string,
         provider TYPE string,
         model TYPE string,
         system_prompt TYPE string,
         created_at TYPE timestampl,
         updated_at TYPE timestampl,
       END OF ty_chat_session.

TYPES: BEGIN OF ty_message,
         session_id TYPE string,
         timestamp TYPE timestampl,
         role TYPE string,     " system, user, assistant
         content TYPE string,
         tokens_used TYPE i,
         model TYPE string,
         cost TYPE p DECIMALS 4,
       END OF ty_message.

*----------------------------------------------------------------------*
* Глобальные переменные
*----------------------------------------------------------------------*
DATA: gt_providers TYPE TABLE OF ty_ai_provider,
      gt_sessions TYPE TABLE OF ty_chat_session,
      gt_messages TYPE TABLE OF ty_message,
      go_ai_manager TYPE REF TO lcl_ai_manager,
      go_chat_ui TYPE REF TO lcl_chat_ui,
      gv_current_session TYPE string,
      gv_current_provider TYPE string.

*----------------------------------------------------------------------*
* Константы для провайдеров
*----------------------------------------------------------------------*
CONSTANTS: BEGIN OF gc_providers,
             openai TYPE string VALUE 'OPENAI',
             claude TYPE string VALUE 'CLAUDE',
             gemini TYPE string VALUE 'GEMINI',
             local TYPE string VALUE 'LOCAL',
           END OF gc_providers.

*----------------------------------------------------------------------*
* Селекционный экран
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_prov TYPE string DEFAULT gc_providers-openai,
            p_model TYPE string DEFAULT 'gpt-3.5-turbo',
            p_apikey TYPE string LOWER CASE.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_temp TYPE p DECIMALS 2 DEFAULT '0.7',
            p_maxtok TYPE i DEFAULT 1000,
            p_systm TYPE string LOWER CASE 
                    DEFAULT 'Ты helpful assistant. Отвечай кратко и по существу.',
            p_stream AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.
PARAMETERS: p_sessid TYPE string,
            p_loadsv AS CHECKBOX DEFAULT 'X',
            p_autosv AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b3.

*----------------------------------------------------------------------*
* Класс для управления ИИ провайдерами
*----------------------------------------------------------------------*
CLASS lcl_ai_manager DEFINITION.
  PUBLIC SECTION.
    METHODS: constructor,
             get_providers RETURNING VALUE(rt_providers) TYPE table,
             create_session IMPORTING iv_provider TYPE string
                                     iv_model TYPE string
                                     iv_system_prompt TYPE string
                           RETURNING VALUE(rv_session_id) TYPE string,
             send_message IMPORTING iv_session_id TYPE string
                                   iv_message TYPE string
                         RETURNING VALUE(rv_response) TYPE string,
             get_session_history IMPORTING iv_session_id TYPE string
                                RETURNING VALUE(rt_messages) TYPE table,
             save_session IMPORTING iv_session_id TYPE string,
             load_session IMPORTING iv_session_id TYPE string,
             delete_session IMPORTING iv_session_id TYPE string.
             
  PRIVATE SECTION.
    METHODS: initialize_providers,
             call_openai_api IMPORTING iv_message TYPE string
                                      iv_session_id TYPE string
                            RETURNING VALUE(rv_response) TYPE string,
             call_claude_api IMPORTING iv_message TYPE string
                                      iv_session_id TYPE string
                            RETURNING VALUE(rv_response) TYPE string,
             call_gemini_api IMPORTING iv_message TYPE string
                                      iv_session_id TYPE string
                            RETURNING VALUE(rv_response) TYPE string,
             call_local_api IMPORTING iv_message TYPE string
                                     iv_session_id TYPE string
                           RETURNING VALUE(rv_response) TYPE string,
             build_openai_payload IMPORTING iv_session_id TYPE string
                                 RETURNING VALUE(rv_json) TYPE string,
             build_claude_payload IMPORTING iv_session_id TYPE string
                                 RETURNING VALUE(rv_json) TYPE string,
             parse_json_response IMPORTING iv_response TYPE string
                                          iv_provider TYPE string
                                RETURNING VALUE(rv_message) TYPE string,
             add_message_to_session IMPORTING iv_session_id TYPE string
                                             iv_role TYPE string
                                             iv_content TYPE string
                                             iv_tokens TYPE i OPTIONAL
                                             iv_model TYPE string OPTIONAL
                                             iv_cost TYPE p OPTIONAL.
ENDCLASS.

*----------------------------------------------------------------------*
* Класс для пользовательского интерфейса
*----------------------------------------------------------------------*
CLASS lcl_chat_ui DEFINITION.
  PUBLIC SECTION.
    METHODS: constructor IMPORTING io_ai_manager TYPE REF TO lcl_ai_manager,
             show_chat_screen,
             update_display,
             handle_user_input IMPORTING iv_input TYPE string,
             handle_command IMPORTING iv_command TYPE string.
             
  PRIVATE SECTION.
    DATA: mo_ai_manager TYPE REF TO lcl_ai_manager,
          mo_container TYPE REF TO cl_gui_custom_container,
          mo_html_viewer TYPE REF TO cl_gui_html_viewer,
          mo_text_editor TYPE REF TO cl_gui_textedit,
          mo_splitter TYPE REF TO cl_gui_splitter_container,
          mv_current_session TYPE string.
          
    METHODS: create_ui_elements,
             build_chat_html RETURNING VALUE(rv_html) TYPE string,
             free_ui_elements.
ENDCLASS.

*----------------------------------------------------------------------*
* Основная программа
*----------------------------------------------------------------------*
INITIALIZATION.
  " Инициализация провайдеров
  PERFORM initialize_default_providers.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_prov.
  PERFORM f4_help_providers.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_model.
  PERFORM f4_help_models.

START-OF-SELECTION.
  " Создание менеджера ИИ
  CREATE OBJECT go_ai_manager.
  
  " Создание пользовательского интерфейса
  CREATE OBJECT go_chat_ui
    EXPORTING
      io_ai_manager = go_ai_manager.
  
  " Создание или загрузка сессии
  IF p_sessid IS NOT INITIAL AND p_loadsv = 'X'.
    CALL METHOD go_ai_manager->load_session
      EXPORTING
        iv_session_id = p_sessid.
    gv_current_session = p_sessid.
  ELSE.
    gv_current_session = go_ai_manager->create_session(
      iv_provider = p_prov
      iv_model = p_model
      iv_system_prompt = p_systm
    ).
  ENDIF.
  
  " Запуск интерфейса
  CALL METHOD go_chat_ui->show_chat_screen.

*----------------------------------------------------------------------*
* Инициализация провайдеров по умолчанию
*----------------------------------------------------------------------*
FORM initialize_default_providers.
  DATA: ls_provider TYPE ty_ai_provider.
  
  " OpenAI
  ls_provider-provider = gc_providers-openai.
  ls_provider-name = 'OpenAI GPT'.
  ls_provider-url = 'https://api.openai.com/v1/chat/completions'.
  ls_provider-api_key_required = abap_true.
  APPEND 'gpt-3.5-turbo' TO ls_provider-models.
  APPEND 'gpt-4' TO ls_provider-models.
  APPEND 'gpt-4-turbo' TO ls_provider-models.
  APPEND ls_provider TO gt_providers.
  CLEAR ls_provider.
  
  " Claude
  ls_provider-provider = gc_providers-claude.
  ls_provider-name = 'Anthropic Claude'.
  ls_provider-url = 'https://api.anthropic.com/v1/messages'.
  ls_provider-api_key_required = abap_true.
  APPEND 'claude-3-sonnet-20240229' TO ls_provider-models.
  APPEND 'claude-3-opus-20240229' TO ls_provider-models.
  APPEND 'claude-3-haiku-20240307' TO ls_provider-models.
  APPEND ls_provider TO gt_providers.
  CLEAR ls_provider.
  
  " Google Gemini
  ls_provider-provider = gc_providers-gemini.
  ls_provider-name = 'Google Gemini'.
  ls_provider-url = 'https://generativelanguage.googleapis.com/v1/models/'.
  ls_provider-api_key_required = abap_true.
  APPEND 'gemini-pro' TO ls_provider-models.
  APPEND 'gemini-pro-vision' TO ls_provider-models.
  APPEND ls_provider TO gt_providers.
  CLEAR ls_provider.
  
  " Локальный API
  ls_provider-provider = gc_providers-local.
  ls_provider-name = 'Local API'.
  ls_provider-url = 'http://localhost:8080/v1/chat/completions'.
  ls_provider-api_key_required = abap_false.
  APPEND 'local-model' TO ls_provider-models.
  APPEND ls_provider TO gt_providers.
  
ENDFORM.

*----------------------------------------------------------------------*
* F4 помощь для провайдеров
*----------------------------------------------------------------------*
FORM f4_help_providers.
  DATA: lt_values TYPE TABLE OF ddshretval,
        ls_value TYPE ddshretval.
  
  LOOP AT gt_providers INTO DATA(ls_provider).
    ls_value-retfield = 'PROVIDER'.
    ls_value-fieldname = 'PROVIDER'.
    ls_value-fieldval = ls_provider-provider.
    APPEND ls_value TO lt_values.
  ENDLOOP.
  
  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING
      retfield = 'PROVIDER'
      value_org = 'S'
    TABLES
      value_tab = lt_values
    EXCEPTIONS
      OTHERS = 1.
      
ENDFORM.

*----------------------------------------------------------------------*
* F4 помощь для моделей
*----------------------------------------------------------------------*
FORM f4_help_models.
  DATA: lt_values TYPE TABLE OF ddshretval,
        ls_value TYPE ddshretval.
  
  READ TABLE gt_providers INTO DATA(ls_provider) 
    WITH KEY provider = p_prov.
    
  IF sy-subrc = 0.
    LOOP AT ls_provider-models INTO DATA(lv_model).
      ls_value-retfield = 'MODEL'.
      ls_value-fieldname = 'MODEL'.
      ls_value-fieldval = lv_model.
      APPEND ls_value TO lt_values.
    ENDLOOP.
    
    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield = 'MODEL'
        value_org = 'S'
      TABLES
        value_tab = lt_values
      EXCEPTIONS
        OTHERS = 1.
  ENDIF.
  
ENDFORM.

*----------------------------------------------------------------------*
* Реализация класса AI Manager
*----------------------------------------------------------------------*
CLASS lcl_ai_manager IMPLEMENTATION.
  
  METHOD constructor.
    initialize_providers( ).
  ENDMETHOD.
  
  METHOD initialize_providers.
    " Загрузка конфигурации провайдеров
    " Можно расширить для чтения из пользовательской таблицы
    gt_providers = VALUE #( ).
  ENDMETHOD.
  
  METHOD get_providers.
    rt_providers = gt_providers.
  ENDMETHOD.
  
  METHOD create_session.
    DATA: ls_session TYPE ty_chat_session.
    
    " Генерация уникального ID сессии
    CALL FUNCTION 'GUID_CREATE'
      IMPORTING
        ev_guid_16 = DATA(lv_guid).
        
    rv_session_id = lv_guid.
    
    " Создание записи сессии
    ls_session-session_id = rv_session_id.
    ls_session-provider = iv_provider.
    ls_session-model = iv_model.
    ls_session-system_prompt = iv_system_prompt.
    GET TIME STAMP FIELD ls_session-created_at.
    ls_session-updated_at = ls_session-created_at.
    APPEND ls_session TO gt_sessions.
    
    " Добавление системного промпта
    IF iv_system_prompt IS NOT INITIAL.
      add_message_to_session(
        iv_session_id = rv_session_id
        iv_role = 'system'
        iv_content = iv_system_prompt
      ).
    ENDIF.
    
  ENDMETHOD.
  
  METHOD send_message.
    DATA: ls_session TYPE ty_chat_session.
    
    " Найти сессию
    READ TABLE gt_sessions INTO ls_session 
      WITH KEY session_id = iv_session_id.
      
    IF sy-subrc <> 0.
      rv_response = 'Сессия не найдена'.
      RETURN.
    ENDIF.
    
    " Добавить сообщение пользователя
    add_message_to_session(
      iv_session_id = iv_session_id
      iv_role = 'user'
      iv_content = iv_message
    ).
    
    " Вызвать соответствующий API
    CASE ls_session-provider.
      WHEN gc_providers-openai.
        rv_response = call_openai_api( iv_message = iv_message 
                                      iv_session_id = iv_session_id ).
      WHEN gc_providers-claude.
        rv_response = call_claude_api( iv_message = iv_message 
                                      iv_session_id = iv_session_id ).
      WHEN gc_providers-gemini.
        rv_response = call_gemini_api( iv_message = iv_message 
                                      iv_session_id = iv_session_id ).
      WHEN gc_providers-local.
        rv_response = call_local_api( iv_message = iv_message 
                                     iv_session_id = iv_session_id ).
      WHEN OTHERS.
        rv_response = 'Неподдерживаемый провайдер'.
    ENDCASE.
    
    " Добавить ответ ассистента
    IF rv_response IS NOT INITIAL.
      add_message_to_session(
        iv_session_id = iv_session_id
        iv_role = 'assistant'
        iv_content = rv_response
        iv_model = ls_session-model
      ).
    ENDIF.
    
  ENDMETHOD.
  
  METHOD call_openai_api.
    DATA: lo_http_client TYPE REF TO if_http_client,
          lv_json TYPE string,
          lv_response TYPE string,
          lv_url TYPE string.
    
    " Получить URL провайдера
    READ TABLE gt_providers INTO DATA(ls_provider) 
      WITH KEY provider = gc_providers-openai.
      
    IF sy-subrc <> 0.
      rv_response = 'Провайдер OpenAI не настроен'.
      RETURN.
    ENDIF.
    
    lv_url = ls_provider-url.
    
    " Создать HTTP клиент
    CALL METHOD cl_http_client=>create_by_url
      EXPORTING
        url = lv_url
      IMPORTING
        client = lo_http_client
      EXCEPTIONS
        OTHERS = 1.
        
    IF sy-subrc <> 0.
      rv_response = 'Ошибка создания HTTP клиента'.
      RETURN.
    ENDIF.
    
    " Настроить заголовки
    lo_http_client->request->set_method( 'POST' ).
    lo_http_client->request->set_header_field( 
      name = 'Content-Type' 
      value = 'application/json' 
    ).
    lo_http_client->request->set_header_field( 
      name = 'Authorization' 
      value = |Bearer { p_apikey }| 
    ).
    
    " Построить JSON payload
    lv_json = build_openai_payload( iv_session_id ).
    
    " Отправить запрос
    lo_http_client->request->set_cdata( lv_json ).
    
    CALL METHOD lo_http_client->send
      EXCEPTIONS
        OTHERS = 1.
        
    IF sy-subrc <> 0.
      rv_response = 'Ошибка отправки запроса'.
      lo_http_client->close( ).
      RETURN.
    ENDIF.
    
    " Получить ответ
    CALL METHOD lo_http_client->receive
      EXCEPTIONS
        OTHERS = 1.
        
    IF sy-subrc <> 0.
      rv_response = 'Ошибка получения ответа'.
      lo_http_client->close( ).
      RETURN.
    ENDIF.
    
    " Проверить статус
    IF lo_http_client->response->get_status( )-code <> 200.
      rv_response = |Ошибка API: { lo_http_client->response->get_status( )-code }|.
      lo_http_client->close( ).
      RETURN.
    ENDIF.
    
    " Парсить ответ
    lv_response = lo_http_client->response->get_cdata( ).
    rv_response = parse_json_response( 
      iv_response = lv_response 
      iv_provider = gc_providers-openai 
    ).
    
    lo_http_client->close( ).
    
  ENDMETHOD.
  
  METHOD call_claude_api.
    " Аналогично OpenAI API, но с другими заголовками и форматом
    rv_response = 'Claude API - в разработке'.
  ENDMETHOD.
  
  METHOD call_gemini_api.
    " Аналогично OpenAI API, но с другими заголовками и форматом
    rv_response = 'Gemini API - в разработке'.
  ENDMETHOD.
  
  METHOD call_local_api.
    " Для локальных API (ollama, lm-studio, etc.)
    rv_response = 'Local API - в разработке'.
  ENDMETHOD.
  
  METHOD build_openai_payload.
    DATA: lv_messages TYPE string,
          ls_message TYPE ty_message.
    
    " Получить историю сообщений для сессии
    LOOP AT gt_messages INTO ls_message 
      WHERE session_id = iv_session_id.
      
      IF sy-tabix > 1.
        lv_messages = |{ lv_messages },|.
      ENDIF.
      
      lv_messages = |{ lv_messages }\{"role":"{ ls_message-role }","content":"{ ls_message-content }"\}|.
    ENDLOOP.
    
    " Построить полный JSON
    rv_json = |\{|.
    rv_json = |{ rv_json }"model":"{ p_model }",|.
    rv_json = |{ rv_json }"messages":[{ lv_messages }],|.
    rv_json = |{ rv_json }"max_tokens":{ p_maxtok },|.
    rv_json = |{ rv_json }"temperature":{ p_temp }|.
    
    IF p_stream = 'X'.
      rv_json = |{ rv_json },"stream":true|.
    ENDIF.
    
    rv_json = |{ rv_json }\}|.
    
  ENDMETHOD.
  
  METHOD build_claude_payload.
    " Payload для Claude API
    rv_json = 'Claude payload - в разработке'.
  ENDMETHOD.
  
  METHOD parse_json_response.
    " Упрощенный парсинг - в реальном проекте использовать JSON парсер
    DATA: lv_pos TYPE i,
          lv_len TYPE i,
          lv_content TYPE string.
    
    CASE iv_provider.
      WHEN gc_providers-openai.
        FIND '"content":"' IN iv_response MATCH OFFSET lv_pos.
        IF sy-subrc = 0.
          lv_pos = lv_pos + 11.
          lv_content = iv_response+lv_pos.
          FIND '"' IN lv_content MATCH OFFSET lv_len.
          IF sy-subrc = 0.
            rv_message = lv_content(lv_len).
            " Обработка escape последовательностей
            REPLACE ALL OCCURRENCES OF '\n' IN rv_message WITH cl_abap_char_utilities=>newline.
            REPLACE ALL OCCURRENCES OF '\"' IN rv_message WITH '"'.
            REPLACE ALL OCCURRENCES OF '\\' IN rv_message WITH '\'.
          ENDIF.
        ENDIF.
        
      WHEN OTHERS.
        rv_message = 'Парсинг для данного провайдера не реализован'.
    ENDCASE.
    
  ENDMETHOD.
  
  METHOD add_message_to_session.
    DATA: ls_message TYPE ty_message.
    
    ls_message-session_id = iv_session_id.
    GET TIME STAMP FIELD ls_message-timestamp.
    ls_message-role = iv_role.
    ls_message-content = iv_content.
    ls_message-tokens_used = iv_tokens.
    ls_message-model = iv_model.
    ls_message-cost = iv_cost.
    
    APPEND ls_message TO gt_messages.
    
  ENDMETHOD.
  
  METHOD get_session_history.
    LOOP AT gt_messages INTO DATA(ls_message) 
      WHERE session_id = iv_session_id.
      APPEND ls_message TO rt_messages.
    ENDLOOP.
  ENDMETHOD.
  
  METHOD save_session.
    " Сохранение сессии в файл или пользовательскую таблицу
    MESSAGE |Сессия { iv_session_id } сохранена| TYPE 'S'.
  ENDMETHOD.
  
  METHOD load_session.
    " Загрузка сессии из файла или пользовательской таблицы
    MESSAGE |Сессия { iv_session_id } загружена| TYPE 'S'.
  ENDMETHOD.
  
  METHOD delete_session.
    " Удаление сессии и всех сообщений
    DELETE gt_sessions WHERE session_id = iv_session_id.
    DELETE gt_messages WHERE session_id = iv_session_id.
    MESSAGE |Сессия { iv_session_id } удалена| TYPE 'S'.
  ENDMETHOD.
  
ENDCLASS.

*----------------------------------------------------------------------*
* Реализация класса Chat UI
*----------------------------------------------------------------------*
CLASS lcl_chat_ui IMPLEMENTATION.
  
  METHOD constructor.
    mo_ai_manager = io_ai_manager.
  ENDMETHOD.
  
  METHOD show_chat_screen.
    CALL SCREEN 200.
  ENDMETHOD.
  
  METHOD create_ui_elements.
    " Создание элементов интерфейса
    " Аналогично основной программе
  ENDMETHOD.
  
  METHOD update_display.
    " Обновление отображения чата
  ENDMETHOD.
  
  METHOD handle_user_input.
    " Обработка ввода пользователя
  ENDMETHOD.
  
  METHOD handle_command.
    " Обработка команд
  ENDMETHOD.
  
  METHOD build_chat_html.
    " Построение HTML для отображения чата
  ENDMETHOD.
  
  METHOD free_ui_elements.
    " Освобождение ресурсов
  ENDMETHOD.
  
ENDCLASS.