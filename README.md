### Описание


    backup_production_db.sh - скрипт для каждодневнего бекапа, если не стоит barman
    dump-db-for-testing.sh - скрипт бекапа для дальнейшей обфускации
    get-prod-dump.sh - скрипт обфускации базы для тестов
    
    google_quota_monitor.py - полученние количества данных гугл-квот и передача их заббиксу
    gluster_check.sh  - скрипт мониторинга состояния GlusterFS
    
    postgresql - несколько плейбуков ansible для разворачивания базы
    
    teamcity_release - плейбук ansible для создания тестового сервера