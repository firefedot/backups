Установка и настройка postgresql
---------

Для запуска нужно запустить

    ansible-playbook playbook_postgresql.yml -i ../test2_hosts_sample.yml
    # test2_hosts_sample.yml - нужный файл инвентори
    # он применяется сразу на группу dbservers
    
### Что делает

    Подключает рипозитории ставит на целевые сервера софт
    name:
      - postgresql-9.6
      - postgresql-contrib-9.6
      - libpq-dev
      - python3-psycopg2
      - python-psycopg2
     
     Последние два нужны для работы модуля postgresql_*
     
     Если есть внешний сервер базыданных, то на appservers ставит:
     name:
      - postgresql-client-9.6
     
   Создает дирректорию хранения паролей для следующих плейбуков
      `{{ home_path }}/_local_conf/passwd` с правами 600
      
Проверяет наличие файла `{{ home_path }}/_local_conf/passwd/psql_{{ db_user }}`
он является подтвеждением, что плейбук выполнялся на этом сервере
( пока так, может другой файл выберем )

Если файла нет, то создаются два файла с паролями в диретории **files** этой роли **postrgeql**,
файлы нужны для того чтобы можно было после работы плейбука внести значения в lastpass

Далее файлы передаются на сервер, от куда их данные попадут в `_local_conf` и `pgswitcher`

Создаются пользователи базы данных ( имя берется из инвенторя ), jdbcproxy, replicator

Генерируется файл .pgpass из шаблона и имеет вид

    localhost:5432:monitoring_{{ customer }}:jdbcproxy:xsw2zaq1
    localhost:5432:taxi:taxi:1qaz2wsx
    app1:5432:taxi:taxi:1qaz2wsx
    app2:5432:taxi:taxi:1qaz2wsx
    
    Если есть внешние БД сервера, то адаптирует файл под них и передает нужные параметры на фппсервера
    
 и права на доступ **600**
 
 С помощью команды `shell: 'df  /var/lib/postgresql | grep "dev"| cut -d " " -f1'`
 выяснется на каком диске расположен postgres и добавляем запись
 `blockdev --setra 16384 {{ read_ahead.stdout }}"` в rc.local, предварительно
 проверив его на существование ( создается если нету )
 
 Вносятся изменения в **sysctl** исходя из того, есть ли выделенный сервер или нет
 
 Считается количество ОЗУ, проверяется наличие SSD диска под postgres
 Копируется основной конфиг **postgres.conf**, и в дирректорию **/etc/postgresql/9.6/main/conf.d**
 копируется дополнительный конфиг, собрав данные о кол-ве ОЗУ и типа дисков.
 Выбирается можель 64 Гб ОЗУ или меньше ( два варианта конфигов на данный момент )
 
 Из шаблона генерируется файл pg_hba.conf  вида
 
    # DO NOT DISABLE!
    # If you change this first entry you will need to make sure that the
    # database superuser can access the database using some other method.
    # Noninteractive access to all databases is required during automatic
    # maintenance (custom daily cronjobs, replication, and similar tasks).
    #
    # Database administrative login by Unix domain socket
    local   all             postgres                                peer
    
    # TYPE  DATABASE        USER            ADDRESS                 METHOD
    
    # "local" is for Unix domain socket connections only
    local   all             all                                     peer
    # IPv4 local connections:
    # database connections from all servers where *-core modules are deploye
    host	all             all             192.168.122.230/32	md5
    host	all             all             192.168.122.149/32	md5
    host    all             all             127.0.0.1/32            md5
    # for replication (IP address of other DB node)
    host    replication     replicator      192.168.122.149/32    trust
    # IPv6 local connections:
    host    all             all             ::1/128                 md5
 
 Репликатор имеет адрес противоположной ноды
 Не стал делать это модулем postgresql_hba из-за большего кода и подумалось. что с шаблоном удобнее работать
 ( можно поменять на модуль, если надо )
 
 Перезапускается сервис postgresql ( по идее он эквивалент _pg_ctlcluster 9.6 main restart_  )
 
#### p.s.

 Расширения добавляются после создания базы в плебуке  **playbook_createdb.yml**