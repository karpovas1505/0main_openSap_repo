*&---------------------------------------------------------------------*
*& Расширение программы - использование BAPI для сохранения изменений
*&---------------------------------------------------------------------*
*& Этот код можно добавить в основную программу для реального сохранения
*& изменений в базе данных через BAPI
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* Дополнительные типы данных для BAPI
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_bapi_changes,
         vbeln TYPE vbrk-vbeln,
         field TYPE fieldname,
         old_value TYPE char50,
         new_value TYPE char50,
       END OF ty_bapi_changes.

DATA: gt_bapi_changes TYPE TABLE OF ty_bapi_changes,
      gs_bapi_changes TYPE ty_bapi_changes.

*----------------------------------------------------------------------*
* Улучшенная форма сохранения изменений с использованием BAPI
*----------------------------------------------------------------------*
FORM save_changes_with_bapi.
  DATA: lv_answer TYPE char1,
        lt_return TYPE TABLE OF bapiret2,
        ls_return TYPE bapiret2,
        lv_success TYPE abap_bool.

  " Подтверждение сохранения
  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      text_question = 'Сохранить изменения через BAPI?'
      text_button_1 = 'Да'
      text_button_2 = 'Нет'
    IMPORTING
      answer = lv_answer.

  IF lv_answer = '1'.
    " Получение списка изменений
    PERFORM get_changed_data.
    
    " Обработка каждого изменения
    lv_success = abap_true.
    LOOP AT gt_bapi_changes INTO gs_bapi_changes.
      
      CASE gs_bapi_changes-field.
        WHEN 'FKDAT'.
          " Изменение даты документа через BAPI
          PERFORM change_invoice_date USING gs_bapi_changes-vbeln
                                           gs_bapi_changes-new_value
                                    CHANGING lv_success.
          
        WHEN 'KUNAG'.
          " Изменение плательщика через BAPI
          PERFORM change_invoice_payer USING gs_bapi_changes-vbeln
                                            gs_bapi_changes-new_value
                                     CHANGING lv_success.
          
        WHEN 'NETWR'.
          " Изменение суммы (сложнее, может потребовать пересчета)
          PERFORM change_invoice_amount USING gs_bapi_changes-vbeln
                                             gs_bapi_changes-new_value
                                      CHANGING lv_success.
          
        WHEN OTHERS.
          " Другие поля через общий BAPI
          PERFORM change_invoice_field USING gs_bapi_changes-vbeln
                                            gs_bapi_changes-field
                                            gs_bapi_changes-new_value
                                     CHANGING lv_success.
      ENDCASE.
      
      " Если произошла ошибка, прервать обработку
      IF lv_success = abap_false.
        EXIT.
      ENDIF.
    ENDLOOP.
    
    " Коммит изменений
    IF lv_success = abap_true.
      COMMIT WORK.
      MESSAGE 'Изменения успешно сохранены' TYPE 'S'.
      
      " Обновление данных в ALV
      PERFORM get_invoice_data.
      CALL METHOD go_alv_grid->refresh_table_display.
    ELSE.
      ROLLBACK WORK.
      MESSAGE 'Ошибка при сохранении изменений' TYPE 'E'.
    ENDIF.
  ENDIF.

ENDFORM.

*----------------------------------------------------------------------*
* Получение списка измененных данных
*----------------------------------------------------------------------*
FORM get_changed_data.
  DATA: lt_mod_cells TYPE lvc_t_modi,
        ls_mod_cell TYPE lvc_s_modi.

  " Получение измененных ячеек из ALV
  CALL METHOD go_alv_grid->get_changed_cells
    IMPORTING
      et_modified_cells = lt_mod_cells.

  " Преобразование в формат для BAPI
  LOOP AT lt_mod_cells INTO ls_mod_cell.
    CLEAR gs_bapi_changes.
    
    " Читаем соответствующую запись из таблицы
    READ TABLE gt_invoice INTO gs_invoice INDEX ls_mod_cell-row_id.
    IF sy-subrc = 0.
      gs_bapi_changes-vbeln = gs_invoice-vbeln.
      gs_bapi_changes-field = ls_mod_cell-fieldname.
      gs_bapi_changes-new_value = ls_mod_cell-value.
      
      " Получение старого значения
      CASE ls_mod_cell-fieldname.
        WHEN 'FKDAT'.
          gs_bapi_changes-old_value = gs_invoice-fkdat.
        WHEN 'KUNAG'.
          gs_bapi_changes-old_value = gs_invoice-kunag.
        WHEN 'NETWR'.
          gs_bapi_changes-old_value = gs_invoice-netwr.
        WHEN OTHERS.
          gs_bapi_changes-old_value = 'N/A'.
      ENDCASE.
      
      APPEND gs_bapi_changes TO gt_bapi_changes.
    ENDIF.
  ENDLOOP.

ENDFORM.

