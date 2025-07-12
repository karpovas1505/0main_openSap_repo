*&---------------------------------------------------------------------*
*& Report ZPP_PACKAGE_EXPLORER_ADVANCED
*&---------------------------------------------------------------------*
*& Расширенная программа для исследования пакетов разработки
*& Дерево объектов пакета с поиском, фильтрацией и контекстным меню
*&---------------------------------------------------------------------*
REPORT zpp_package_explorer_advanced.

TABLES: tadir, tdevc.

*----------------------------------------------------------------------*
* Селекционный экран
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_devclass TYPE devclass OBLIGATORY
             MATCHCODE OBJECT h_tdevc_devclass.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_prog AS CHECKBOX DEFAULT 'X',
            p_clas AS CHECKBOX DEFAULT 'X', 
            p_fugr AS CHECKBOX DEFAULT 'X',
            p_tabl AS CHECKBOX DEFAULT 'X',
            p_dtel AS CHECKBOX DEFAULT 'X',
            p_doma AS CHECKBOX DEFAULT 'X',
            p_tran AS CHECKBOX DEFAULT 'X',
            p_other AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.
PARAMETERS: p_search TYPE string LOWER CASE.
SELECTION-SCREEN END OF BLOCK b3.

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
         is_folder TYPE abap_bool,
         expanded TYPE abap_bool,
         level TYPE i,
       END OF ty_object.

TYPES: BEGIN OF ty_object_type,
         object TYPE tadir-object,
         description TYPE string,
         icon TYPE iconname,
         count TYPE i,
       END OF ty_object_type.

DATA: gt_objects TYPE TABLE OF ty_object,
      gt_objects_filtered TYPE TABLE OF ty_object,
      gt_object_types TYPE TABLE OF ty_object_type,
      gv_tree_container TYPE REF TO cl_gui_custom_container,
      gv_tree TYPE REF TO cl_gui_alv_tree,
      gv_toolbar_container TYPE REF TO cl_gui_custom_container,
      gv_toolbar TYPE REF TO cl_gui_toolbar,
      gv_search_container TYPE REF TO cl_gui_custom_container,
      gv_search_field TYPE REF TO cl_gui_textedit,
      gv_ok_code TYPE sy-ucomm,
      gv_search_text TYPE string,
      gv_expanded_all TYPE abap_bool.

*----------------------------------------------------------------------*
* Константы
*----------------------------------------------------------------------*
CONSTANTS: c_custom_container TYPE scrfname VALUE 'CONTAINER',
           c_toolbar_container TYPE scrfname VALUE 'TOOLBAR',
           c_search_container TYPE scrfname VALUE 'SEARCH',
           c_node_folder TYPE lvc_nkey VALUE 'FOLDER',
           c_node_object TYPE lvc_nkey VALUE 'OBJECT'.

*----------------------------------------------------------------------*
* События
*----------------------------------------------------------------------*
CLASS lcl_event_handler DEFINITION.
  PUBLIC SECTION.
    METHODS: handle_double_click FOR EVENT node_double_click 
               OF cl_gui_alv_tree IMPORTING node_key,
             handle_context_menu FOR EVENT node_context_menu_request
               OF cl_gui_alv_tree IMPORTING node_key menu,
             handle_context_menu_selected FOR EVENT context_menu_selected
               OF cl_gui_alv_tree IMPORTING node_key fcode,
             handle_toolbar_function_selected FOR EVENT function_selected
               OF cl_gui_toolbar IMPORTING fcode,
             handle_expand_node FOR EVENT expand_no_children
               OF cl_gui_alv_tree IMPORTING node_key.
ENDCLASS.

DATA: go_event_handler TYPE REF TO lcl_event_handler.

*----------------------------------------------------------------------*
* Инициализация
*----------------------------------------------------------------------*
INITIALIZATION.
  " Установка заголовков
  %_p_devclass_%_app_%-text = 'Пакет разработки'.
  %_p_search_%_app_%-text = 'Поиск по имени объекта'.

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
  PERFORM apply_filters.
  PERFORM apply_search.
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
    WHEN 'SEARCH'.
      PERFORM search_objects.
    WHEN 'EXPAND_ALL'.
      PERFORM expand_all_nodes.
    WHEN 'COLLAPSE_ALL'.
      PERFORM collapse_all_nodes.
    WHEN OTHERS.
      " Обработка других команд
  ENDCASE.

