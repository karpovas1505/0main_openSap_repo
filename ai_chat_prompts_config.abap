*&---------------------------------------------------------------------*
*& Include ZAI_CHAT_PROMPTS_CONFIG
*&---------------------------------------------------------------------*
*& Конфигурация промптов и настроек для ИИ чата
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* Системные промпты для разных задач
*----------------------------------------------------------------------*
CONSTANTS: BEGIN OF gc_system_prompts,
  " Общий помощник
  general TYPE string VALUE 
    'Ты полезный ИИ-помощник. Отвечай кратко и по существу на русском языке. ' &&
    'Если не знаешь ответа, так и скажи.',
    
  " ABAP эксперт
  abap_expert TYPE string VALUE 
    'Ты эксперт по ABAP программированию с 15-летним опытом. ' &&
    'Анализируй код, предлагай оптимизации, объясняй концепции. ' &&
    'Используй современные подходы ABAP Objects. Отвечай на русском языке.',
    
  " SAP функциональный консультант
  sap_functional TYPE string VALUE 
    'Ты опытный SAP функциональный консультант. ' &&
    'Помогай с бизнес-процессами, настройкой модулей, best practices. ' &&
    'Объясняй сложные концепции простым языком.',
    
  " Архитектор решений
  solution_architect TYPE string VALUE 
    'Ты архитектор SAP решений. Проектируй системы, интеграции, ' &&
    'выбирай технологии. Учитывай производительность, безопасность, ' &&
    'масштабируемость. Предлагай конкретные решения.',
    
  " Преподаватель
  teacher TYPE string VALUE 
    'Ты преподаватель SAP технологий. Объясняй материал пошагово, ' &&
    'используй примеры, проверяй понимание. Адаптируй сложность под уровень студента.',
    
  " Отладчик
  debugger TYPE string VALUE 
    'Ты специалист по отладке SAP. Анализируй ошибки, дампы, ' &&
    'проблемы производительности. Предлагай конкретные шаги для решения.',
    
  " Документатор
  documenter TYPE string VALUE 
    'Ты создаешь техническую документацию для SAP. ' &&
    'Структурируй информацию, используй примеры кода, ' &&
    'создавай понятные инструкции.',
    
  " Код-ревьюер
  code_reviewer TYPE string VALUE 
    'Ты делаешь код-ревью ABAP программ. Проверяй качество, ' &&
    'соответствие стандартам, безопасность, производительность. ' &&
    'Предлагай конкретные улучшения.',
    
  " Интеграционный специалист
  integration_expert TYPE string VALUE 
    'Ты эксперт по интеграции SAP с внешними системами. ' &&
    'Знаешь REST, SOAP, RFC, IDoc, PI/PO. Проектируй надежные интеграции.',
    
  " Тестировщик
  tester TYPE string VALUE 
    'Ты QA инженер для SAP. Создавай тест-кейсы, ' &&
    'планируй тестирование, находи баги. Фокусируйся на качестве.',
    
  END OF gc_system_prompts.

*----------------------------------------------------------------------*
* Готовые промпты для часто используемых задач
*----------------------------------------------------------------------*
CONSTANTS: BEGIN OF gc_quick_prompts,
  " Анализ кода
  analyze_code TYPE string VALUE 
    'Проанализируй этот ABAP код и предложи улучшения:\n\n',
    
  " Оптимизация производительности
  optimize_performance TYPE string VALUE 
    'Как оптимизировать производительность этого кода:\n\n',
    
  " Создание документации
  create_docs TYPE string VALUE 
    'Создай техническую документацию для этого кода:\n\n',
    
  " Объяснение ошибки
  explain_error TYPE string VALUE 
    'Объясни эту ошибку SAP и как её исправить:\n\n',
    
  " Конвертация кода
  convert_code TYPE string VALUE 
    'Конвертируй этот старый ABAP код в современный стиль:\n\n',
    
  " Создание тестов
  create_tests TYPE string VALUE 
    'Создай Unit тесты для этого ABAP кода:\n\n',
    
  " Рефакторинг
  refactor_code TYPE string VALUE 
    'Отрефактори этот код, используя лучшие практики:\n\n',
    
  " Интеграция
  design_integration TYPE string VALUE 
    'Спроектируй интеграцию между SAP и внешней системой:\n\n',
    
  " Обучение
  explain_concept TYPE string VALUE 
    'Объясни эту SAP концепцию с примерами:\n\n',
    
  " Решение проблем
  solve_problem TYPE string VALUE 
    'Помоги решить эту проблему в SAP:\n\n',
    
  END OF gc_quick_prompts.

