*&---------------------------------------------------------------------*
*& Report ZSD_INVOICE_EDIT_V2
*&---------------------------------------------------------------------*
*& Исправленная версия программы для работы с сбытовыми фактурами
*&---------------------------------------------------------------------*
REPORT zsd_invoice_edit_v2.

*----------------------------------------------------------------------*
* Классы для обработки событий ALV
*----------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS: handle_data_changed FOR EVENT data_changed OF cl_gui_alv_grid
               IMPORTING er_data_changed,
             handle_toolbar FOR EVENT toolbar OF cl_gui_alv_grid
               IMPORTING e_object e_interactive,
             handle_user_command FOR EVENT user_command OF cl_gui_alv_grid
               IMPORTING e_ucomm.
ENDCLASS.

*----------------------------------------------------------------------*
* Объявление типов данных
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_invoice,
         vbeln     TYPE vbrk-vbeln,    " Номер документа биллинга
         fkdat     TYPE vbrk-fkdat,    " Дата выставления фактуры
         kunag     TYPE vbrk-kunag,    " Плательщик
         name1     TYPE kna1-name1,    " Наименование клиента
         netwr     TYPE vbrk-netwr,    " Чистая стоимость
         waerk     TYPE vbrk-waerk,    " Валюта
         vkorg     TYPE vbrk-vkorg,    " Сбытовая организация
         vtweg     TYPE vbrk-vtweg,    " Канал сбыта
         spart     TYPE vbrk-spart,    " Область сбыта
         fkart     TYPE vbrk-fkart,    " Тип документа биллинга
         fksto     TYPE vbrk-fksto,    " Отмененный документ
         sfakn     TYPE vbrk-sfakn,    " Аннулирующий документ
         knumv     TYPE vbrk-knumv,    " Номер документа условий
         cellcolor TYPE lvc_t_scol,    " Цвета ячеек для ALV
       END OF ty_invoice.

*----------------------------------------------------------------------*
* Глобальные переменные
*----------------------------------------------------------------------*
DATA: gt_invoice TYPE TABLE OF ty_invoice,
      gs_invoice TYPE ty_invoice,
      go_alv_grid TYPE REF TO cl_gui_alv_grid,
      go_container TYPE REF TO cl_gui_custom_container,
      go_event_handler TYPE REF TO lcl_event_handler,
      gt_fieldcat TYPE lvc_t_fcat,
      gs_fieldcat TYPE lvc_s_fcat,
      gs_layout TYPE lvc_s_layo,
      gs_variant TYPE disvariant,
      gv_okcode TYPE sy-ucomm.

*----------------------------------------------------------------------*
* Селекционный экран
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
SELECT-OPTIONS: s_vbeln FOR vbrk-vbeln,       " Номер фактуры
                s_fkdat FOR vbrk-fkdat,       " Дата фактуры
                s_kunag FOR vbrk-kunag,       " Плательщик
                s_vkorg FOR vbrk-vkorg,       " Сбытовая организация
                s_vtweg FOR vbrk-vtweg,       " Канал сбыта
                s_spart FOR vbrk-spart,       " Область сбыта
                s_fkart FOR vbrk-fkart.       " Тип документа
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_edit AS CHECKBOX DEFAULT 'X',   " Разрешить редактирование
            p_save AS CHECKBOX DEFAULT 'X'.   " Разрешить сохранение
SELECTION-SCREEN END OF BLOCK b2.

*----------------------------------------------------------------------*
* Инициализация
*----------------------------------------------------------------------*
INITIALIZATION.
  " Заполнение значений по умолчанию
  s_fkdat-sign = 'I'.
  s_fkdat-option = 'BT'.
  s_fkdat-low = sy-datum - 30.
  s_fkdat-high = sy-datum.
  APPEND s_fkdat.

*----------------------------------------------------------------------*
* Проверка введенных данных
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  IF s_vbeln[] IS INITIAL AND s_fkdat[] IS INITIAL AND s_kunag[] IS INITIAL.
    MESSAGE 'Укажите хотя бы один параметр отбора' TYPE 'E'.
  ENDIF.

*----------------------------------------------------------------------*
* Основная программа
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM get_invoice_data.
  CALL SCREEN 100.