*&---------------------------------------------------------------------*
*& Класс обработки событий
*&---------------------------------------------------------------------*
CLASS lcl_event_handler IMPLEMENTATION.
  METHOD handle_double_click.
    DATA: ls_object TYPE ty_object.
    
    READ TABLE gt_objects_filtered INTO ls_object 
      WITH KEY node_key = node_key.
    
    IF sy-subrc = 0 AND ls_object-is_folder = abap_false.
      PERFORM edit_object USING ls_object.
    ENDIF.
  ENDMETHOD.

  METHOD handle_context_menu.
    DATA: ls_object TYPE ty_object.
    
    READ TABLE gt_objects_filtered INTO ls_object 
      WITH KEY node_key = node_key.
    
    IF sy-subrc = 0.
      PERFORM build_context_menu USING menu ls_object.
    ENDIF.
  ENDMETHOD.

  METHOD handle_context_menu_selected.
    DATA: ls_object TYPE ty_object.
    
    READ TABLE gt_objects_filtered INTO ls_object 
      WITH KEY node_key = node_key.
    
    IF sy-subrc = 0.
      PERFORM handle_context_menu_action USING fcode ls_object.
    ENDIF.
  ENDMETHOD.

  METHOD handle_toolbar_function_selected.
    CASE fcode.
      WHEN 'REFRESH'.
        PERFORM refresh_tree.
      WHEN 'SEARCH'.
        PERFORM search_objects.
      WHEN 'EXPAND_ALL'.
        PERFORM expand_all_nodes.
      WHEN 'COLLAPSE_ALL'.
        PERFORM collapse_all_nodes.
      WHEN 'FILTER'.
        PERFORM show_filter_dialog.
    ENDCASE.
  ENDMETHOD.

  METHOD handle_expand_node.
    " Динамическое расширение узлов
    PERFORM expand_node_dynamically USING node_key.
  ENDMETHOD.
ENDCLASS.

*&---------------------------------------------------------------------*
*& Основные процедуры
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

FORM get_package_objects.
  DATA: lv_counter TYPE i VALUE 1.
  
  CLEAR: gt_objects, gt_object_types.
  
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
  
  " Обогащение данными и создание статистики
  LOOP AT gt_objects INTO DATA(ls_object).
    ls_object-node_key = lv_counter.
    ls_object-level = 1.
    ls_object-is_folder = abap_false.
    lv_counter = lv_counter + 1.
    
    " Установка иконки и описания
    PERFORM set_object_icon_and_description USING ls_object.
    
    " Обновление статистики типов объектов
    PERFORM update_object_type_statistics USING ls_object.
    
    MODIFY gt_objects FROM ls_object INDEX sy-tabix.
  ENDLOOP.
  
  " Создание групп по типам объектов
  PERFORM create_object_type_folders.
ENDFORM.

FORM set_object_icon_and_description USING ps_object TYPE ty_object.
  DATA: ls_object TYPE ty_object.
  ls_object = ps_object.
  
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
  
  ps_object = ls_object.
ENDFORM.

FORM update_object_type_statistics USING ps_object TYPE ty_object.
  DATA: ls_object_type TYPE ty_object_type.
  
  READ TABLE gt_object_types INTO ls_object_type
    WITH KEY object = ps_object-object.
  
  IF sy-subrc = 0.
    ls_object_type-count = ls_object_type-count + 1.
    MODIFY gt_object_types FROM ls_object_type INDEX sy-tabix.
  ELSE.
    ls_object_type-object = ps_object-object.
    ls_object_type-icon = ps_object-icon.
    ls_object_type-count = 1.
    
    CASE ps_object-object.
      WHEN 'PROG'.
        ls_object_type-description = 'Программы'.
      WHEN 'CLAS'.
        ls_object_type-description = 'Классы'.
      WHEN 'FUGR'.
        ls_object_type-description = 'Группы функций'.
      WHEN 'TABL'.
        ls_object_type-description = 'Таблицы'.
      WHEN 'DTEL'.
        ls_object_type-description = 'Элементы данных'.
      WHEN 'DOMA'.
        ls_object_type-description = 'Домены'.
      WHEN 'TRAN'.
        ls_object_type-description = 'Транзакции'.
      WHEN OTHERS.
        ls_object_type-description = 'Другие объекты'.
    ENDCASE.
    
    APPEND ls_object_type TO gt_object_types.
  ENDIF.