*----------------------------------------------------------------------*
* Конфигурация моделей
*----------------------------------------------------------------------*
CONSTANTS: BEGIN OF gc_model_configs,
  " Настройки для разных типов задач
  BEGIN OF creative_writing,
    temperature TYPE p VALUE '1.2',
    max_tokens TYPE i VALUE '2000',
    top_p TYPE p VALUE '0.9',
  END OF creative_writing,
  
  BEGIN OF code_analysis,
    temperature TYPE p VALUE '0.3',
    max_tokens TYPE i VALUE '1500',
    top_p TYPE p VALUE '0.8',
  END OF code_analysis,
  
  BEGIN OF documentation,
    temperature TYPE p VALUE '0.5',
    max_tokens TYPE i VALUE '2500',
    top_p TYPE p VALUE '0.8',
  END OF documentation,
  
  BEGIN OF problem_solving,
    temperature TYPE p VALUE '0.4',
    max_tokens TYPE i VALUE '1200',
    top_p TYPE p VALUE '0.8',
  END OF problem_solving,
  
  BEGIN OF learning,
    temperature TYPE p VALUE '0.6',
    max_tokens TYPE i VALUE '1800',
    top_p TYPE p VALUE '0.9',
  END OF learning,
  
  END OF gc_model_configs.

*----------------------------------------------------------------------*
* Шаблоны для специальных команд
*----------------------------------------------------------------------*
CONSTANTS: BEGIN OF gc_chat_commands,
  " Команды чата
  help TYPE string VALUE '/help',
  clear TYPE string VALUE '/clear',
  save TYPE string VALUE '/save',
  load TYPE string VALUE '/load',
  export TYPE string VALUE '/export',
  config TYPE string VALUE '/config',
  prompt TYPE string VALUE '/prompt',
  model TYPE string VALUE '/model',
  tokens TYPE string VALUE '/tokens',
  cost TYPE string VALUE '/cost',
  history TYPE string VALUE '/history',
  
  " Быстрые команды
  code_review TYPE string VALUE '/review',
  optimize TYPE string VALUE '/optimize',
  document TYPE string VALUE '/document',
  test TYPE string VALUE '/test',
  explain TYPE string VALUE '/explain',
  convert TYPE string VALUE '/convert',
  debug TYPE string VALUE '/debug',
  integrate TYPE string VALUE '/integrate',
  
  END OF gc_chat_commands.

*----------------------------------------------------------------------*
* Настройки для разных провайдеров
*----------------------------------------------------------------------*
CONSTANTS: BEGIN OF gc_provider_settings,
  " OpenAI
  BEGIN OF openai,
    url TYPE string VALUE 'https://api.openai.com/v1/chat/completions',
    default_model TYPE string VALUE 'gpt-3.5-turbo',
    supports_streaming TYPE abap_bool VALUE abap_true,
    max_context_length TYPE i VALUE 4096,
    cost_per_1k_tokens TYPE p VALUE '0.002',
  END OF openai,
  
  " Claude
  BEGIN OF claude,
    url TYPE string VALUE 'https://api.anthropic.com/v1/messages',
    default_model TYPE string VALUE 'claude-3-sonnet-20240229',
    supports_streaming TYPE abap_bool VALUE abap_true,
    max_context_length TYPE i VALUE 100000,
    cost_per_1k_tokens TYPE p VALUE '0.015',
  END OF claude,
  
  " Gemini
  BEGIN OF gemini,
    url TYPE string VALUE 'https://generativelanguage.googleapis.com/v1/models/',
    default_model TYPE string VALUE 'gemini-pro',
    supports_streaming TYPE abap_bool VALUE abap_false,
    max_context_length TYPE i VALUE 30720,
    cost_per_1k_tokens TYPE p VALUE '0.001',
  END OF gemini,
  
  " Local
  BEGIN OF local,
    url TYPE string VALUE 'http://localhost:8080/v1/chat/completions',
    default_model TYPE string VALUE 'local-model',
    supports_streaming TYPE abap_bool VALUE abap_true,
    max_context_length TYPE i VALUE 2048,
    cost_per_1k_tokens TYPE p VALUE '0.000',
  END OF local,
  
  END OF gc_provider_settings.

