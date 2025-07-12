*&---------------------------------------------------------------------*
*& Report ZPP_PACKAGE_EXPLORER
*&---------------------------------------------------------------------*
*& Программа для исследования пакетов разработки
*& Отображает дерево объектов пакета с возможностью редактирования
*&---------------------------------------------------------------------*
REPORT zpp_package_explorer.

TABLES: tadir, tdevc.

*----------------------------------------------------------------------*
* Селекционный экран
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_devclass TYPE devclass OBLIGATORY
             MATCHCODE OBJECT h_tdevc_devclass.
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* Типы данных
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_object,
         devclass TYPE devclass,
         pgmid    TYPE tadir-pgmid,
         object   TYPE tadir-object,
         obj_name TYPE tadir-obj_name,
         created_by TYPE tadir-author,
         created_on TYPE tadir-created_on,
         changed_by TYPE tadir-lastuser,
         changed_on TYPE tadir-changedts,
         description TYPE string,
         node_key TYPE lvc_nkey,
         parent_key TYPE lvc_nkey,
         icon TYPE iconname,
       END OF ty_object.

DATA: gt_objects TYPE TABLE OF ty_object,
      gv_tree_container TYPE REF TO cl_gui_custom_container,
      gv_tree TYPE REF TO cl_gui_alv_tree,
      gv_ok_code TYPE sy-ucomm.

*----------------------------------------------------------------------*
* Константы
*----------------------------------------------------------------------*
CONSTANTS: c_custom_container TYPE scrfname VALUE 'CONTAINER'.

*----------------------------------------------------------------------*
* Инициализация
*----------------------------------------------------------------------*
INITIALIZATION.
  " Установка заголовков
  %_p_devclass_%_app_%-text = 'Пакет разработки'.

*----------------------------------------------------------------------*
* Проверка входных данных
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  PERFORM check_package.

*----------------------------------------------------------------------*
* Основная логика
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM get_package_objects.
  PERFORM display_tree.

*----------------------------------------------------------------------*
* Обработка пользовательских команд
*----------------------------------------------------------------------*
AT USER-COMMAND.
  gv_ok_code = sy-ucomm.
  CASE gv_ok_code.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE PROGRAM.
    WHEN 'REFRESH'.
      PERFORM refresh_tree.
    WHEN OTHERS.
      PERFORM handle_tree_events.
  ENDCASE.

*&---------------------------------------------------------------------*
*& Form check_package
*&---------------------------------------------------------------------*
FORM check_package.
  DATA: lv_devclass TYPE devclass.
  
  SELECT SINGLE devclass FROM tdevc
    INTO lv_devclass
    WHERE devclass = p_devclass.
    
  IF sy-subrc <> 0.
    MESSAGE 'Пакет разработки не найден' TYPE 'E'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_package_objects
*&---------------------------------------------------------------------*
FORM get_package_objects.
  DATA: lv_counter TYPE i VALUE 1.
  
  CLEAR gt_objects.
  
  " Получение всех объектов пакета
  SELECT tadir~pgmid,
         tadir~object,
         tadir~obj_name,
         tadir~devclass,
         tadir~author,
         tadir~created_on,
         tadir~lastuser,
         tadir~changedts
    FROM tadir
    INTO CORRESPONDING FIELDS OF TABLE gt_objects
    WHERE devclass = p_devclass
    ORDER BY object, obj_name.
  
  " Обогащение данными
  LOOP AT gt_objects INTO DATA(ls_object).
    ls_object-node_key = lv_counter.
    lv_counter = lv_counter + 1.
    
    " Установка иконки в зависимости от типа объекта
    CASE ls_object-object.
      WHEN 'PROG'.
        ls_object-icon = '@49@'.
        PERFORM get_program_description USING ls_object-obj_name
                                        CHANGING ls_object-description.
      WHEN 'CLAS'.
        ls_object-icon = '@2L@'.
        PERFORM get_class_description USING ls_object-obj_name
                                      CHANGING ls_object-description.
      WHEN 'FUGR'.
        ls_object-icon = '@2M@'.
        PERFORM get_function_group_description USING ls_object-obj_name
                                              CHANGING ls_object-description.
      WHEN 'TABL'.
        ls_object-icon = '@16@'.
        PERFORM get_table_description USING ls_object-obj_name
                                     CHANGING ls_object-description.
      WHEN 'DTEL'.
        ls_object-icon = '@17@'.
        PERFORM get_data_element_description USING ls_object-obj_name
                                           CHANGING ls_object-description.
      WHEN 'DOMA'.
        ls_object-icon = '@18@'.
        PERFORM get_domain_description USING ls_object-obj_name
                                      CHANGING ls_object-description.
      WHEN 'TRAN'.
        ls_object-icon = '@15@'.
        PERFORM get_transaction_description USING ls_object-obj_name
                                          CHANGING ls_object-description.
      WHEN OTHERS.
        ls_object-icon = '@01@'.
        ls_object-description = 'Другой объект'.
    ENDCASE.
    
    MODIFY gt_objects FROM ls_object TRANSPORTING node_key icon description.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form display_tree