ENDFORM.

FORM create_object_type_folders.
  DATA: ls_object TYPE ty_object,
        lv_counter TYPE i.
  
  " Получение текущего максимального ключа
  LOOP AT gt_objects INTO ls_object.
    IF ls_object-node_key > lv_counter.
      lv_counter = ls_object-node_key.
    ENDIF.
  ENDLOOP.
  
  " Создание папок для каждого типа объектов
  LOOP AT gt_object_types INTO DATA(ls_object_type).
    lv_counter = lv_counter + 1.
    
    CLEAR ls_object.
    ls_object-node_key = lv_counter.
    ls_object-object = ls_object_type-object.
    ls_object-obj_name = ls_object_type-description.
    ls_object-description = |{ ls_object_type-description } ({ ls_object_type-count })|.
    ls_object-icon = ls_object_type-icon.
    ls_object-is_folder = abap_true.
    ls_object-level = 0.
    ls_object-devclass = p_devclass.
    
    INSERT ls_object INTO gt_objects INDEX 1.
    
    " Обновление parent_key для объектов этого типа
    LOOP AT gt_objects INTO DATA(ls_child) WHERE object = ls_object_type-object 
                                            AND is_folder = abap_false.
      ls_child-parent_key = lv_counter.
      ls_child-level = 1.
      MODIFY gt_objects FROM ls_child INDEX sy-tabix.
    ENDLOOP.
  ENDLOOP.
ENDFORM.

FORM apply_filters.
  DATA: lt_temp_objects TYPE TABLE OF ty_object.
  
  " Применение фильтров по типам объектов
  LOOP AT gt_objects INTO DATA(ls_object).
    CASE ls_object-object.
      WHEN 'PROG'.
        IF p_prog = 'X'.
          APPEND ls_object TO lt_temp_objects.
        ENDIF.
      WHEN 'CLAS'.
        IF p_clas = 'X'.
          APPEND ls_object TO lt_temp_objects.
        ENDIF.
      WHEN 'FUGR'.
        IF p_fugr = 'X'.
          APPEND ls_object TO lt_temp_objects.
        ENDIF.
      WHEN 'TABL'.
        IF p_tabl = 'X'.
          APPEND ls_object TO lt_temp_objects.
        ENDIF.
      WHEN 'DTEL'.
        IF p_dtel = 'X'.
          APPEND ls_object TO lt_temp_objects.
        ENDIF.
      WHEN 'DOMA'.
        IF p_doma = 'X'.
          APPEND ls_object TO lt_temp_objects.
        ENDIF.
      WHEN 'TRAN'.
        IF p_tran = 'X'.
          APPEND ls_object TO lt_temp_objects.
        ENDIF.
      WHEN OTHERS.
        IF p_other = 'X'.
          APPEND ls_object TO lt_temp_objects.
        ENDIF.
    ENDCASE.
    
    " Всегда добавляем папки
    IF ls_object-is_folder = abap_true.
      APPEND ls_object TO lt_temp_objects.
    ENDIF.
  ENDLOOP.
  
  gt_objects = lt_temp_objects.
ENDFORM.

FORM apply_search.
  gt_objects_filtered = gt_objects.
  
  IF p_search IS NOT INITIAL.
    DATA: lt_temp_objects TYPE TABLE OF ty_object.
    
    LOOP AT gt_objects INTO DATA(ls_object).
      " Поиск по имени объекта или описанию
      IF ls_object-obj_name CP |*{ p_search }*| OR
         ls_object-description CP |*{ p_search }*|.
        APPEND ls_object TO lt_temp_objects.
      ENDIF.
      
      " Всегда добавляем папки
      IF ls_object-is_folder = abap_true.
        APPEND ls_object TO lt_temp_objects.
      ENDIF.
    ENDLOOP.
    
    gt_objects_filtered = lt_temp_objects.
  ENDIF.
