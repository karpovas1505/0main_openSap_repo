*&---------------------------------------------------------------------*
*& Report ZAI_CHAT
*&---------------------------------------------------------------------*
*& Программа для чата с ИИ моделью
*&---------------------------------------------------------------------*
REPORT zai_chat.

*----------------------------------------------------------------------*
* Типы данных
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_chat_message,
         timestamp TYPE timestampl,
         user_type TYPE char1,     " U - User, A - Assistant
         message   TYPE string,
         tokens    TYPE i,
         model     TYPE string,
       END OF ty_chat_message.

TYPES: tt_chat_history TYPE TABLE OF ty_chat_message.

*----------------------------------------------------------------------*
* Глобальные переменные
*----------------------------------------------------------------------*
DATA: gt_chat_history TYPE tt_chat_history,
      gs_chat_message TYPE ty_chat_message,
      go_ai_client TYPE REF TO lcl_ai_client,
      go_container TYPE REF TO cl_gui_custom_container,
      go_html_viewer TYPE REF TO cl_gui_html_viewer,
      go_textedit TYPE REF TO cl_gui_textedit,
      go_splitter TYPE REF TO cl_gui_splitter_container,
      go_container_top TYPE REF TO cl_gui_container,
      go_container_bottom TYPE REF TO cl_gui_container,
      gv_user_input TYPE string,
      gv_html_content TYPE string,
      gv_okcode TYPE sy-ucomm.

*----------------------------------------------------------------------*
* Константы
*----------------------------------------------------------------------*
CONSTANTS: gc_openai_url TYPE string VALUE 'https://api.openai.com/v1/chat/completions',
           gc_model_gpt35 TYPE string VALUE 'gpt-3.5-turbo',
           gc_model_gpt4 TYPE string VALUE 'gpt-4',
           gc_max_tokens TYPE i VALUE 2000.

*----------------------------------------------------------------------*
* Селекционный экран
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_apikey TYPE string OBLIGATORY LOWER CASE,
            p_model TYPE string DEFAULT gc_model_gpt35,
            p_maxtok TYPE i DEFAULT 1000,
            p_temp TYPE p DECIMALS 2 DEFAULT '0.7'.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_syspmt TYPE string LOWER CASE 
            DEFAULT 'Ты helpful assistant. Отвечай на русском языке, если вопрос на русском.',
            p_save AS CHECKBOX DEFAULT 'X',
            p_clear AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b2.

*----------------------------------------------------------------------*
* Класс для работы с ИИ API
*----------------------------------------------------------------------*
CLASS lcl_ai_client DEFINITION.
  PUBLIC SECTION.
    METHODS: constructor IMPORTING iv_api_key TYPE string
                                  iv_model TYPE string
                                  iv_max_tokens TYPE i
                                  iv_temperature TYPE p
                                  iv_system_prompt TYPE string,
             send_message IMPORTING iv_message TYPE string
                         RETURNING VALUE(rv_response) TYPE string,
             get_chat_history RETURNING VALUE(rt_history) TYPE tt_chat_history,
             clear_history,
             set_system_prompt IMPORTING iv_prompt TYPE string.
             
  PRIVATE SECTION.
    DATA: mv_api_key TYPE string,
          mv_model TYPE string,
          mv_max_tokens TYPE i,
          mv_temperature TYPE p,
          mv_system_prompt TYPE string,
          mt_chat_history TYPE tt_chat_history.
          
    METHODS: build_request_json IMPORTING iv_message TYPE string
                               RETURNING VALUE(rv_json) TYPE string,
             parse_response IMPORTING iv_response TYPE string
                           RETURNING VALUE(rv_message) TYPE string,
             add_to_history IMPORTING iv_user_type TYPE char1
                                     iv_message TYPE string
                                     iv_tokens TYPE i OPTIONAL
                                     iv_model TYPE string OPTIONAL.
ENDCLASS.

*----------------------------------------------------------------------*
* Основная программа
*----------------------------------------------------------------------*
START-OF-SELECTION.
  " Проверка параметров
  IF p_apikey IS INITIAL.
    MESSAGE 'Укажите API ключ' TYPE 'E'.
  ENDIF.
  
  " Очистка истории если требуется
  IF p_clear = 'X'.
    CLEAR gt_chat_history.
  ENDIF.
  
  " Создание клиента ИИ
  CREATE OBJECT go_ai_client
    EXPORTING
      iv_api_key = p_apikey
      iv_model = p_model
      iv_max_tokens = p_maxtok
      iv_temperature = p_temp
      iv_system_prompt = p_syspmt.
  
  " Запуск интерфейса чата
  CALL SCREEN 100.

