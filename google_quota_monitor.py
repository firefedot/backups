#!/usr/bin/python3
import json
import sys
import os.path
import subprocess
import datetime

if len(sys.argv) > 1:
    gets = sys.argv[1]
    full_gets = gets.split('.')
    name_prod = full_gets[0]
else:
    sys.exit("Error: less argv, you mast write argv param0.param1.param2 etc.")

name_prod_file_json = '/home/haulmont/_log/NAMEPROD.json'

# Generate  main json for discovery
esc = '{"{#API}"'
esc_nameprod = '"{#NAMEPROD}"'
end_esc = '},'

export_json_global = '/tmp/Global_out.json'

#
# Для того что бы каждый раз не вписывать новые API  и новые channels
# Используется генерация из поступающих данных,
# что дает возможность добавлять новые данные к выводу и практически не менять этот скрипт
#
periods = ['day', 'week', 'month']
channels = ['all']

if name_prod == 'nameprod':

    # global day,week,month vars
    for period in periods:
        exec('global_ALL_all_' + period + ' = 0')

    with open(name_prod_file_json) as name_prod_file:
        list_full_prod = json.load(name_prod_file)
        print('{ "data":[')
        for i in range(0, len(list_full_prod["data"])):
            list_prods = str(list_full_prod["data"][i]).replace('{','').replace('}', '').split(',')
            zabbix_name_prod = list_prods[0].replace("'",'').replace(' ', '').split(':')
            zabbix_ip_prod = list_prods[1].replace("'", '').replace(' ', '').split(':')
            zabbix_port_list = list_prods[2].replace("'",'').replace(' ', '').split(':')

            if zabbix_port_list[1] != '0':
                zabbix_ip = zabbix_ip_prod[1]
                zabbix_port = str(zabbix_port_list[1])
                name_prod = zabbix_name_prod[1]

                # export file json
                api_list = ['ALL']
                export_json = f'/tmp/{name_prod}_out.json'

                # check for port or not port into argv
                try:
                    zabbix_port = int(zabbix_port)
                except ValueError:
                    pass

                if zabbix_port > 0:
                    json_var = subprocess.run(f'/usr/bin/zabbix_get -s {zabbix_ip} -p {zabbix_port} -k jmx[app-core.taxi:service=GoogleQuotaMonitor][ConsumedQuotaAsJson]',
                        shell=True, stdout=subprocess.PIPE, encoding='utf-8')
                    list_full = json.loads(str(json_var.stdout))

                    # generate vars for individual API. example: GEO_all_day
                    for API, channelz in list_full.items():
                        api_list.append(API)
                        for period in periods:
                            exec(API + '_all_' + period + ' = 0')

                    # total count into current API
                    all_day = 0
                    all_week = 0
                    all_month = 0
                    # define vars for collect json into string
                    json_global = ''
                    json_global += "{"
                    json_global_temp_day = ''
                    json_global_temp_week = ''
                    json_global_temp_month = ''

                    # decode json
                    for API, channel in list_full.items():
                        json_global += f"'{API}': " + "{"
                        for single_channel, time_count in channel.items():
                            # exec('global_' + API + '_' + single_channel + '_all_month = 0')
                            # collect channels
                            if single_channel not in channels:
                                channels.append(single_channel)

                            json_global += f"'{single_channel}':" + "{"
                            for days in time_count.items():
                                # loop for generate comma if loop is not finale
                                if 'month' in days:
                                    comma = ''
                                else:
                                    comma = ','
                                json_global += f"'{days[0]}': {days[1]}{comma}"

                                # create/generate all_day/week/month for current API
                                exec('all_' + days[0] + "=all_" + days[0] + " + list_full[API][single_channel][days[0]]")

                                # generate global_api_channel_period if this need
                                try:
                                    exec('global_' + API + '_' + single_channel + '_' + days[0] + ' += list_full[API][single_channel][days[0]]')
                                except NameError as nameer:
                                    exec('global_' + API + '_' + single_channel + '_' + days[0] + ' = 0')
                                    exec('global_' + API + '_' + single_channel + '_' + days[0] + ' += list_full[API][single_channel][days[0]]')

                                # generate global_api_channel_period if this need
                                try:
                                    exec('global_ALL_' + single_channel + '_' + days[0] + ' += list_full[API][single_channel][days[0]]')
                                except NameError as nameer:
                                    exec('global_ALL_' + single_channel + '_' + days[0] + ' = 0')
                                    exec('global_ALL_' + single_channel + '_' + days[0] + ' += list_full[API][single_channel][days[0]]')

                                # generate global day,week,month
                                exec('global_ALL_all_' + days[0] + "+= list_full[API][single_channel][days[0]]")
                                try:
                                    if isinstance(exec(API + '_all_' + days[0] + "=" + API + "_all_" + days[0] + " + list_full[API][single_channel][days[0]]"), str):
                                        exec(API + '_all_' + days[0] + "=" + API + "_all_" + days[0] + " + list_full[API][single_channel][days[0]]")
                                except KeyError as exc:
                                    pass

                            json_global += "},"
                        json_global += "'all': {"
                        for period in periods:
                            exec('json_global_temp_' + period + ' = ' + API + '_all_' + period )
                            # generate global_api_period if this need
                            try:
                                exec('global_' + API + '_all_' + period + '+= ' + API + '_all_' + period)
                            except NameError as nameerr:
                                exec('global_' + API + '_all_' + period + '= 0')
                                exec('global_' + API + '_all_' + period + '+= ' + API + '_all_' + period)

                        json_global += f'"day":{json_global_temp_day},"week":{json_global_temp_week},"month":{json_global_temp_month}'
                        json_global += "}},"

                    json_global += "'ALL': {"
                    json_global += "'all': {"
                    json_global += f"'day': {all_day},"
                    json_global += f"'week': {all_week},"
                    json_global += f"'month': {all_month}"
                    json_global += '}}'
                    json_global += '}'

                    # save json with current API to file, for next usage
                    with open(export_json, "w") as new_json:
                        new_json.write((json_global.replace("'", '"')))

                    for API, channel in list_full.items():
                        for single_channel, time_count in channel.items():
                            for days in time_count.items():
                                print(f"{esc}: \"{name_prod}.{API}.{single_channel}.{days[0]}\",{esc_nameprod}: \"{name_prod}\"{end_esc}")
                        print(f"{esc}: \"{name_prod}.{API}.all.day\",{esc_nameprod}: \"{name_prod}\"{end_esc}")
                        print(f"{esc}: \"{name_prod}.{API}.all.week\",{esc_nameprod}: \"{name_prod}\"{end_esc}")
                        print(f"{esc}: \"{name_prod}.{API}.all.month\",{esc_nameprod}: \"{name_prod}\"{end_esc}")

                    print('{"{#API}": "' + name_prod + '.ALL.all.day", "{#NAMEPROD}": "'+name_prod+'"},')
                    print('{"{#API}": "' + name_prod + '.ALL.all.week", "{#NAMEPROD}": "'+name_prod+'"},')
                    print('{"{#API}": "' + name_prod + '.ALL.all.month", "{#NAMEPROD}": "'+name_prod+'"},')
                else:
                    sys.exit('0')
            else:
                pass

        for API in api_list:
            # print('{"{#API}": "Global.' + API + '.all.' + period + '", "{#NAMEPROD}": "Global"},')
            for channel in channels:
                for period in periods:
                    try:
                        count_loop += 1
                    except NameError as nameerr:
                        count_loop = 0
                        count_loop += 1
                    if count_loop == (len(channels) * len(api_list) * len(periods)):
                        comma = ''
                    else:
                        comma = ','

                    print('{"{#API}": "Global.' + API + '.' + channel + '.' + period + '", "{#NAMEPROD}": "Global"}' + comma + '')

        print(']}')


    # when global_day/week/month is correct
    if global_ALL_all_day > 0:
        with open(export_json_global, "w") as global_json:
            # generate json for Global periods
            json_global_all = ""
            json_global_all += "{"

            for count_loop_api, API in enumerate(api_list):
                json_global_all += "'" + API + "': {"
                for count_loop_channel, channel in enumerate(channels):
                    json_global_all += "'" + channel + "': {"
                    for period in periods:
                        if 'month' in period:
                            comma = ''
                        else:
                            comma = ','
                        try:
                            json_global_all += "'" + period + "': " + str(eval('global_' + API + '_' + channel + '_' + period)) + "" + comma + ""
                        except NameError as nameer:
                            exec('global_' + API + '_' + channel + '_' + period + ' = 0')
                            json_global_all += "'" + period + "': " + str(eval('global_' + API + '_' + channel + '_' + period)) + "" + comma + ""

                    if (count_loop_channel == (len(channels)-1)):
                        commas = ''
                    else:
                        commas = ','
                    json_global_all += "}" + commas
                    if (count_loop_api == (len(api_list) - 1)) and (count_loop_channel == (len(channels)-1)):
                        commaz = ''
                    else:
                        commaz = ','

                json_global_all += "}" + commaz + ""
            json_global_all += "}"
            global_json.write((json_global_all.replace("'", '"')))


# get parameter from Discovery (example: ALL.all.day: 1234 )
if len(full_gets) == 4:
    export_json = f'/tmp/{name_prod}_out.json'
    if os.path.exists(export_json):
        with open(export_json) as file_all:
            list_full_gets = json.load(file_all)
        print(f'{list_full_gets[full_gets[1]][full_gets[2]][full_gets[3]]}')
        debug_file = '/tmp/debug/' + name_prod + '.dbg'
        with open(debug_file, 'a') as dbg_file:
            dbg_file.write(f'{datetime.datetime.now()} - {full_gets[0]}.{full_gets[1]}.{full_gets[2]}.{full_gets[3]}\n')
            dbg_file.write(f'{datetime.datetime.now()} - {list_full_gets[full_gets[1]]}\n')
            dbg_file.write(f'{datetime.datetime.now()} - {list_full_gets[full_gets[1]][full_gets[2]]}\n')
            dbg_file.write(f'{datetime.datetime.now()} - {list_full_gets[full_gets[1]][full_gets[2]][full_gets[3]]}\n')
    sys.exit()