*----------------------------------------------------------------------*
* Готовые сценарии использования
*----------------------------------------------------------------------*
CONSTANTS: BEGIN OF gc_use_cases,
  " Сценарии для разных ролей
  BEGIN OF developer,
    title TYPE string VALUE 'ABAP Разработчик',
    description TYPE string VALUE 'Помощь в разработке, отладке и оптимизации ABAP кода',
    system_prompt TYPE string VALUE gc_system_prompts-abap_expert,
    temperature TYPE p VALUE '0.3',
    max_tokens TYPE i VALUE '1500',
  END OF developer,
  
  BEGIN OF consultant,
    title TYPE string VALUE 'SAP Консультант',
    description TYPE string VALUE 'Функциональная настройка и бизнес-процессы',
    system_prompt TYPE string VALUE gc_system_prompts-sap_functional,
    temperature TYPE p VALUE '0.5',
    max_tokens TYPE i VALUE '2000',
  END OF consultant,
  
  BEGIN OF architect,
    title TYPE string VALUE 'Архитектор Решений',
    description TYPE string VALUE 'Проектирование системной архитектуры',
    system_prompt TYPE string VALUE gc_system_prompts-solution_architect,
    temperature TYPE p VALUE '0.4',
    max_tokens TYPE i VALUE '2500',
  END OF architect,
  
  BEGIN OF student,
    title TYPE string VALUE 'Студент SAP',
    description TYPE string VALUE 'Обучение и изучение SAP технологий',
    system_prompt TYPE string VALUE gc_system_prompts-teacher,
    temperature TYPE p VALUE '0.6',
    max_tokens TYPE i VALUE '1800',
  END OF student,
  
  END OF gc_use_cases.

*----------------------------------------------------------------------*
* Функции для работы с конфигурацией
*----------------------------------------------------------------------*
CLASS lcl_prompt_manager DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS: get_system_prompts RETURNING VALUE(rt_prompts) TYPE string_table,
                   get_quick_prompts RETURNING VALUE(rt_prompts) TYPE string_table,
                   get_model_config IMPORTING iv_task TYPE string
                                   RETURNING VALUE(rs_config) TYPE string,
                   get_use_case_config IMPORTING iv_role TYPE string
                                      RETURNING VALUE(rs_config) TYPE string,
                   validate_command IMPORTING iv_command TYPE string
                                   RETURNING VALUE(rv_valid) TYPE abap_bool,
                   process_command IMPORTING iv_command TYPE string
                                             iv_session_id TYPE string
                                  RETURNING VALUE(rv_result) TYPE string.
ENDCLASS.