ENDFORM.

FORM display_tree.
  IF gv_tree_container IS INITIAL.
    CALL SCREEN 9001.
  ELSE.
    PERFORM build_tree.
  ENDIF.
ENDFORM.

FORM build_tree.
  DATA: lt_fieldcat TYPE lvc_t_fcat,
        ls_fieldcat TYPE lvc_s_fcat,
        lv_title TYPE lvc_title,
        lt_sort TYPE lvc_t_sort,
        ls_sort TYPE lvc_s_sort.
  
  " Создание каталога полей
  PERFORM create_field_catalog CHANGING lt_fieldcat.
  
  " Создание дерева
  CALL METHOD gv_tree->set_table_for_first_display
    EXPORTING
      i_structure_name = 'ZPP_PACKAGE_EXPLORER'
      it_fieldcatalog  = lt_fieldcat
      i_save           = 'A'
      i_default        = 'X'
    CHANGING
      it_outtab        = gt_objects_filtered.
  
  " Построение иерархии
  PERFORM build_hierarchy.
  
  " Установка заголовка
  CONCATENATE 'Объекты пакета' p_devclass 
    INTO lv_title SEPARATED BY space.
  gv_tree->set_screen_title( lv_title ).
  
  " Регистрация событий
  PERFORM register_tree_events.
ENDFORM.

FORM create_field_catalog CHANGING pt_fieldcat TYPE lvc_t_fcat.
  DATA: ls_fieldcat TYPE lvc_s_fcat.
  
  CLEAR pt_fieldcat.
  
  " Тип объекта
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'OBJECT'.
  ls_fieldcat-coltext = 'Тип'.
  ls_fieldcat-outputlen = 8.
  ls_fieldcat-key = 'X'.
  APPEND ls_fieldcat TO pt_fieldcat.
  
  " Имя объекта
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'OBJ_NAME'.
  ls_fieldcat-coltext = 'Имя объекта'.
  ls_fieldcat-outputlen = 40.
  APPEND ls_fieldcat TO pt_fieldcat.
  
  " Описание
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'DESCRIPTION'.
  ls_fieldcat-coltext = 'Описание'.
  ls_fieldcat-outputlen = 60.
  APPEND ls_fieldcat TO pt_fieldcat.
  
  " Автор
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'CREATED_BY'.
  ls_fieldcat-coltext = 'Автор'.
  ls_fieldcat-outputlen = 12.
  APPEND ls_fieldcat TO pt_fieldcat.
  
  " Дата создания
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'CREATED_ON'.
  ls_fieldcat-coltext = 'Создан'.
  ls_fieldcat-outputlen = 10.
  APPEND ls_fieldcat TO pt_fieldcat.
  
  " Последнее изменение
  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname = 'CHANGED_BY'.
  ls_fieldcat-coltext = 'Изменил'.
  ls_fieldcat-outputlen = 12.
  APPEND ls_fieldcat TO pt_fieldcat.
ENDFORM.

FORM build_hierarchy.
  DATA: lt_hierarchy TYPE lvc_t_nkey,
        ls_hierarchy TYPE lvc_s_hier.
  
  " Построение иерархии дерева
  LOOP AT gt_objects_filtered INTO DATA(ls_object).
    IF ls_object-is_folder = abap_true.
      " Добавление папки как корневого узла
      CALL METHOD gv_tree->add_node
        EXPORTING
          i_relat_node_key = ''
          i_relationship   = cl_gui_alv_tree=>relat_last_child
          i_node_text      = ls_object-obj_name
          is_outtab_line   = ls_object
          i_node_key       = ls_object-node_key.
    ELSE.
      " Добавление объекта как дочернего узла
      CALL METHOD gv_tree->add_node
        EXPORTING
          i_relat_node_key = ls_object-parent_key
          i_relationship   = cl_gui_alv_tree=>relat_last_child
          i_node_text      = ls_object-obj_name
          is_outtab_line   = ls_object
          i_node_key       = ls_object-node_key.
    ENDIF.
  ENDLOOP.
ENDFORM.