*----------------------------------------------------------------------*
* Получение данных о фактурах
*----------------------------------------------------------------------*
FORM get_invoice_data.
  
  SELECT v~vbeln,
         v~fkdat,
         v~kunag,
         k~name1,
         v~netwr,
         v~waerk,
         v~vkorg,
         v~vtweg,
         v~spart,
         v~fkart,
         v~fksto,
         v~sfakn,
         v~knumv
    FROM vbrk AS v
    LEFT JOIN kna1 AS k ON v~kunag = k~kunnr
    INTO CORRESPONDING FIELDS OF TABLE gt_invoice
    WHERE v~vbeln IN s_vbeln
      AND v~fkdat IN s_fkdat
      AND v~kunag IN s_kunag
      AND v~vkorg IN s_vkorg
      AND v~vtweg IN s_vtweg
      AND v~spart IN s_spart
      AND v~fkart IN s_fkart
      AND v~fksto = ''              " Исключить отмененные
    ORDER BY v~fkdat DESCENDING, v~vbeln.

  IF sy-subrc <> 0.
    MESSAGE 'Данные не найдены по заданным критериям' TYPE 'I'.
    LEAVE LIST-PROCESSING.
  ENDIF.

  " Установка цветов для строк
  PERFORM set_row_colors.

ENDFORM.

*----------------------------------------------------------------------*
* Установка цветов строк
*----------------------------------------------------------------------*
FORM set_row_colors.
  DATA: ls_color TYPE lvc_s_scol.
  
  LOOP AT gt_invoice INTO gs_invoice.
    " Отмененные документы - красный цвет
    IF gs_invoice-fksto = 'X'.
      ls_color-fname = ''.
      ls_color-color-col = 6.  " Красный
      ls_color-color-int = 1.
      APPEND ls_color TO gs_invoice-cellcolor.
    ENDIF.
    
    " Нулевая сумма - желтый цвет
    IF gs_invoice-netwr = 0.
      ls_color-fname = 'NETWR'.
      ls_color-color-col = 3.  " Желтый
      ls_color-color-int = 1.
      APPEND ls_color TO gs_invoice-cellcolor.
    ENDIF.
    
    MODIFY gt_invoice FROM gs_invoice.
    CLEAR: gs_invoice, ls_color.
  ENDLOOP.
ENDFORM.

*----------------------------------------------------------------------*
* Логика экрана 100
*----------------------------------------------------------------------*
MODULE pbo_100 OUTPUT.
  SET PF-STATUS 'STANDARD'.
  SET TITLEBAR 'TITLE_100'.
  
  IF go_container IS INITIAL.
    PERFORM create_alv_grid.
  ENDIF.
ENDMODULE.

MODULE pai_100 INPUT.
  gv_okcode = sy-ucomm.
  CLEAR sy-ucomm.
  
  CASE gv_okcode.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      PERFORM free_alv_grid.
      LEAVE TO SCREEN 0.
    WHEN 'SAVE'.
      PERFORM save_changes.
    WHEN 'EXPORT'.
      PERFORM export_to_excel.
  ENDCASE.
ENDMODULE.

*----------------------------------------------------------------------*
* Создание ALV Grid
*----------------------------------------------------------------------*
FORM create_alv_grid.
  
  " Создание контейнера
  CREATE OBJECT go_container
    EXPORTING
      container_name = 'CONTAINER'
    EXCEPTIONS
      cntl_error = 1
      cntl_system_error = 2
      create_error = 3
      lifetime_error = 4
      lifetime_dynpro_dynpro_link = 5
      OTHERS = 6.
      
  IF sy-subrc <> 0.
    MESSAGE 'Ошибка создания контейнера' TYPE 'E'.
  ENDIF.

  " Создание ALV Grid
  CREATE OBJECT go_alv_grid
    EXPORTING
      i_parent = go_container
    EXCEPTIONS
      error_cntl_create = 1
      error_cntl_init = 2
      error_cntl_link = 3
      error_dp_create = 4
      OTHERS = 5.
      
  IF sy-subrc <> 0.
    MESSAGE 'Ошибка создания ALV Grid' TYPE 'E'.
  ENDIF.

  " Настройка каталога полей
  PERFORM build_fieldcat.
  
  " Настройка макета
  PERFORM build_layout.
  
  " Настройка варианта
  gs_variant-report = sy-repid.
  gs_variant-username = sy-uname.

  " Создание обработчика событий
  CREATE OBJECT go_event_handler.

  " Регистрация событий
  SET HANDLER go_event_handler->handle_data_changed FOR go_alv_grid.
  SET HANDLER go_event_handler->handle_toolbar FOR go_alv_grid.
  SET HANDLER go_event_handler->handle_user_command FOR go_alv_grid.

  " Отображение данных
  CALL METHOD go_alv_grid->set_table_for_first_display
    EXPORTING
      is_layout                     = gs_layout
      is_variant                    = gs_variant
      i_save                        = 'A'
      i_default                     = 'X'
    CHANGING
      it_outtab                     = gt_invoice
      it_fieldcatalog               = gt_fieldcat
    EXCEPTIONS
      invalid_parameter_combination = 1
      program_error                 = 2
      too_many_lines                = 3
      OTHERS                        = 4.

  IF sy-subrc <> 0.
    MESSAGE 'Ошибка отображения ALV' TYPE 'E'.
  ENDIF.

