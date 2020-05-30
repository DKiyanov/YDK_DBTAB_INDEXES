*&---------------------------------------------------------------------*
*& Report  YDK_DBTAB_INDEXES
*& Display all indexes for db table
*&---------------------------------------------------------------------*
*& Autor: Kiyanov Dmitry
*& Email: DKiyanov@mail.ru
*&---------------------------------------------------------------------*

REPORT ydk_dbtab_indexes.

PARAMETERS: tabname TYPE dd02l-tabname MEMORY ID dtb OBLIGATORY.
PARAMETERS: dbexist AS CHECKBOX DEFAULT 'X'.

DATA: fc  TYPE lvc_t_fcat.
DATA: fct TYPE abap_component_tab.
FIELD-SYMBOLS <fc> LIKE LINE OF fc.
FIELD-SYMBOLS <fct> LIKE LINE OF fct.

FIELD-SYMBOLS: <alv_tab> TYPE STANDARD TABLE.
FIELD-SYMBOLS: <alv_wa> TYPE any.

DATA: htext TYPE c LENGTH 255.

START-OF-SELECTION.
  PERFORM get_data.
  PERFORM alv_show.

FORM get_data.
  DATA: itfld TYPE STANDARD TABLE OF dfies WITH HEADER LINE.
  DATA: indx TYPE STANDARD TABLE OF dd17s-indexname WITH HEADER LINE.
  DATA: BEGIN OF indxf OCCURS 0,
          indexname LIKE dd17s-indexname,
          position  LIKE dd17s-position,
          fieldname LIKE dd17s-fieldname,
        END   OF indxf.
  DATA: fname TYPE string.

  FIELD-SYMBOLS <fs> TYPE dd17s-position.

  CALL FUNCTION 'GET_FIELDTAB'
    EXPORTING
      tabname             = tabname
    TABLES
      fieldtab            = itfld
    EXCEPTIONS
      internal_error      = 1
      no_texts_found      = 2
      table_has_no_fields = 3
      table_not_activ     = 4
      OTHERS              = 5.

  IF sy-subrc <> 0.
    MESSAGE 'table not found' TYPE 'S' DISPLAY LIKE 'E'.
    STOP.
  ENDIF.

  SELECT * INTO CORRESPONDING FIELDS OF TABLE indxf
    FROM dd17s
   WHERE sqltab   = tabname
     AND as4local = 'A'
     AND as4vers  = '0000'.

  SORT indxf.

  IF dbexist = abap_true.
    DATA: subrc TYPE sy-subrc.
    LOOP AT indxf.
      AT NEW indexname.
        CLEAR subrc.
        CALL FUNCTION 'DB_EXISTS_INDEX'
          EXPORTING
            tabname   = tabname
            indexname = indxf-indexname
          IMPORTING
            subrc     = subrc
          EXCEPTIONS
            OTHERS    = 2.
        IF sy-subrc <> 0 OR subrc <> 0.
          DELETE indxf WHERE indexname = indxf-indexname.
        ENDIF.
      ENDAT.
    ENDLOOP.
  ENDIF.

  indxf-indexname = '0'.
  LOOP AT itfld WHERE keyflag = 'X'.
    indxf-position  = itfld-position.
    indxf-fieldname = itfld-fieldname.
    APPEND indxf.
  ENDLOOP.

  IF indxf[] IS INITIAL.
    MESSAGE 'it is not DB table' TYPE 'S' DISPLAY LIKE 'E'.
    STOP.
  ENDIF.

  SELECT SINGLE  ddtext INTO htext
    FROM dd02t
   WHERE tabname    = tabname
     AND ddlanguage = sy-langu
     AND as4local   = 'A'
     AND as4vers    = '0000'.
  CONCATENATE tabname htext INTO htext SEPARATED BY space.

  SORT indxf BY indexname.

  LOOP AT indxf.
    AT NEW indexname.
      APPEND indxf-indexname TO indx.
    ENDAT.
  ENDLOOP.

  PERFORM fc_add_field USING 'FIELDNAME' 'DFIES-FIELDNAME' '' '' ''.
  PERFORM fc_add_field USING 'FIELDTEXT' 'DFIES-FIELDTEXT' '' '' ''.

  LOOP AT indx.
    CONCATENATE 'ZZYDFD' indx INTO fname.
    PERFORM fc_add_field USING fname 'DD17S-POSITION' '' '' indx.
  ENDLOOP.

  PERFORM fc_create.

  LOOP AT itfld.
    READ TABLE indxf WITH KEY fieldname = itfld-fieldname.
    CHECK sy-subrc = 0.

    APPEND INITIAL LINE TO <alv_tab> ASSIGNING <alv_wa>.
    MOVE-CORRESPONDING itfld TO <alv_wa>.

    LOOP AT indx.
      READ TABLE indxf WITH KEY indexname = indx fieldname = itfld-fieldname.
      CHECK sy-subrc = 0.

      CONCATENATE 'ZZYDFD' indx INTO fname.
      ASSIGN COMPONENT fname OF STRUCTURE <alv_wa> TO <fs>.
      <fs> = indxf-position.
    ENDLOOP.
  ENDLOOP.