FORM register_tree_events.
  DATA: lt_events TYPE cntl_simple_events,
        ls_event TYPE cntl_simple_event.
  
  CREATE OBJECT go_event_handler.
  
  " Регистрация событий
  ls_event-eventid = cl_gui_alv_tree=>eventid_node_double_click.
  ls_event-appl_event = 'X'.
  APPEND ls_event TO lt_events.
  
  ls_event-eventid = cl_gui_alv_tree=>eventid_node_context_menu_req.
  ls_event-appl_event = 'X'.
  APPEND ls_event TO lt_events.
  
  ls_event-eventid = cl_gui_alv_tree=>eventid_context_menu_selected.
  ls_event-appl_event = 'X'.
  APPEND ls_event TO lt_events.
  
  ls_event-eventid = cl_gui_alv_tree=>eventid_expand_no_children.
  ls_event-appl_event = 'X'.
  APPEND ls_event TO lt_events.
  
  gv_tree->set_registered_events( lt_events ).
  
  " Установка обработчиков событий
  SET HANDLER go_event_handler->handle_double_click FOR gv_tree.
  SET HANDLER go_event_handler->handle_context_menu FOR gv_tree.
  SET HANDLER go_event_handler->handle_context_menu_selected FOR gv_tree.
  SET HANDLER go_event_handler->handle_expand_node FOR gv_tree.
ENDFORM.

FORM build_context_menu USING po_menu TYPE REF TO cl_ctmenu
                              ps_object TYPE ty_object.
  
  IF ps_object-is_folder = abap_false.
    CALL METHOD po_menu->add_function
      EXPORTING
        fcode = 'EDIT'
        text  = 'Редактировать'.
    
    CALL METHOD po_menu->add_function
      EXPORTING
        fcode = 'DISPLAY'
        text  = 'Просмотр'.
    
    CALL METHOD po_menu->add_separator.
    
    CALL METHOD po_menu->add_function
      EXPORTING
        fcode = 'COPY'
        text  = 'Копировать имя'.
    
    CALL METHOD po_menu->add_function
      EXPORTING
        fcode = 'WHERE_USED'
        text  = 'Где используется'.
  ENDIF.
ENDFORM.

FORM handle_context_menu_action USING pv_fcode TYPE sy-ucomm
                                       ps_object TYPE ty_object.
  
  CASE pv_fcode.
    WHEN 'EDIT'.
      PERFORM edit_object USING ps_object.
    WHEN 'DISPLAY'.
      PERFORM display_object USING ps_object.
    WHEN 'COPY'.
      PERFORM copy_object_name USING ps_object.
    WHEN 'WHERE_USED'.
      PERFORM show_where_used USING ps_object.
  ENDCASE.
ENDFORM.

FORM edit_object USING ps_object TYPE ty_object.
  DATA: lv_transaction TYPE sy-tcode.
  
  CASE ps_object-object.
    WHEN 'PROG'.
      lv_transaction = 'SE80'.
      SET PARAMETER ID 'RID' FIELD ps_object-obj_name.
    WHEN 'CLAS'.
      lv_transaction = 'SE80'.
      SET PARAMETER ID 'CLS' FIELD ps_object-obj_name.
    WHEN 'FUGR'.
      lv_transaction = 'SE80'.
      SET PARAMETER ID 'FUG' FIELD ps_object-obj_name.
    WHEN 'TABL'.
      lv_transaction = 'SE11'.
      SET PARAMETER ID 'DTB' FIELD ps_object-obj_name.
    WHEN 'DTEL'.
      lv_transaction = 'SE11'.
      SET PARAMETER ID 'DTE' FIELD ps_object-obj_name.
    WHEN 'DOMA'.
      lv_transaction = 'SE11'.
      SET PARAMETER ID 'DOM' FIELD ps_object-obj_name.
    WHEN 'TRAN'.
      lv_transaction = 'SE93'.
      SET PARAMETER ID 'TCD' FIELD ps_object-obj_name.
    WHEN OTHERS.
      MESSAGE 'Редактирование данного типа объекта не поддерживается' TYPE 'I'.
      RETURN.
  ENDCASE.
  
  CALL TRANSACTION lv_transaction.
ENDFORM.