*&---------------------------------------------------------------------*
FORM display_tree.
  DATA: lv_title TYPE lvc_title.
  
  " Создание контейнера
  IF gv_tree_container IS INITIAL.
    CALL SCREEN 9000.
  ELSE.
    PERFORM build_tree.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form build_tree
*&---------------------------------------------------------------------*
FORM build_tree.
  DATA: lt_fieldcat TYPE lvc_t_fcat,
        ls_fieldcat TYPE lvc_s_fcat,
        lv_title TYPE lvc_title.
  
  " Создание каталога полей
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'OBJECT'.
  ls_fieldcat-coltext = 'Тип объекта'.
  ls_fieldcat-outputlen = 10.
  APPEND ls_fieldcat TO lt_fieldcat.
  
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'OBJ_NAME'.
  ls_fieldcat-coltext = 'Имя объекта'.
  ls_fieldcat-outputlen = 30.
  APPEND ls_fieldcat TO lt_fieldcat.
  
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'DESCRIPTION'.
  ls_fieldcat-coltext = 'Описание'.
  ls_fieldcat-outputlen = 50.
  APPEND ls_fieldcat TO lt_fieldcat.
  
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'CREATED_BY'.
  ls_fieldcat-coltext = 'Автор'.
  ls_fieldcat-outputlen = 12.
  APPEND ls_fieldcat TO lt_fieldcat.
  
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'CREATED_ON'.
  ls_fieldcat-coltext = 'Дата создания'.
  ls_fieldcat-outputlen = 10.
  APPEND ls_fieldcat TO lt_fieldcat.
  
  " Создание дерева
  CALL METHOD gv_tree->set_table_for_first_display
    EXPORTING
      i_structure_name = 'ZPP_PACKAGE_EXPLORER'
      it_fieldcatalog  = lt_fieldcat
      i_save           = 'A'
    CHANGING
      it_outtab        = gt_objects.
  
  " Установка заголовка
  CONCATENATE 'Объекты пакета' p_devclass INTO lv_title SEPARATED BY space.
  gv_tree->set_screen_title( lv_title ).
  
  " Регистрация событий
  PERFORM register_tree_events.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form register_tree_events  
*&---------------------------------------------------------------------*
FORM register_tree_events.
  DATA: lt_events TYPE cntl_simple_events,
        ls_event TYPE cntl_simple_event.
  
  " Двойной клик
  ls_event-eventid = cl_gui_alv_tree=>eventid_node_double_click.
  ls_event-appl_event = 'X'.
  APPEND ls_event TO lt_events.
  
  " Контекстное меню
  ls_event-eventid = cl_gui_alv_tree=>eventid_node_context_menu_req.
  ls_event-appl_event = 'X'.
  APPEND ls_event TO lt_events.
  
  gv_tree->set_registered_events( lt_events ).
