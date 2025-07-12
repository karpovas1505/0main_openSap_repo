*&---------------------------------------------------------------------*
*& Include ZPP_PACKAGE_EXPLORER_DESCRIPTIONS
*&---------------------------------------------------------------------*
*& Описания объектов для программ исследования пакетов
*&---------------------------------------------------------------------*

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
*& Form get_message_class_description
*&---------------------------------------------------------------------*
FORM get_message_class_description USING pv_msag TYPE arbgb
                                  CHANGING pv_description TYPE string.
  DATA: lv_stext TYPE t100a-stext.
  
  SELECT SINGLE stext FROM t100a
    INTO lv_stext
    WHERE arbgb = pv_msag
    AND masterlang = sy-langu.
  
  IF sy-subrc = 0.
    pv_description = lv_stext.
  ELSE.
    pv_description = 'Класс сообщений'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_view_description
*&---------------------------------------------------------------------*
FORM get_view_description USING pv_view TYPE tabname
                         CHANGING pv_description TYPE string.
  DATA: lv_ddtext TYPE dd02t-ddtext.
  
  SELECT SINGLE ddtext FROM dd02t
    INTO lv_ddtext
    WHERE tabname = pv_view
    AND ddlanguage = sy-langu
    AND as4local = 'A'.
  
  IF sy-subrc = 0.
    pv_description = lv_ddtext.
  ELSE.
    pv_description = 'Представление'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_interface_description
*&---------------------------------------------------------------------*
FORM get_interface_description USING pv_interface TYPE seoclsname
                              CHANGING pv_description TYPE string.
  DATA: lv_descript TYPE string.
  
  SELECT SINGLE descript FROM seoclass
    INTO lv_descript
    WHERE clsname = pv_interface
    AND langu = sy-langu.
  
  IF sy-subrc = 0.
    pv_description = lv_descript.
  ELSE.
    pv_description = 'Интерфейс'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_type_group_description
*&---------------------------------------------------------------------*
FORM get_type_group_description USING pv_type_group TYPE typename
                               CHANGING pv_description TYPE string.
  DATA: lv_ddtext TYPE dd02t-ddtext.
  
  SELECT SINGLE ddtext FROM dd02t
    INTO lv_ddtext
    WHERE tabname = pv_type_group
    AND ddlanguage = sy-langu
    AND as4local = 'A'.
  
  IF sy-subrc = 0.
    pv_description = lv_ddtext.
  ELSE.
    pv_description = 'Группа типов'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_web_dynpro_description
*&---------------------------------------------------------------------*
FORM get_web_dynpro_description USING pv_wda TYPE wdy_application_name
                               CHANGING pv_description TYPE string.
  DATA: lv_description TYPE wdy_md_description.
  
  SELECT SINGLE description FROM wdy_application
    INTO lv_description
    WHERE application_name = pv_wda
    AND language = sy-langu.
  
  IF sy-subrc = 0.
    pv_description = lv_description.
  ELSE.
    pv_description = 'Web Dynpro приложение'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_bsp_description
*&---------------------------------------------------------------------*
FORM get_bsp_description USING pv_bsp TYPE o2applname
                        CHANGING pv_description TYPE string.
  DATA: lv_description TYPE o2desc.
  
  SELECT SINGLE description FROM o2applprop
    INTO lv_description
    WHERE applname = pv_bsp
    AND langu = sy-langu.
  
  IF sy-subrc = 0.
    pv_description = lv_description.
  ELSE.
    pv_description = 'BSP приложение'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_enhancement_description
*&---------------------------------------------------------------------*
FORM get_enhancement_description USING pv_enh TYPE enhname
                                CHANGING pv_description TYPE string.
  DATA: lv_shorttext TYPE enhtxt.
  
  SELECT SINGLE shorttext FROM enhtxt
    INTO lv_shorttext
    WHERE enhname = pv_enh
    AND langu = sy-langu.
  
  IF sy-subrc = 0.
    pv_description = lv_shorttext.
  ELSE.
    pv_description = 'Улучшение'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_workflow_description
*&---------------------------------------------------------------------*
FORM get_workflow_description USING pv_workflow TYPE sww_wiid
                             CHANGING pv_description TYPE string.
  " Для workflow объектов описание можно получить из разных таблиц
  " в зависимости от типа workflow
  pv_description = 'Workflow'.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form get_authorization_object_description
*&---------------------------------------------------------------------*
FORM get_authorization_object_description USING pv_auth TYPE tobj-objct
                                         CHANGING pv_description TYPE string.
  DATA: lv_text TYPE tobj-text.
  
  SELECT SINGLE text FROM tobj
    INTO lv_text
    WHERE objct = pv_auth
    AND langu = sy-langu.
  
  IF sy-subrc = 0.
    pv_description = lv_text.
  ELSE.
    pv_description = 'Объект авторизации'.
  ENDIF.
ENDFORM.