FORM display_object USING ps_object TYPE ty_object.
  DATA: lv_transaction TYPE sy-tcode.
  
  CASE ps_object-object.
    WHEN 'PROG'.
      lv_transaction = 'SE80'.
      SET PARAMETER ID 'RID' FIELD ps_object-obj_name.
    WHEN 'CLAS'.
      lv_transaction = 'SE80'.
      SET PARAMETER ID 'CLS' FIELD ps_object-obj_name.
    WHEN 'FUGR'.
      lv_transaction = 'SE80'.
      SET PARAMETER ID 'FUG' FIELD ps_object-obj_name.
    WHEN 'TABL'.
      lv_transaction = 'SE11'.
      SET PARAMETER ID 'DTB' FIELD ps_object-obj_name.
    WHEN 'DTEL'.
      lv_transaction = 'SE11'.
      SET PARAMETER ID 'DTE' FIELD ps_object-obj_name.
    WHEN 'DOMA'.
      lv_transaction = 'SE11'.
      SET PARAMETER ID 'DOM' FIELD ps_object-obj_name.
    WHEN 'TRAN'.
      lv_transaction = 'SE93'.
      SET PARAMETER ID 'TCD' FIELD ps_object-obj_name.
    WHEN OTHERS.
      MESSAGE 'Просмотр данного типа объекта не поддерживается' TYPE 'I'.
      RETURN.
  ENDCASE.
  
  CALL TRANSACTION lv_transaction AND RETURN.
ENDFORM.

FORM copy_object_name USING ps_object TYPE ty_object.
  " Копирование имени объекта в буфер обмена
  CALL FUNCTION 'SCMS_STRING_TO_FTEXT'
    EXPORTING
      text   = ps_object-obj_name
    IMPORTING
      ftext  = DATA(lv_ftext).
  
  MESSAGE |Имя объекта { ps_object-obj_name } скопировано| TYPE 'S'.
ENDFORM.

FORM show_where_used USING ps_object TYPE ty_object.
  " Показать где используется объект
  CASE ps_object-object.
    WHEN 'PROG' OR 'CLAS' OR 'FUGR'.
      CALL FUNCTION 'RS_EU_CROSSREF'
        EXPORTING
          i_find_obj_cls = ps_object-object
          i_find_object  = ps_object-obj_name.
    WHEN OTHERS.
      MESSAGE 'Анализ использования для данного типа объекта не поддерживается' TYPE 'I'.
  ENDCASE.
ENDFORM.

FORM refresh_tree.
  PERFORM get_package_objects.
  PERFORM apply_filters.
  PERFORM apply_search.
  PERFORM build_tree.
  MESSAGE 'Дерево обновлено' TYPE 'S'.
ENDFORM.

FORM search_objects.
  " Реализация поиска объектов
  CALL FUNCTION 'POPUP_TO_GET_ONE_VALUE'
    EXPORTING
      textline1    = 'Поиск объектов'
      textline2    = 'Введите строку для поиска:'
      title        = 'Поиск'
      start_column = 10
      start_row    = 5
    IMPORTING
      returncode   = DATA(lv_returncode)
    CHANGING
      parameter    = gv_search_text.
  
  IF lv_returncode = 'OK' AND gv_search_text IS NOT INITIAL.
    p_search = gv_search_text.
    PERFORM apply_search.
    PERFORM build_tree.
  ENDIF.
ENDFORM.

FORM expand_all_nodes.
  gv_tree->expand_all_nodes( ).
  gv_expanded_all = abap_true.
ENDFORM.

FORM collapse_all_nodes.
  gv_tree->collapse_all_nodes( ).
  gv_expanded_all = abap_false.
ENDFORM.

FORM show_filter_dialog.
  " Показать диалог фильтрации
  MESSAGE 'Используйте селекционный экран для настройки фильтров' TYPE 'I'.
ENDFORM.

FORM expand_node_dynamically USING pv_node_key TYPE lvc_nkey.
  " Динамическое расширение узлов при необходимости
  " Можно добавить дополнительную логику загрузки подобъектов
ENDFORM.

" Формы для получения описаний (аналогично базовой версии)
INCLUDE zpp_package_explorer_descriptions.

*&---------------------------------------------------------------------*
*& Модули экрана 9001
*&---------------------------------------------------------------------*
MODULE status_9001 OUTPUT.
  SET PF-STATUS 'MAIN_ADVANCED'.
  SET TITLEBAR 'TITLE_ADVANCED'.