CLASS lcl_prompt_manager IMPLEMENTATION.
  METHOD get_system_prompts.
    " Возвращает список доступных системных промптов
    APPEND 'Общий помощник' TO rt_prompts.
    APPEND 'ABAP эксперт' TO rt_prompts.
    APPEND 'SAP консультант' TO rt_prompts.
    APPEND 'Архитектор решений' TO rt_prompts.
    APPEND 'Преподаватель' TO rt_prompts.
    APPEND 'Отладчик' TO rt_prompts.
    APPEND 'Документатор' TO rt_prompts.
    APPEND 'Код-ревьюер' TO rt_prompts.
    APPEND 'Интеграционный специалист' TO rt_prompts.
    APPEND 'Тестировщик' TO rt_prompts.
  ENDMETHOD.
  
  METHOD get_quick_prompts.
    " Возвращает список быстрых промптов
    APPEND 'Анализ кода' TO rt_prompts.
    APPEND 'Оптимизация производительности' TO rt_prompts.
    APPEND 'Создание документации' TO rt_prompts.
    APPEND 'Объяснение ошибки' TO rt_prompts.
    APPEND 'Конвертация кода' TO rt_prompts.
    APPEND 'Создание тестов' TO rt_prompts.
    APPEND 'Рефакторинг' TO rt_prompts.
    APPEND 'Проектирование интеграции' TO rt_prompts.
    APPEND 'Обучение' TO rt_prompts.
    APPEND 'Решение проблем' TO rt_prompts.
  ENDMETHOD.
  
  METHOD get_model_config.
    " Возвращает конфигурацию модели для конкретной задачи
    CASE iv_task.
      WHEN 'creative'.
        rs_config = |Temperature: { gc_model_configs-creative_writing-temperature }, | &&
                   |Max Tokens: { gc_model_configs-creative_writing-max_tokens }|.
      WHEN 'code'.
        rs_config = |Temperature: { gc_model_configs-code_analysis-temperature }, | &&
                   |Max Tokens: { gc_model_configs-code_analysis-max_tokens }|.
      WHEN 'docs'.
        rs_config = |Temperature: { gc_model_configs-documentation-temperature }, | &&
                   |Max Tokens: { gc_model_configs-documentation-max_tokens }|.
      WHEN 'problem'.
        rs_config = |Temperature: { gc_model_configs-problem_solving-temperature }, | &&
                   |Max Tokens: { gc_model_configs-problem_solving-max_tokens }|.
      WHEN 'learning'.
        rs_config = |Temperature: { gc_model_configs-learning-temperature }, | &&
                   |Max Tokens: { gc_model_configs-learning-max_tokens }|.
      WHEN OTHERS.
        rs_config = 'Конфигурация по умолчанию'.
    ENDCASE.
  ENDMETHOD.
  
  METHOD get_use_case_config.
    " Возвращает конфигурацию для роли пользователя
    CASE iv_role.
      WHEN 'developer'.
        rs_config = |{ gc_use_cases-developer-title }: { gc_use_cases-developer-description }|.
      WHEN 'consultant'.
        rs_config = |{ gc_use_cases-consultant-title }: { gc_use_cases-consultant-description }|.
      WHEN 'architect'.
        rs_config = |{ gc_use_cases-architect-title }: { gc_use_cases-architect-description }|.
      WHEN 'student'.
        rs_config = |{ gc_use_cases-student-title }: { gc_use_cases-student-description }|.
      WHEN OTHERS.
        rs_config = 'Общий пользователь'.
    ENDCASE.
  ENDMETHOD.
  
  METHOD validate_command.
    " Проверяет валидность команды чата
    rv_valid = abap_false.
    
    IF iv_command CP '/help' OR iv_command CP '/clear' OR iv_command CP '/save' OR
       iv_command CP '/load' OR iv_command CP '/export' OR iv_command CP '/config' OR
       iv_command CP '/prompt' OR iv_command CP '/model' OR iv_command CP '/tokens' OR
       iv_command CP '/cost' OR iv_command CP '/history' OR iv_command CP '/review' OR
       iv_command CP '/optimize' OR iv_command CP '/document' OR iv_command CP '/test' OR
       iv_command CP '/explain' OR iv_command CP '/convert' OR iv_command CP '/debug' OR
       iv_command CP '/integrate'.
      rv_valid = abap_true.
    ENDIF.
  ENDMETHOD.
  
  METHOD process_command.
    " Обрабатывает команды чата
    CASE iv_command.
      WHEN '/help'.
        rv_result = |Доступные команды:
/help - Показать справку
/clear - Очистить чат
/save - Сохранить сессию
/load - Загрузить сессию
/export - Экспорт истории
/config - Показать конфигурацию
/prompt - Сменить системный промпт
/model - Сменить модель
/tokens - Показать использование токенов
/cost - Показать стоимость запросов
/history - Показать историю сессий

Быстрые команды:
/review - Код-ревью
/optimize - Оптимизация
/document - Документирование
/test - Создание тестов
/explain - Объяснение
/convert - Конвертация кода
/debug - Отладка
/integrate - Интеграция|.
        
      WHEN '/clear'.
        rv_result = 'Чат очищен. Начните новый разговор.'.
        
      WHEN '/save'.
        rv_result = |Сессия { iv_session_id } сохранена.|.
        
      WHEN '/config'.
        rv_result = 'Текущая конфигурация: OpenAI GPT-3.5-turbo, Temperature: 0.7, Max Tokens: 1000'.
        
      WHEN '/tokens'.
        rv_result = 'Использовано токенов в этой сессии: 1,234'.
        
      WHEN '/cost'.
        rv_result = 'Стоимость текущей сессии: $0.05'.
        
      WHEN OTHERS.
        rv_result = 'Неизвестная команда. Наберите /help для справки.'.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Примеры использования
*----------------------------------------------------------------------*
* Пример 1: Анализ ABAP кода
* System Prompt: gc_system_prompts-abap_expert
* User Input: gc_quick_prompts-analyze_code + [КОД]
*
* Пример 2: Обучение SAP концепциям
* System Prompt: gc_system_prompts-teacher
* User Input: gc_quick_prompts-explain_concept + 'BAPI vs RFC'
*
* Пример 3: Отладка ошибок
* System Prompt: gc_system_prompts-debugger
* User Input: gc_quick_prompts-explain_error + [ТЕКСТ ОШИБКИ]
*
* Пример 4: Создание документации
* System Prompt: gc_system_prompts-documenter
* User Input: gc_quick_prompts-create_docs + [КОД/ОПИСАНИЕ]
*
* Пример 5: Код-ревью
* System Prompt: gc_system_prompts-code_reviewer
* User Input: gc_quick_prompts-refactor_code + [КОД]
*----------------------------------------------------------------------*