*----------------------------------------------------------------------*
* Экран 100 - Основной экран чата
*----------------------------------------------------------------------*
MODULE pbo_100 OUTPUT.
  SET PF-STATUS 'STANDARD'.
  SET TITLEBAR 'TITLE_100'.
  
  IF go_container IS INITIAL.
    PERFORM create_chat_interface.
  ENDIF.
  
  PERFORM update_chat_display.
ENDMODULE.

MODULE pai_100 INPUT.
  gv_okcode = sy-ucomm.
  CLEAR sy-ucomm.
  
  CASE gv_okcode.
    WHEN 'SEND'.
      PERFORM send_message.
    WHEN 'CLEAR'.
      PERFORM clear_chat.
    WHEN 'SAVE'.
      PERFORM save_chat_history.
    WHEN 'LOAD'.
      PERFORM load_chat_history.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      PERFORM free_objects.
      LEAVE TO SCREEN 0.
  ENDCASE.
ENDMODULE.

*----------------------------------------------------------------------*
* Создание интерфейса чата
*----------------------------------------------------------------------*
FORM create_chat_interface.
  
  " Создание основного контейнера
  CREATE OBJECT go_container
    EXPORTING
      container_name = 'CHAT_CONTAINER'
    EXCEPTIONS
      OTHERS = 1.
      
  IF sy-subrc <> 0.
    MESSAGE 'Ошибка создания контейнера' TYPE 'E'.
  ENDIF.
  
  " Создание разделителя
  CREATE OBJECT go_splitter
    EXPORTING
      parent = go_container
      rows = 2
      columns = 1
    EXCEPTIONS
      OTHERS = 1.
      
  " Получение контейнеров
  CALL METHOD go_splitter->get_container
    EXPORTING
      row = 1
      column = 1
    RECEIVING
      container = go_container_top.
      
  CALL METHOD go_splitter->get_container
    EXPORTING
      row = 2
      column = 1
    RECEIVING
      container = go_container_bottom.
      
  " Настройка размеров (70% для истории, 30% для ввода)
  CALL METHOD go_splitter->set_row_height
    EXPORTING
      id = 1
      height = 70.
      
  " Создание HTML Viewer для истории чата
  CREATE OBJECT go_html_viewer
    EXPORTING
      parent = go_container_top
    EXCEPTIONS
      OTHERS = 1.
      
  " Создание текстового редактора для ввода
  CREATE OBJECT go_textedit
    EXPORTING
      parent = go_container_bottom
      wordwrap_mode = cl_gui_textedit=>wordwrap_at_windowborder
    EXCEPTIONS
      OTHERS = 1.
      
  " Настройка текстового редактора
  CALL METHOD go_textedit->set_toolbar_mode
    EXPORTING
      toolbar_mode = cl_gui_textedit=>false.
      
  " Установка обработчика событий для Enter
  SET HANDLER handle_textedit_event FOR go_textedit.
  
ENDFORM.

*----------------------------------------------------------------------*
* Обработка события текстового редактора
*----------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS: handle_textedit_event FOR EVENT sapevent OF cl_gui_textedit
               IMPORTING action.
ENDCLASS.

CLASS lcl_event_handler IMPLEMENTATION.
  METHOD handle_textedit_event.
    IF action = 'ENTER'.
      PERFORM send_message.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

DATA: go_event_handler TYPE REF TO lcl_event_handler.