ENDMODULE.

MODULE user_command_9001 INPUT.
  gv_ok_code = sy-ucomm.
  CASE gv_ok_code.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 0.
    WHEN 'REFRESH'.
      PERFORM refresh_tree.
    WHEN 'SEARCH'.
      PERFORM search_objects.
    WHEN 'EXPAND_ALL'.
      PERFORM expand_all_nodes.
    WHEN 'COLLAPSE_ALL'.
      PERFORM collapse_all_nodes.
    WHEN 'FILTER'.
      PERFORM show_filter_dialog.
    WHEN OTHERS.
      " Обработка других команд
  ENDCASE.
ENDMODULE.

MODULE create_containers OUTPUT.
  DATA: lv_title TYPE lvc_title.
  
  IF gv_tree_container IS INITIAL.
    " Создание основного контейнера
    CREATE OBJECT gv_tree_container
      EXPORTING
        container_name = c_custom_container.
    
    " Создание дерева
    CREATE OBJECT gv_tree
      EXPORTING
        parent = gv_tree_container
        node_selection_mode = cl_gui_alv_tree=>node_sel_mode_single.
    
    " Создание тулбара
    CREATE OBJECT gv_toolbar_container
      EXPORTING
        container_name = c_toolbar_container.
    
    CREATE OBJECT gv_toolbar
      EXPORTING
        parent = gv_toolbar_container.
    
    " Создание панели поиска
    CREATE OBJECT gv_search_container
      EXPORTING
        container_name = c_search_container.
    
    CREATE OBJECT gv_search_field
      EXPORTING
        parent = gv_search_container.
    
    PERFORM build_tree.
    PERFORM setup_toolbar.
  ENDIF.
ENDMODULE.

FORM setup_toolbar.
  DATA: lt_toolbar TYPE ttb_button,
        ls_toolbar TYPE stb_button.
  
  " Кнопка обновления
  ls_toolbar-function = 'REFRESH'.
  ls_toolbar-icon = '@42@'.
  ls_toolbar-text = 'Обновить'.
  ls_toolbar-quickinfo = 'Обновить дерево объектов'.
  ls_toolbar-butn_type = 0.
  APPEND ls_toolbar TO lt_toolbar.
  
  " Разделитель
  CLEAR ls_toolbar.
  ls_toolbar-butn_type = 3.
  APPEND ls_toolbar TO lt_toolbar.
  
  " Кнопка поиска
  ls_toolbar-function = 'SEARCH'.
  ls_toolbar-icon = '@46@'.
  ls_toolbar-text = 'Поиск'.
  ls_toolbar-quickinfo = 'Поиск объектов'.
  ls_toolbar-butn_type = 0.
  APPEND ls_toolbar TO lt_toolbar.
  
  " Кнопка развернуть все
  ls_toolbar-function = 'EXPAND_ALL'.
  ls_toolbar-icon = '@4V@'.
  ls_toolbar-text = 'Развернуть все'.
  ls_toolbar-quickinfo = 'Развернуть все узлы'.
  ls_toolbar-butn_type = 0.
  APPEND ls_toolbar TO lt_toolbar.
  
  " Кнопка свернуть все
  ls_toolbar-function = 'COLLAPSE_ALL'.
  ls_toolbar-icon = '@4T@'.
  ls_toolbar-text = 'Свернуть все'.
  ls_toolbar-quickinfo = 'Свернуть все узлы'.
  ls_toolbar-butn_type = 0.
  APPEND ls_toolbar TO lt_toolbar.
  
  " Кнопка фильтра
  ls_toolbar-function = 'FILTER'.
  ls_toolbar-icon = '@43@'.
  ls_toolbar-text = 'Фильтр'.
  ls_toolbar-quickinfo = 'Настройка фильтров'.
  ls_toolbar-butn_type = 0.
  APPEND ls_toolbar TO lt_toolbar.
  
  gv_toolbar->add_button_group( lt_toolbar ).
  
  " Регистрация обработчика событий тулбара
  SET HANDLER go_event_handler->handle_toolbar_function_selected FOR gv_toolbar.
ENDFORM.