ENDFORM.

*----------------------------------------------------------------------*
* Освобождение ресурсов ALV
*----------------------------------------------------------------------*
FORM free_alv_grid.
  IF go_alv_grid IS NOT INITIAL.
    CALL METHOD go_alv_grid->free.
    CLEAR go_alv_grid.
  ENDIF.
  
  IF go_container IS NOT INITIAL.
    CALL METHOD go_container->free.
    CLEAR go_container.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* Создание каталога полей
*----------------------------------------------------------------------*
FORM build_fieldcat.
  
  " Номер документа
  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'VBELN'.
  gs_fieldcat-ref_table = 'VBRK'.
  gs_fieldcat-ref_field = 'VBELN'.
  gs_fieldcat-coltext = 'Номер фактуры'.
  gs_fieldcat-outputlen = 10.
  gs_fieldcat-key = 'X'.
  APPEND gs_fieldcat TO gt_fieldcat.

  " Дата фактуры
  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'FKDAT'.
  gs_fieldcat-ref_table = 'VBRK'.
  gs_fieldcat-ref_field = 'FKDAT'.
  gs_fieldcat-coltext = 'Дата фактуры'.
  gs_fieldcat-outputlen = 10.
  gs_fieldcat-edit = p_edit.
  APPEND gs_fieldcat TO gt_fieldcat.

  " Плательщик
  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'KUNAG'.
  gs_fieldcat-ref_table = 'VBRK'.
  gs_fieldcat-ref_field = 'KUNAG'.
  gs_fieldcat-coltext = 'Плательщик'.
  gs_fieldcat-outputlen = 10.
  gs_fieldcat-edit = p_edit.
  APPEND gs_fieldcat TO gt_fieldcat.

  " Наименование клиента
  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'NAME1'.
  gs_fieldcat-ref_table = 'KNA1'.
  gs_fieldcat-ref_field = 'NAME1'.
  gs_fieldcat-coltext = 'Наименование'.
  gs_fieldcat-outputlen = 35.
  APPEND gs_fieldcat TO gt_fieldcat.

  " Сумма
  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'NETWR'.
  gs_fieldcat-ref_table = 'VBRK'.
  gs_fieldcat-ref_field = 'NETWR'.
  gs_fieldcat-coltext = 'Сумма'.
  gs_fieldcat-outputlen = 15.
  gs_fieldcat-edit = p_edit.
  gs_fieldcat-do_sum = 'X'.
  APPEND gs_fieldcat TO gt_fieldcat.

  " Валюта
  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'WAERK'.
  gs_fieldcat-ref_table = 'VBRK'.
  gs_fieldcat-ref_field = 'WAERK'.
  gs_fieldcat-coltext = 'Валюта'.
  gs_fieldcat-outputlen = 5.
  gs_fieldcat-edit = p_edit.
  APPEND gs_fieldcat TO gt_fieldcat.

  " Сбытовая организация
  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'VKORG'.
  gs_fieldcat-ref_table = 'VBRK'.
  gs_fieldcat-ref_field = 'VKORG'.
  gs_fieldcat-coltext = 'Сбыт.орг'.
  gs_fieldcat-outputlen = 8.
  gs_fieldcat-edit = p_edit.
  APPEND gs_fieldcat TO gt_fieldcat.

  " Канал сбыта
  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'VTWEG'.
  gs_fieldcat-ref_table = 'VBRK'.
  gs_fieldcat-ref_field = 'VTWEG'.
  gs_fieldcat-coltext = 'Канал'.
  gs_fieldcat-outputlen = 6.
  gs_fieldcat-edit = p_edit.
  APPEND gs_fieldcat TO gt_fieldcat.

  " Область сбыта
  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'SPART'.
  gs_fieldcat-ref_table = 'VBRK'.
  gs_fieldcat-ref_field = 'SPART'.
  gs_fieldcat-coltext = 'Область'.
  gs_fieldcat-outputlen = 6.
  gs_fieldcat-edit = p_edit.
  APPEND gs_fieldcat TO gt_fieldcat.

  " Тип документа
  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'FKART'.
  gs_fieldcat-ref_table = 'VBRK'.
  gs_fieldcat-ref_field = 'FKART'.
  gs_fieldcat-coltext = 'Тип док.'.
  gs_fieldcat-outputlen = 8.
  gs_fieldcat-edit = p_edit.
  APPEND gs_fieldcat TO gt_fieldcat.