*----------------------------------------------------------------------*
* Обновление отображения чата
*----------------------------------------------------------------------*
FORM update_chat_display.
  DATA: lv_html TYPE string,
        ls_message TYPE ty_chat_message,
        lv_timestamp TYPE string,
        lv_user_class TYPE string,
        lv_message_html TYPE string.
  
  " Начало HTML
  lv_html = |<html><head><style>|.
  lv_html = |{ lv_html }body \{ font-family: Arial, sans-serif; margin: 10px; background-color: #f5f5f5; \}|.
  lv_html = |{ lv_html }.message \{ margin: 10px 0; padding: 10px; border-radius: 8px; \}|.
  lv_html = |{ lv_html }.user \{ background-color: #007bff; color: white; text-align: right; \}|.
  lv_html = |{ lv_html }.assistant \{ background-color: #e9ecef; color: #333; \}|.
  lv_html = |{ lv_html }.timestamp \{ font-size: 12px; color: #666; margin-bottom: 5px; \}|.
  lv_html = |{ lv_html }.model-info \{ font-size: 11px; color: #888; margin-top: 5px; \}|.
  lv_html = |{ lv_html }</style></head><body>|.
  
  " Добавление сообщений
  LOOP AT gt_chat_history INTO ls_message.
    " Форматирование времени
    lv_timestamp = |{ ls_message-timestamp TIMESTAMP = USER }|.
    
    " Определение класса CSS
    IF ls_message-user_type = 'U'.
      lv_user_class = 'user'.
    ELSE.
      lv_user_class = 'assistant'.
    ENDIF.
    
    " Экранирование HTML
    lv_message_html = ls_message-message.
    REPLACE ALL OCCURRENCES OF '<' IN lv_message_html WITH '&lt;'.
    REPLACE ALL OCCURRENCES OF '>' IN lv_message_html WITH '&gt;'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_message_html WITH '<br>'.
    
    " Добавление сообщения
    lv_html = |{ lv_html }<div class="message { lv_user_class }">|.
    lv_html = |{ lv_html }<div class="timestamp">{ lv_timestamp }</div>|.
    lv_html = |{ lv_html }<div>{ lv_message_html }</div>|.
    
    " Добавление информации о модели для ответов ИИ
    IF ls_message-user_type = 'A' AND ls_message-model IS NOT INITIAL.
      lv_html = |{ lv_html }<div class="model-info">Model: { ls_message-model }|.
      IF ls_message-tokens > 0.
        lv_html = |{ lv_html }, Tokens: { ls_message-tokens }|.
      ENDIF.
      lv_html = |{ lv_html }</div>|.
    ENDIF.
    
    lv_html = |{ lv_html }</div>|.
  ENDLOOP.
  
  " Завершение HTML
  lv_html = |{ lv_html }</body></html>|.
  
  " Отображение HTML
  CALL METHOD go_html_viewer->load_data
    EXPORTING
      type = 'text'
      subtype = 'html'
    IMPORTING
      assigned_url = DATA(lv_url)
    CHANGING
      data_table = VALUE lvc_t_char1024( ( lv_html ) )
    EXCEPTIONS
      OTHERS = 1.
      
  CALL METHOD go_html_viewer->show_url
    EXPORTING
      url = lv_url
    EXCEPTIONS
      OTHERS = 1.
      
  " Прокрутка вниз
  CALL METHOD go_html_viewer->go_end.
  
ENDFORM.

*----------------------------------------------------------------------*
* Отправка сообщения
*----------------------------------------------------------------------*
FORM send_message.
  DATA: lv_text TYPE string,
        lv_response TYPE string.
  
  " Получение текста от пользователя
  CALL METHOD go_textedit->get_text
    IMPORTING
      text = lv_text
    EXCEPTIONS
      OTHERS = 1.
      
  " Удаление пробелов
  lv_text = condense( lv_text ).
  
  IF lv_text IS NOT INITIAL.
    " Добавление сообщения пользователя в историю
    CLEAR gs_chat_message.
    GET TIME STAMP FIELD gs_chat_message-timestamp.
    gs_chat_message-user_type = 'U'.
    gs_chat_message-message = lv_text.
    APPEND gs_chat_message TO gt_chat_history.
    
    " Отправка к ИИ
    lv_response = go_ai_client->send_message( lv_text ).
    
    " Добавление ответа ИИ в историю
    IF lv_response IS NOT INITIAL.
      CLEAR gs_chat_message.
      GET TIME STAMP FIELD gs_chat_message-timestamp.
      gs_chat_message-user_type = 'A'.
      gs_chat_message-message = lv_response.
      gs_chat_message-model = p_model.
      APPEND gs_chat_message TO gt_chat_history.
    ENDIF.
    
    " Очистка поля ввода
    CALL METHOD go_textedit->set_text
      EXPORTING
        text = ''
      EXCEPTIONS
        OTHERS = 1.
        
    " Обновление отображения
    PERFORM update_chat_display.
  ENDIF.
  
ENDFORM.

*----------------------------------------------------------------------*
* Очистка чата
*----------------------------------------------------------------------*
FORM clear_chat.
  DATA: lv_answer TYPE char1.
  
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      text_question = 'Очистить историю чата?'
      text_button_1 = 'Да'
      text_button_2 = 'Нет'
    IMPORTING
      answer = lv_answer.
      
  IF lv_answer = '1'.
    CLEAR gt_chat_history.
    CALL METHOD go_ai_client->clear_history.
    PERFORM update_chat_display.
    MESSAGE 'История чата очищена' TYPE 'S'.
  ENDIF.
  
ENDFORM.

*----------------------------------------------------------------------*
* Сохранение истории чата
*----------------------------------------------------------------------*
FORM save_chat_history.
  " Здесь можно добавить логику сохранения в файл или таблицу
  MESSAGE 'Функция сохранения в разработке' TYPE 'I'.
ENDFORM.

*----------------------------------------------------------------------*
* Загрузка истории чата
*----------------------------------------------------------------------*
FORM load_chat_history.
  " Здесь можно добавить логику загрузки из файла или таблицы
  MESSAGE 'Функция загрузки в разработке' TYPE 'I'.
ENDFORM.

*----------------------------------------------------------------------*
* Освобождение объектов
*----------------------------------------------------------------------*
FORM free_objects.
  IF go_html_viewer IS NOT INITIAL.
    CALL METHOD go_html_viewer->free.
    CLEAR go_html_viewer.
  ENDIF.
  
  IF go_textedit IS NOT INITIAL.
    CALL METHOD go_textedit->free.
    CLEAR go_textedit.
  ENDIF.
  
  IF go_splitter IS NOT INITIAL.
    CALL METHOD go_splitter->free.
    CLEAR go_splitter.
  ENDIF.
  
  IF go_container IS NOT INITIAL.
    CALL METHOD go_container->free.
    CLEAR go_container.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* Реализация класса для работы с ИИ
*----------------------------------------------------------------------*
CLASS lcl_ai_client IMPLEMENTATION.
  
  METHOD constructor.
    mv_api_key = iv_api_key.
    mv_model = iv_model.
    mv_max_tokens = iv_max_tokens.
    mv_temperature = iv_temperature.
    mv_system_prompt = iv_system_prompt.
    
    " Добавление системного промпта в историю
    IF mv_system_prompt IS NOT INITIAL.
      add_to_history( iv_user_type = 'S' iv_message = mv_system_prompt ).
    ENDIF.
  ENDMETHOD.
  
  METHOD send_message.
    DATA: lo_http_client TYPE REF TO if_http_client,
          lv_request_json TYPE string,
          lv_response_text TYPE string,
          lv_status_code TYPE i.
    
    " Добавление сообщения пользователя в историю
    add_to_history( iv_user_type = 'U' iv_message = iv_message ).
    
    " Создание HTTP клиента
    CALL METHOD cl_http_client=>create_by_url
      EXPORTING
        url = gc_openai_url
      IMPORTING
        client = lo_http_client
      EXCEPTIONS
        OTHERS = 1.
        
    IF sy-subrc <> 0.
      rv_response = 'Ошибка создания HTTP клиента'.
      RETURN.
    ENDIF.
    
    " Настройка запроса
    lo_http_client->request->set_method( 'POST' ).
    lo_http_client->request->set_header_field( 
      name = 'Content-Type' 
      value = 'application/json' 
    ).
    lo_http_client->request->set_header_field( 
      name = 'Authorization' 
      value = |Bearer { mv_api_key }| 
    ).
    
    " Формирование JSON запроса
    lv_request_json = build_request_json( iv_message ).
    
    " Установка данных запроса
    lo_http_client->request->set_cdata( lv_request_json ).
    
    " Отправка запроса
    CALL METHOD lo_http_client->send
      EXCEPTIONS
        OTHERS = 1.
        
    IF sy-subrc <> 0.
      rv_response = 'Ошибка отправки запроса'.
      lo_http_client->close( ).
      RETURN.
    ENDIF.
    
    " Получение ответа
    CALL METHOD lo_http_client->receive
      EXCEPTIONS
        OTHERS = 1.
        
    IF sy-subrc <> 0.
      rv_response = 'Ошибка получения ответа'.
      lo_http_client->close( ).
      RETURN.
    ENDIF.
    
    " Проверка статуса
    lv_status_code = lo_http_client->response->get_status( )-code.
    
    IF lv_status_code <> 200.
      rv_response = |Ошибка API: { lv_status_code }|.
      lo_http_client->close( ).
      RETURN.
    ENDIF.
    
    " Получение текста ответа
    lv_response_text = lo_http_client->response->get_cdata( ).
    
    " Парсинг ответа
    rv_response = parse_response( lv_response_text ).
    
    " Добавление ответа в историю
    add_to_history( 
      iv_user_type = 'A' 
      iv_message = rv_response 
      iv_model = mv_model 
    ).
    
    " Закрытие соединения
    lo_http_client->close( ).
    
  ENDMETHOD.
  
  METHOD build_request_json.
    DATA: lv_messages TYPE string,
          ls_message TYPE ty_chat_message.
    
    " Формирование массива сообщений
    lv_messages = '['.
    
    LOOP AT mt_chat_history INTO ls_message.
      IF sy-tabix > 1.
        lv_messages = |{ lv_messages },|.
      ENDIF.
      
      " Определение роли
      CASE ls_message-user_type.
        WHEN 'S'.
          lv_messages = |{ lv_messages }\{"role":"system","content":"{ ls_message-message }"\}|.
        WHEN 'U'.
          lv_messages = |{ lv_messages }\{"role":"user","content":"{ ls_message-message }"\}|.
        WHEN 'A'.
          lv_messages = |{ lv_messages }\{"role":"assistant","content":"{ ls_message-message }"\}|.
      ENDCASE.
    ENDLOOP.
    
    lv_messages = |{ lv_messages }]|.
    
    " Формирование полного JSON запроса
    rv_json = |\{|.
    rv_json = |{ rv_json }"model":"{ mv_model }",|.
    rv_json = |{ rv_json }"messages":{ lv_messages },|.
    rv_json = |{ rv_json }"max_tokens":{ mv_max_tokens },|.
    rv_json = |{ rv_json }"temperature":{ mv_temperature }|.
    rv_json = |{ rv_json }\}|.
    
  ENDMETHOD.
  
  METHOD parse_response.
    " Упрощенный парсинг JSON ответа
    " В реальном проекте лучше использовать JSON парсер
    
    DATA: lv_pos TYPE i,
          lv_len TYPE i,
          lv_content TYPE string.
    
    " Поиск содержимого сообщения
    FIND '"content":"' IN iv_response MATCH OFFSET lv_pos.
    
    IF sy-subrc = 0.
      lv_pos = lv_pos + 11. " Длина '"content":"'
      lv_content = iv_response+lv_pos.
      
      " Поиск конца сообщения
      FIND '"' IN lv_content MATCH OFFSET lv_len.
      
      IF sy-subrc = 0.
        rv_message = lv_content(lv_len).
        
        " Обработка escape последовательностей
        REPLACE ALL OCCURRENCES OF '\n' IN rv_message WITH cl_abap_char_utilities=>newline.
        REPLACE ALL OCCURRENCES OF '\t' IN rv_message WITH cl_abap_char_utilities=>horizontal_tab.
        REPLACE ALL OCCURRENCES OF '\"' IN rv_message WITH '"'.
        REPLACE ALL OCCURRENCES OF '\\' IN rv_message WITH '\'.
      ELSE.
        rv_message = 'Ошибка парсинга ответа'.
      ENDIF.
    ELSE.
      rv_message = 'Ошибка: не найдено содержимое в ответе'.
    ENDIF.
    
  ENDMETHOD.
  
  METHOD add_to_history.
    CLEAR gs_chat_message.
    GET TIME STAMP FIELD gs_chat_message-timestamp.
    gs_chat_message-user_type = iv_user_type.
    gs_chat_message-message = iv_message.
    gs_chat_message-tokens = iv_tokens.
    gs_chat_message-model = iv_model.
    APPEND gs_chat_message TO mt_chat_history.
  ENDMETHOD.
  
  METHOD get_chat_history.
    rt_history = mt_chat_history.
  ENDMETHOD.
  
  METHOD clear_history.
    CLEAR mt_chat_history.
    
    " Восстановление системного промпта
    IF mv_system_prompt IS NOT INITIAL.
      add_to_history( iv_user_type = 'S' iv_message = mv_system_prompt ).
    ENDIF.
  ENDMETHOD.
  
  METHOD set_system_prompt.
    mv_system_prompt = iv_prompt.
  ENDMETHOD.
  
ENDCLASS.