### Install and configure pgswitcher

    # Запускаем
    ansible-playbook playbook_pgswitcher.yml -i ../test2_hosts_sample.yml
    # -i ../test2_hosts_sample.yml - файл инвентори
    
### Details

Собирает пароли из заранее подготовленных файлов ( см. README_POSTGRESQL.md )

Дополняет файлы jmxremote, если там не было еще записи нужной и создает с нужными правами если не было файла ранее.

Устанавливает нужный софт, если не было 

        name:
      - jsvc
      - openjdk-8-jre-headless


В локальной дирректории проекта, roles/pgswitcher/files/, лежат файлы:

    pgswitcher-cli-1.2.3.deb
    pgswitcher-node-1.2.3.deb

Они не выкачиваются каждый раз из тимсити по двум причинам:
 1 - пока что не понятно как это правильно делать
 2 - эти файлы изменяются не так частно
 
Эти файлы копируются на ноды баз данных, устанавливаются

Копируются шаблоны конфигов

    /etc/pgswitcher/node-daemon.properties
    /etc/pgswitcher/config.yaml
    
 В первый вносятся адреса на которых будут установлены клиенты pgswitcher
 Во второй генерируются данные из инвенторя и имеет вид
    
        useNodeDaemon: true
        drainTimeoutMsec: 5000
        initStandbyTimeoutMin: 600
        serviceDbOptions:
            dbName: taxi
            user: taxi
            password: x-OU-hsYP_
        
        datasources:
        - !ds
            alias: app1
            host: app1
            port: 7777
            objectName: Catalina:type=DataSource,context=/app-core,host=localhost,class=javax.sql.DataSource,name="jdbc/CubaDS"
            user: pgswitcher
            password: gBdUIY0TH7
        
        - !ds
            alias: aa-app1
            host: app1
            port: 7777
            objectName: Catalina:type=DataSource,context=/allocator,host=localhost,class=javax.sql.DataSource,name="jdbc/CubaDS"
            user: pgswitcher
            password: gBdUIY0TH7
        
        - !ds
            alias: app2
            host: app2
            port: 7777
            objectName: Catalina:type=DataSource,context=/app-core,host=localhost,class=javax.sql.DataSource,name="jdbc/CubaDS"
            user: pgswitcher
            password: gBdUIY0TH7
        
        - !ds
            alias: aa-app2
            host: app2
            port: 7777
            objectName: Catalina:type=DataSource,context=/allocator,host=localhost,class=javax.sql.DataSource,name="jdbc/CubaDS"
            user: pgswitcher
            password: gBdUIY0TH7
        
        postgresNodes:
        - !pg
            alias: db1
            host: app1
            clusterVersion: 9.6
        - !pg
            alias: db2
            host: app2
            clusterVersion: 9.6

Пока что не добавлял функции для общежития.

И если аллокатор один, то будет один алолкатор в этом конфиге, шаблон с работает и прри 46 теге.

( Возможно надо добавить в имена алиасов имя внедрения на случай общежития )
    
            - !ds
            alias: app2-test2
            host: app2
            port: 7777
            objectName: Catalina:type=DataSource,context=/app-core,host=localhost,class=javax.sql.DataSource,name="jdbc/CubaDS"
            user: pgswitcher
            password: gBdUIY0TH7
        
        - !ds
            alias: aa-app2-test2
            host: app2
            port: 7777
            objectName: Catalina:type=DataSource,context=/allocator,host=localhost,class=javax.sql.DataSource,name="jdbc/CubaDS"
            user: pgswitcher
            password: gBdUIY0TH7


Перезапускается pgswitcher-node и проверяются логи на предмет удачного запуска
( полностью правильно отработает. только в первый запуск. пока логи чистые )

Проверяется запущен ли демон

И тестовые подключения по телнету к серверам с базой 

#### p.s.
Плейбук выполняет работу до пукта **Тестирование штатного переключения**
, так как пока чтон е настроены томкаты для тестов

#### p.s.2
В следующей версии будут устранены эти и другие пробелы 