ENDFORM.

*----------------------------------------------------------------------*
* Создание макета
*----------------------------------------------------------------------*
FORM build_layout.
  gs_layout-cwidth_opt = 'X'.      " Оптимизация ширины колонок
  gs_layout-zebra = 'X'.           " Зебра-раскраска
  gs_layout-sel_mode = 'D'.        " Режим выбора строк
  gs_layout-coll_end_l = 'X'.      " Конец коллекции слева
  gs_layout-stylefname = 'CELLCOLOR'. " Поле со стилями
  
  IF p_edit = 'X'.
    gs_layout-edit = 'X'.          " Разрешить редактирование
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* Сохранение изменений
*----------------------------------------------------------------------*
FORM save_changes.
  DATA: lv_answer TYPE char1.

  " Подтверждение сохранения
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      text_question = 'Сохранить изменения?'
      text_button_1 = 'Да'
      text_button_2 = 'Нет'
    IMPORTING
      answer = lv_answer.

  IF lv_answer = '1'.
    " Здесь можно добавить логику сохранения в базу данных
    MESSAGE 'Данные сохранены' TYPE 'S'.
  ENDIF.

ENDFORM.

*----------------------------------------------------------------------*
* Экспорт в Excel
*----------------------------------------------------------------------*
FORM export_to_excel.
  CALL METHOD go_alv_grid->export_to_excel.
ENDFORM.

*----------------------------------------------------------------------*
* Реализация класса обработки событий
*----------------------------------------------------------------------*
CLASS lcl_event_handler IMPLEMENTATION.
  
  METHOD handle_data_changed.
    DATA: ls_mod_cell TYPE lvc_s_modi,
          lv_value TYPE string.

    " Проверка измененных ячеек
    LOOP AT er_data_changed->mt_mod_cells INTO ls_mod_cell.
      
      " Валидация данных
      CASE ls_mod_cell-fieldname.
        WHEN 'KUNAG'.
          " Проверка существования клиента
          SELECT SINGLE kunnr FROM kna1 INTO lv_value
            WHERE kunnr = ls_mod_cell-value.
          IF sy-subrc <> 0.
            MESSAGE 'Клиент не найден' TYPE 'E'.
          ENDIF.
          
        WHEN 'NETWR'.
          " Проверка корректности суммы
          IF ls_mod_cell-value < 0.
            MESSAGE 'Сумма не может быть отрицательной' TYPE 'E'.
          ENDIF.
          
        WHEN 'FKDAT'.
          " Проверка даты
          IF ls_mod_cell-value > sy-datum.
            MESSAGE 'Дата не может быть больше текущей' TYPE 'E'.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    " Обновление данных
    CALL METHOD go_alv_grid->refresh_table_display.
  ENDMETHOD.

  METHOD handle_toolbar.
    DATA: ls_toolbar TYPE stb_button.

    " Добавление кнопки сохранения
    IF p_save = 'X'.
      CLEAR ls_toolbar.
      ls_toolbar-function = 'SAVE'.
      ls_toolbar-icon = '@2L@'.
      ls_toolbar-text = 'Сохранить'.
      ls_toolbar-quickinfo = 'Сохранить изменения'.
      ls_toolbar-disabled = ''.
      APPEND ls_toolbar TO e_object->mt_toolbar.
    ENDIF.

    " Добавление кнопки экспорта
    CLEAR ls_toolbar.
    ls_toolbar-function = 'EXPORT'.
    ls_toolbar-icon = '@1A@'.
    ls_toolbar-text = 'Экспорт'.
    ls_toolbar-quickinfo = 'Экспорт в Excel'.
    ls_toolbar-disabled = ''.
    APPEND ls_toolbar TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD handle_user_command.
    CASE e_ucomm.
      WHEN 'SAVE'.
        PERFORM save_changes.
      WHEN 'EXPORT'.
        PERFORM export_to_excel.
    ENDCASE.
  ENDMETHOD.
  
ENDCLASS.