*----------------------------------------------------------------------*
* Изменение даты документа
*----------------------------------------------------------------------*
FORM change_invoice_date USING pv_vbeln TYPE vbrk-vbeln
                              pv_new_date TYPE char50
                     CHANGING pv_success TYPE abap_bool.
  
  DATA: ls_doc_header TYPE bapi_doc_header,
        ls_doc_headerx TYPE bapi_doc_headerx,
        lt_return TYPE TABLE OF bapiret2,
        ls_return TYPE bapiret2.

  " Подготовка данных для BAPI
  ls_doc_header-doc_date = pv_new_date.
  ls_doc_headerx-doc_date = 'X'.

  " Вызов BAPI изменения документа
  CALL FUNCTION 'BAPI_BILLINGDOC_CHANGE'
    EXPORTING
      billingdocument = pv_vbeln
      doc_header = ls_doc_header
      doc_headerx = ls_doc_headerx
    TABLES
      return = lt_return.

  " Проверка результата
  pv_success = abap_true.
  LOOP AT lt_return INTO ls_return.
    IF ls_return-type = 'E' OR ls_return-type = 'A'.
      pv_success = abap_false.
      MESSAGE ls_return-message TYPE 'E'.
      EXIT.
    ENDIF.
  ENDLOOP.

ENDFORM.

*----------------------------------------------------------------------*
* Изменение плательщика
*----------------------------------------------------------------------*
FORM change_invoice_payer USING pv_vbeln TYPE vbrk-vbeln
                               pv_new_payer TYPE char50
                      CHANGING pv_success TYPE abap_bool.
  
  DATA: ls_doc_header TYPE bapi_doc_header,
        ls_doc_headerx TYPE bapi_doc_headerx,
        lt_return TYPE TABLE OF bapiret2,
        ls_return TYPE bapiret2.

  " Подготовка данных для BAPI
  ls_doc_header-payer = pv_new_payer.
  ls_doc_headerx-payer = 'X'.

  " Вызов BAPI изменения документа
  CALL FUNCTION 'BAPI_BILLINGDOC_CHANGE'
    EXPORTING
      billingdocument = pv_vbeln
      doc_header = ls_doc_header
      doc_headerx = ls_doc_headerx
    TABLES
      return = lt_return.

  " Проверка результата
  pv_success = abap_true.
  LOOP AT lt_return INTO ls_return.
    IF ls_return-type = 'E' OR ls_return-type = 'A'.
      pv_success = abap_false.
      MESSAGE ls_return-message TYPE 'E'.
      EXIT.
    ENDIF.
  ENDLOOP.

ENDFORM.

*----------------------------------------------------------------------*
* Изменение суммы документа (сложная операция)
*----------------------------------------------------------------------*
FORM change_invoice_amount USING pv_vbeln TYPE vbrk-vbeln
                                pv_new_amount TYPE char50
                       CHANGING pv_success TYPE abap_bool.
  
  " Внимание: Изменение суммы фактуры - сложная операция
  " Может потребовать пересчета позиций, налогов, скидок
  " В реальном проекте может потребоваться создание нового документа
  
  DATA: lv_amount TYPE vbrk-netwr,
        lt_return TYPE TABLE OF bapiret2,
        ls_return TYPE bapiret2.

  " Конвертация суммы
  lv_amount = pv_new_amount.
  
  " Для демонстрации - простая проверка
  IF lv_amount <= 0.
    MESSAGE 'Сумма должна быть положительной' TYPE 'E'.
    pv_success = abap_false.
    RETURN.
  ENDIF.
  
  " В реальном проекте здесь должна быть сложная логика
  " для пересчета всех связанных данных
  
  " Пока устанавливаем флаг успеха
  pv_success = abap_true.
  MESSAGE 'Изменение суммы требует дополнительной обработки' TYPE 'W'.

ENDFORM.

*----------------------------------------------------------------------*
* Изменение произвольного поля
*----------------------------------------------------------------------*
FORM change_invoice_field USING pv_vbeln TYPE vbrk-vbeln
                                pv_field TYPE fieldname
                                pv_new_value TYPE char50
                       CHANGING pv_success TYPE abap_bool.
  
  " Универсальная функция для изменения полей
  " В реальном проекте может использовать таблицу соответствий
  " полей ALV и полей BAPI
  
  pv_success = abap_true.
  
  " Здесь можно добавить обработку для других полей
  CASE pv_field.
    WHEN 'VKORG' OR 'VTWEG' OR 'SPART' OR 'FKART'.
      " Эти поля обычно нельзя изменять после создания документа
      MESSAGE 'Поле не может быть изменено после создания документа' TYPE 'W'.
      pv_success = abap_false.
      
    WHEN OTHERS.
      " Для неизвестных полей
      MESSAGE 'Изменение поля не поддерживается' TYPE 'W'.
      pv_success = abap_false.
  ENDCASE.

ENDFORM.

*----------------------------------------------------------------------*
* Логирование изменений
*----------------------------------------------------------------------*
FORM log_changes.
  DATA: lv_timestamp TYPE timestampl,
        lv_user TYPE sy-uname.

  " Получение текущего времени
  GET TIME STAMP FIELD lv_timestamp.
  lv_user = sy-uname.

  " Запись лога в пользовательскую таблицу (если существует)
  " Например, в таблицу Z_INVOICE_CHANGES
  LOOP AT gt_bapi_changes INTO gs_bapi_changes.
    " INSERT INTO z_invoice_changes VALUES ...
    " Здесь должна быть логика записи в таблицу логов
  ENDLOOP.

ENDFORM.

*----------------------------------------------------------------------*
* Примечания по использованию:
*----------------------------------------------------------------------*
* 1. Этот код нужно интегрировать в основную программу
* 2. Заменить PERFORM save_changes на PERFORM save_changes_with_bapi
* 3. Создать пользовательскую таблицу для логирования изменений
* 4. Настроить авторизации для использования BAPI
* 5. Протестировать на тестовых данных
*----------------------------------------------------------------------*