ENDFORM.

FORM fc_add_field USING fname ftype flength fdecimals fdesc.
  DATA: l TYPE i.
  DATA: xdd03l TYPE dd_x031l_table WITH HEADER LINE.
  DATA: elemdescr TYPE REF TO cl_abap_elemdescr.

  READ TABLE fct WITH KEY name = fname TRANSPORTING NO FIELDS.
  CHECK sy-subrc <> 0.

  APPEND INITIAL LINE TO fc ASSIGNING <fc>.
  APPEND INITIAL LINE TO fct ASSIGNING <fct>.

  <fct>-name = fname.
  TRANSLATE <fct>-name TO UPPER CASE.

  l = strlen( ftype ).

  IF l <= 1.
    CASE ftype.
      WHEN ' '. <fct>-type ?= cl_abap_elemdescr=>get_string( ).
      WHEN 'g'. <fct>-type ?= cl_abap_elemdescr=>get_string( ).
      WHEN 'I'. <fct>-type ?= cl_abap_elemdescr=>get_i( ).
      WHEN 'F'. <fct>-type ?= cl_abap_elemdescr=>get_f( ).
      WHEN 'D'. <fct>-type ?= cl_abap_elemdescr=>get_d( ).
      WHEN 'T'. <fct>-type ?= cl_abap_elemdescr=>get_t( ).
      WHEN 'C'. <fct>-type ?= cl_abap_elemdescr=>get_c( p_length = flength ).
      WHEN 'N'. <fct>-type ?= cl_abap_elemdescr=>get_n( p_length = flength ).
      WHEN 'X'. <fct>-type ?= cl_abap_elemdescr=>get_x( p_length = flength ).
      WHEN 'P'. <fct>-type ?= cl_abap_elemdescr=>get_p( p_length = flength p_decimals = fdecimals ).
    ENDCASE.
  ELSE.
    <fct>-type ?= cl_abap_elemdescr=>describe_by_name( ftype ).

    CALL METHOD <fct>-type->get_ddic_object
      RECEIVING
        p_object     = xdd03l[]
      EXCEPTIONS
        not_found    = 1
        no_ddic_type = 2
        OTHERS       = 3.

    IF sy-subrc = 0.
      READ TABLE xdd03l INDEX 1.
      IF xdd03l-rollname IS INITIAL.
        elemdescr ?= <fct>-type.
        <fc>-rollname = elemdescr->help_id.
      ELSE.
        <fc>-rollname = xdd03l-rollname.
      ENDIF.
      <fc>-convexit = xdd03l-convexit.
      <fc>-datatype = xdd03l-dtyp.
    ENDIF.
  ENDIF.

*  <fc>-col_pos   = reg_wa-findex.
  <fc>-fieldname = fname.
  <fc>-tabname   = 1.
*  <fc>-datatype  = reg_dd03p_wa-datatype.
  <fc>-inttype   = <fct>-type->type_kind.
  <fc>-intlen    = <fct>-type->length.
