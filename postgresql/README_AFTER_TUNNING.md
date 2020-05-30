### Post tuning production system settings through web client

Запуск плейбука:

    ansible-playbook playbook_after_tunning_jmx.yml -i ../test_inventory.yml 

Автоматически выполняются пост настройки томката по статье:
 - https://confluence.haulmont.com/display/TAXI/Post+tuning+production+system+settings+through+web+client
 
 SMTP данные берутся из файла инвентори:
 
      all:
        vars:
            smtp:
                  smtpHost: localhost
                  smtpPort: 12345
                  smtpAuthRequired: true
                  smtpUser: test
                  smtpPassword: test
                  smtpStarttlsEnable: false
                  fromaddress: noreply@mycompanyz.com
                  smtpConnectionTimeoutSec: 21
                  smtpTimeoutSec: 61
 
Если данные о smtp отсутсвуют, по умолчанию применятся значения из статьи выше

#### p.s.
Плейбук выполняется одним из самых завершающих.
Так как ему требуются данные прошлых плейбуков и нужно будет перезапускать все томкаты.