ENDFORM.

*&---------------------------------------------------------------------*
*& Form handle_tree_events
*&---------------------------------------------------------------------*
FORM handle_tree_events.
  DATA: ls_object TYPE ty_object.
  
  " Получение выбранного объекта
  PERFORM get_selected_object CHANGING ls_object.
  
  IF ls_object IS NOT INITIAL.
    PERFORM edit_object USING ls_object.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_selected_object
*&---------------------------------------------------------------------*
FORM get_selected_object CHANGING ps_object TYPE ty_object.
  DATA: lt_selected_nodes TYPE lvc_t_nkey,
        lv_node_key TYPE lvc_nkey.
  
  CLEAR ps_object.
  
  " Получение выбранных узлов
  CALL METHOD gv_tree->get_selected_nodes
    IMPORTING
      et_selected_nodes = lt_selected_nodes.
  
  READ TABLE lt_selected_nodes INTO lv_node_key INDEX 1.
  IF sy-subrc = 0.
    READ TABLE gt_objects INTO ps_object 
      WITH KEY node_key = lv_node_key.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form edit_object
*&---------------------------------------------------------------------*
FORM edit_object USING ps_object TYPE ty_object.
  DATA: lv_transaction TYPE sy-tcode.
  
  CASE ps_object-object.
    WHEN 'PROG'.
      " Редактирование программы
      lv_transaction = 'SE80'.
      SET PARAMETER ID 'RID' FIELD ps_object-obj_name.
      
    WHEN 'CLAS'.
      " Редактирование класса
      lv_transaction = 'SE80'.
      SET PARAMETER ID 'CLS' FIELD ps_object-obj_name.
      
    WHEN 'FUGR'.
      " Редактирование группы функций
      lv_transaction = 'SE80'.
      SET PARAMETER ID 'FUG' FIELD ps_object-obj_name.
      
    WHEN 'TABL'.
      " Редактирование таблицы
      lv_transaction = 'SE11'.
      SET PARAMETER ID 'DTB' FIELD ps_object-obj_name.
      
    WHEN 'DTEL'.
      " Редактирование элемента данных
      lv_transaction = 'SE11'.
      SET PARAMETER ID 'DTE' FIELD ps_object-obj_name.
      
    WHEN 'DOMA'.
      " Редактирование домена
      lv_transaction = 'SE11'.
      SET PARAMETER ID 'DOM' FIELD ps_object-obj_name.
      
    WHEN 'TRAN'.
      " Редактирование транзакции
      lv_transaction = 'SE93'.
      SET PARAMETER ID 'TCD' FIELD ps_object-obj_name.
      
    WHEN OTHERS.
      MESSAGE 'Редактирование данного типа объекта не поддерживается' TYPE 'I'.
      RETURN.
  ENDCASE.
  
  " Вызов транзакции для редактирования
  CALL TRANSACTION lv_transaction.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form refresh_tree
*&---------------------------------------------------------------------*
FORM refresh_tree.
  PERFORM get_package_objects.
  PERFORM build_tree.
  MESSAGE 'Дерево обновлено' TYPE 'S'.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_program_description
*&---------------------------------------------------------------------*
FORM get_program_description USING pv_program TYPE programm
                            CHANGING pv_description TYPE string.
  DATA: lv_title TYPE rspltitle.
  
  SELECT SINGLE text FROM trdirt
    INTO lv_title
    WHERE name = pv_program
    AND sprsl = sy-langu.
  
  IF sy-subrc = 0.
    pv_description = lv_title.
  ELSE.
    pv_description = 'Программа'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_class_description
*&---------------------------------------------------------------------*
FORM get_class_description USING pv_class TYPE seoclsname
                          CHANGING pv_description TYPE string.
  DATA: lv_descript TYPE string.
  
  SELECT SINGLE descript FROM seoclass
    INTO lv_descript
    WHERE clsname = pv_class
    AND langu = sy-langu.
  
  IF sy-subrc = 0.
    pv_description = lv_descript.
  ELSE.
    pv_description = 'Класс'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_function_group_description