*  <fc>-domname   = reg_dd03p_wa-domname.
*  <fc>-dd_outlen = reg_dd03p_wa-outputlen.
  <fc>-decimals  = <fct>-type->decimals.
*  <fc>-ref_table = reg_wa-sname.
*  <fc>-ref_field = reg_wa-fld.
  <fc>-coltext   = fdesc.
  <fc>-tooltip   = fdesc.

  DATA: tabname   TYPE dd03t-tabname.
  DATA: fieldname TYPE dd03t-fieldname.
  DATA: ddtext    TYPE dd03t-ddtext.

  IF fdesc IS INITIAL AND ftype CA '-'.
    SPLIT ftype AT '-' INTO tabname fieldname.

    SELECT SINGLE ddtext INTO ddtext
      FROM dd03t
     WHERE tabname = tabname
       AND ddlanguage = sy-langu
       AND as4local = 'A'
       AND fieldname = fieldname.
    <fc>-coltext   = ddtext.
    <fc>-tooltip   = ddtext.
  ENDIF.

ENDFORM.                    "add_fc_field

FORM fc_create.
  DATA: alv_wa_ref TYPE REF TO data.
  DATA: alv_tab_ref TYPE REF TO data.
  DATA: structdescr TYPE REF TO cl_abap_structdescr.

  structdescr ?= cl_abap_structdescr=>create( fct ).
  CREATE DATA alv_wa_ref TYPE HANDLE structdescr.

  ASSIGN alv_wa_ref->* TO <alv_wa>.
  CREATE DATA alv_tab_ref LIKE TABLE OF <alv_wa>.
  ASSIGN alv_tab_ref->* TO <alv_tab>.
ENDFORM.

FORM alv_show.
  DATA: repid TYPE sy-repid.
  repid = sy-repid.
  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
*     I_INTERFACE_CHECK           = ' '
*     I_BYPASSING_BUFFER          =
*     I_BUFFER_ACTIVE             =
      i_callback_program          = repid
*     i_callback_pf_status_set    = 'ALV_STATUS_SET'
*     i_callback_user_command     = 'ALV_USER_COMMAND'
*     I_CALLBACK_TOP_OF_PAGE      = ' '
      i_callback_html_top_of_page = 'ALV_HTML_TOP_OF_PAGE'
*     I_CALLBACK_HTML_END_OF_LIST = ' '
*     I_STRUCTURE_NAME            =
*     I_BACKGROUND_ID             = ' '
*     I_GRID_TITLE                =
*     I_GRID_SETTINGS             =
*     IS_LAYOUT_LVC               =
      it_fieldcat_lvc             = fc[]
*     IT_EXCLUDING                =
*     IT_SPECIAL_GROUPS_LVC       =
*     IT_SORT_LVC                 =
*     IT_FILTER_LVC               =
*     IT_HYPERLINK                =
*     IS_SEL_HIDE                 =
*     I_DEFAULT                   = 'X'
*     i_save                      = 'A'
*     is_variant                  = variant
*     IT_EVENTS                   =
*     IT_EVENT_EXIT               =
*     IS_PRINT_LVC                =
*     IS_REPREP_ID_LVC            =
*     I_SCREEN_START_COLUMN       = 0
*     I_SCREEN_START_LINE         = 0
*     I_SCREEN_END_COLUMN         = 0
*     I_SCREEN_END_LINE           = 0
      i_html_height_top           = 4
*     I_HTML_HEIGHT_END           =
*     IT_ALV_GRAPHICS             =
*     IT_EXCEPT_QINFO_LVC         =
*     IR_SALV_FULLSCREEN_ADAPTER  =
    TABLES
      t_outtab                    = <alv_tab>
    EXCEPTIONS
      program_error               = 1
      OTHERS                      = 2.
ENDFORM.                    "alv_show

FORM alv_html_top_of_page USING document  TYPE REF TO cl_dd_document.
  CALL METHOD document->add_text
    EXPORTING
      text = htext.
ENDFORM.