*&---------------------------------------------------------------------*
FORM get_function_group_description USING pv_fugr TYPE rs38l_area
                                   CHANGING pv_description TYPE string.
  DATA: lv_areat TYPE tlibg-areat.
  
  SELECT SINGLE areat FROM tlibg
    INTO lv_areat
    WHERE area = pv_fugr
    AND spras = sy-langu.
  
  IF sy-subrc = 0.
    pv_description = lv_areat.
  ELSE.
    pv_description = 'Группа функций'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_table_description
*&---------------------------------------------------------------------*
FORM get_table_description USING pv_table TYPE tabname
                          CHANGING pv_description TYPE string.
  DATA: lv_ddtext TYPE dd02t-ddtext.
  
  SELECT SINGLE ddtext FROM dd02t
    INTO lv_ddtext
    WHERE tabname = pv_table
    AND ddlanguage = sy-langu
    AND as4local = 'A'.
  
  IF sy-subrc = 0.
    pv_description = lv_ddtext.
  ELSE.
    pv_description = 'Таблица'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_data_element_description
*&---------------------------------------------------------------------*
FORM get_data_element_description USING pv_dtel TYPE rollname
                                 CHANGING pv_description TYPE string.
  DATA: lv_ddtext TYPE dd04t-ddtext.
  
  SELECT SINGLE ddtext FROM dd04t
    INTO lv_ddtext
    WHERE rollname = pv_dtel
    AND ddlanguage = sy-langu
    AND as4local = 'A'.
  
  IF sy-subrc = 0.
    pv_description = lv_ddtext.
  ELSE.
    pv_description = 'Элемент данных'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_domain_description
*&---------------------------------------------------------------------*
FORM get_domain_description USING pv_domain TYPE domname
                           CHANGING pv_description TYPE string.
  DATA: lv_ddtext TYPE dd01t-ddtext.
  
  SELECT SINGLE ddtext FROM dd01t
    INTO lv_ddtext
    WHERE domname = pv_domain
    AND ddlanguage = sy-langu
    AND as4local = 'A'.
  
  IF sy-subrc = 0.
    pv_description = lv_ddtext.
  ELSE.
    pv_description = 'Домен'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_transaction_description
*&---------------------------------------------------------------------*
FORM get_transaction_description USING pv_tcode TYPE tcode
                                CHANGING pv_description TYPE string.
  DATA: lv_ttext TYPE tstct-ttext.
  
  SELECT SINGLE ttext FROM tstct
    INTO lv_ttext
    WHERE tcode = pv_tcode
    AND sprsl = sy-langu.
  
  IF sy-subrc = 0.
    pv_description = lv_ttext.
  ELSE.
    pv_description = 'Транзакция'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Module  STATUS_9000  OUTPUT
*&---------------------------------------------------------------------*
MODULE status_9000 OUTPUT.
  SET PF-STATUS 'MAIN'.
  SET TITLEBAR 'TITLE'.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_9000  INPUT
*&---------------------------------------------------------------------*
MODULE user_command_9000 INPUT.
  gv_ok_code = sy-ucomm.
  CASE gv_ok_code.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 0.
    WHEN 'REFRESH'.
      PERFORM refresh_tree.
    WHEN OTHERS.
      PERFORM handle_tree_events.
  ENDCASE.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  CREATE_CONTAINER  OUTPUT
*&---------------------------------------------------------------------*
MODULE create_container OUTPUT.
  DATA: lv_title TYPE lvc_title.
  
  IF gv_tree_container IS INITIAL.
    CREATE OBJECT gv_tree_container
      EXPORTING
        container_name = c_custom_container.
    
    CREATE OBJECT gv_tree
      EXPORTING
        parent = gv_tree_container
        node_selection_mode = cl_gui_alv_tree=>node_sel_mode_single.
    
    PERFORM build_tree.
  ENDIF.
ENDMODULE.