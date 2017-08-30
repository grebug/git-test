#!/usr/bin/python3
# -*- coding: UTF-8 -*-

################################################################################
#                       suggest_file clean and count                           #
# @author: ruidi.wang                                                          #
# @create:2017/7/28                                                            #
#                                                                              #
# 输入：input_dir output_dir                                                   #
# 文件夹输入路径和输出路径（绝对路径）                                         #
#                                                                              #
# 输出：按文件时间排列的文件夹，如20170724_cleaned文件夹                       #
# 包含结果文件：                                                               #
# suggest_cleaned.txt 数据清洗、格式转换后文件                                 #
# search_click_data.txt 有搜索结果数据量、无结果数据量、点击量                 #
# click_position_source_data.txt 用户点击的位置源数据                          #
# click_position_distribution.txt 用户点击分布统计                             #
# click_search_route.txt 点击内容，搜索路径长度，搜索内容(|分隔)               #
# click_search_content.txt 点击内容：对应的所有用户的输入行为                  #
################################################################################


import pandas as pd
import time
import json
import re
import os
import shutil
import sys

COLUMNNUM=18#14增至18

def parse_data(data):
    "解析数据，包括了增加列索引和切分session"

    # step.1 列索引
    columns = ["uid", "uname", "platform", "atime", "eventorder", "eventname", "suggest_search_key",
               "suggest_search_result_num", "suggest_view_num", "suggest_view_line", "suggest_point_city",
               "suggest_point_airport", "rn","list_point_city","suggest_button_cancel","suggest_other_cancel","list_cancel"]#新增列："list_point_city","suggest_button_cancel","suggest_other_cancel","list_cancel"
    data.columns = columns

    # step.2 切分session
    for k, v in data.groupby("uid"):  # 按照uid聚合
        if len(v.values) != 0:
            split_session(v.values)

    # 输出step5 点击对应的搜索行为存入文件
    with open(cleaned_file_path + "/click_search_content.txt", 'w', encoding='utf-8') as f:
        for k, v in click_city_dict.items():
            str = ""
            for i in v:
                str += (i + ",")
            f.write(k + ":" + str + "\n")
    pass


def split_session(group_list):
    """
	1. 调整错误顺序;
	2. 根据eventorder字段切分session

	:param group_list: 每个按uid聚合，对应的数据集合
	"""

    firstLine = group_list[0]
    previousK = firstLine[4]  # 行为代号: eventorder
    previousTime = firstLine[3]  # 时间戳: atime

    sessionList = [firstLine, ]  # 初始化sessionList,存放一个session的所有line
    for i in range(1, len(group_list)):
        nextLine = group_list[i]
        currentK = nextLine[4]
        currentTime = nextLine[3]

        if currentK >= previousK:
            # 顺序，就是一个session中的数据，添加
            sessionList.append(group_list[i])
            previousK = currentK
            previousTime = currentTime
        else:
            # 逆序，打乱的顺序 or 一个新的session
            # if previousTime[0:len(previousTime) - 1] == currentTime[0:len(currentTime) - 1]:
            if int(currentTime) - int(previousTime) < 20:  # 时间判断(20毫秒内就是顺序打乱的情况)
                sessionList.append(group_list[i])
                parse_sesssion_str(sessionList)#为什么会话在这儿就结束了？感觉有问题！如若如此，previous没有更新，后面肯定有影响的！
                sessionList = []
            else:
                # 开启另一条session,先flush之前的sessionList
                parse_sesssion_str(sessionList)
                sessionList = [group_list[i], ]
                previousK = currentK
                previousTime = currentTime
    # flush最后的session
    parse_sesssion_str(sessionList)


# 统计用户最后一次输入有结果的量（会话中任意一次）
sum_session_has_result = 0


def parse_sesssion_str(session_list):
    """
	1. 将这个sessionList中的数据清洗到suggest_cleaned.txt文件中
	2. 统计用户触发点击之前的搜索次数，搜索内容click_search_route.txt

	:param session_list: 一个session中的数据list，每一个item是一个NumPy
	"""
    global sum_session_has_result
    if len(session_list) == 0:
        return

    # step.1 获取uid, uname, platform, atime,
    firstLine = session_list[0]
    uid = firstLine[0]
    uname = firstLine[1]
    platform = firstLine[2]
    atime = firstLine[3]

    # step.2 获取event
    inputList = []  # 存放用户输入数据的list
    clickBean = ""  # 存放点选数据的Bean

    # print("一个session")

    resultStr = uid + "," + uname + "," + platform + "," + atime + ","
    for tempNumPy in session_list:
        eventorder = tempNumPy[4]
		
        suggest_search_key = tempNumPy[6]
        suggest_view_line = tempNumPy[9]
        list_point_city = tempNumPy[13]
        suggest_button_cancel = tempNumPy[14]
        suggest_other_cancel = tempNumPy[15]
        list_cancel = tempNumPy[16]
		
        if eventorder == "1":
            resultStr += "(进入)~"
        elif eventorder == "2" and suggest_search_key != "K":  # suggest搜索
            inputList.append(SearchBean(tempNumPy[6], tempNumPy[7]))
            resultStr += "(搜索:"+json.dumps(SearchBean(tempNumPy[6], tempNumPy[7]), default=convert_to_dict_type, ensure_ascii=False)+")~"
        elif eventorder == "2" and suggest_button_cancel == "1":#suggest框点击取消按钮取消
            resultStr += "(suggest点击取消按钮取消)~"
        elif eventorder == "2" and suggest_other_cancel == "1":#suggest框点击其他位置取消
            resultStr += "(suggest点击其他位置取消)~"
        elif eventorder == "3" and suggest_view_line != "-9999":  # suggest点选
            clickBean = ClickBean(tempNumPy[8], tempNumPy[9], tempNumPy[10], tempNumPy[11])
            resultStr += "(点击:"+json.dumps(clickBean, default=convert_to_dict_type, ensure_ascii=False)+")~"
        elif eventorder == "3" and list_point_city != "X":#城市列表点选
            resultStr += "(城市列表点击："+list_point_city+")~"
        elif eventorder == "3" and list_cancel == "1":#城市列表页点击取消
            resultStr += "(城市列表取消)~"
        elif eventorder == "4":
            resultStr += "(离开)"

    # 将inputList和clickBean转换成json串
    searchStr = json.dumps(inputList, default=convert_to_dict_type, ensure_ascii=False)
    clickStr = json.dumps(clickBean, default=convert_to_dict_type, ensure_ascii=False)
    # print(clickStr)

    # 针对一些特别的漏打：没有search,有click的情况 处理：直接过滤，约80条
    if searchStr == "[]" and clickStr != "\"\"":
        return

    #eventStr = "(进入)~" + "(搜索:" + searchStr + ")~(点击:" + clickStr + ")~(离开)\n"
    #resultStr = uid + "," + uname + "," + platform + "," + atime + "," + eventStr

    # 有点击的session
    if clickStr != "\"\"":
        data_statistics1(inputList, clickBean.city)
        data_statistics2(inputList, clickBean.city)

    cleaned_file.write(resultStr+"\n")

    for tempNumPy in session_list:
        eventorder = tempNumPy[4]
        suggest_search_result_num = tempNumPy[7]
        if eventorder == "2" and suggest_search_result_num != "-1":  # 统计session中是否有结果的搜索
            sum_session_has_result += 1
            break
    pass


# 存放点击城市，共同输入的字典
click_city_dict = {}


def data_statistics2(inputList, click_city):
    """
		step.5 用户相同点击结果，对应哪些输入行为
	"""

    lastSearchItem = inputList[len(inputList) - 1]
    if click_city not in click_city_dict:
        click_city_dict[click_city] = set()
        click_city_dict[click_city].add(lastSearchItem.key)
    else:
        click_city_dict.get(click_city).add(lastSearchItem.key);
    pass


def data_statistics1(input_list, click_city):
    """
		step.4 用户触发点击之前搜索次数，搜索内容路径
	"""

    inputStr = ""
    for i in range(0, len(input_list)):
        if i != len(input_list) - 1:
            inputStr += (input_list[i].key + "|")
        else:
            # 最后一条
            inputStr += input_list[i].key

    # print(click_city + "," + str(len(input_list)) + "," + inputStr)

    # 结果写入文件(点击结果,搜索路径长度,搜索内容)
    before_click_file.write(click_city + "," + str(len(input_list)) + "," + inputStr + "\n")

    pass


def convert_to_dict_type(obj):
    "把自定义对象MyObj转换成dict类型的对象"
    d = {}
    d.update(obj.__dict__)
    return d


class SearchBean:
    "搜索的Bean，包含了搜索key，和返回个数size"

    key = ""
    size = ""

    def __init__(self, key, size):
        self.key = key
        self.size = size

    def __repr__(self):
        return self.key + ".." + self.size


class ClickBean:
    "点选的Bean，包含了显示个数viewsize，点击行数point，城市名city，机场名airport"

    viewsize = ""
    point = ""
    city = ""
    airport = ""

    def __init__(self, viewsize, point, city, airport):
        self.viewsize = viewsize
        self.point = point
        self.city = city
        self.airport = airport

    def __repr__(self):
        return self.viewsize + ".." + self.point + ".." + self.city + ".." + self.airport


def data_statistics(data):
    """
	数据统计：

	1. 有结果的数据量、点击量
	2. 无结果的数据量
	3. 搜索结果条数量，用户点击的位置的量

	:param data: 去重和清洗的数据
	"""
    # step.1 统计有结果的数据量，点击量
    global sum_session_has_result
    df_search_result_data = data[(data["eventorder"] == "2") & (data["suggest_search_key"] != "K") & (data["suggest_search_result_num"] != "-1")]
    # 查看分布
    # print(pd.value_counts(df_search_result_data.suggest_search_result_num))

    # step.2 无结果的数据量
    df_search_no_result_data = data[(data["eventorder"] == "2") & (data["suggest_search_key"] != "K") & (data["suggest_search_result_num"] == "-1")]
    # print("2. 无结果的搜索量:", len(df_search_no_result_data))

    # step.3 搜索结果条数量，用户点击的位置的量
    df_click_data = data[(data["eventorder"] == "3") & (data["suggest_view_line"] != "-9999")]
    # print("3. 返回结果条数量，用户点击的位置的量", len(df_click_data))

    # 1,2的结果写入文件
    with open(cleaned_file_path + "/search_click_data.txt", 'w', encoding='utf-8') as f:
        f.write("有结果的搜索量: " + str(len(df_search_result_data)) + "\n")
        f.write("最后一次输入有结果的搜索量（会话中任意一次）:" + str(sum_session_has_result) + "\n")
        f.write("无结果的搜索量: " + str(len(df_search_no_result_data)) + "\n")
        f.write("点击量: " + str(len(df_click_data)) + "\n")
        f.write("命中率: " + str("%.2f%%" % (len(df_click_data) / len(df_search_result_data) * 100)) + "\n")
        f.write("最后一次输入有结果的命中率: " + str("%.2f%%" % (len(df_click_data) / sum_session_has_result * 100)) + "\n")
    sum_session_has_result=0#全局变量清零，以应对多个输入文件的情形

    df_click_position = df_click_data[['uid', 'suggest_view_num', 'suggest_view_line']]
    # print("查看点击分布")
    searies_arr = pd.value_counts(df_click_position.suggest_view_line)

    # 输出点击分布
    with open(cleaned_file_path + "/click_position_distribution.txt", 'w', encoding='utf-8') as f:
        f.write("用户点击结果分布：" "\n")
        for idx in searies_arr.index:
            f.write(idx + "\t" + str(searies_arr[idx]) + "\n")

    # 输出点击源数据
    with open(cleaned_file_path + "/click_position_source_data.txt", 'w', encoding='utf-8') as f:
        for temp in df_click_position.values:
            f.write(temp[0] + "," + temp[1] + "," + temp[2] + "\n")
    pass


def main(file_dir, file_name):
    "读取数据;清洗数据;统计数据"

    # 1 读取File,初始化数据到DataFrame
    wrong_lines = []
    right_lines = []
    distinctSet = set()  # 去重set
    with open(file_dir + file_name, "r", encoding='utf-8') as f:
        for line in f.readlines():
            line_splits = line.split(",")
            if len(line_splits) == COLUMNNUM and "00000000000000" not in line_splits[0]:  # 过滤掉0000
                try:  # 过滤掉异常suggest_search_result_num异常的字段
                    x = int(line_splits[7])
                    if x < -1 and x != -9999:
                        continue
                except ValueError:
                    continue
                prefixStr = line_splits[0] + line_splits[3] + line_splits[4]  # 去重字段，UID+时间戳+行为代码
                if prefixStr in distinctSet:
                    continue
                else:
                    right_lines.append(line_splits[0:COLUMNNUM-1])#去除最后一列的action
                distinctSet.add(prefixStr)
            else:
                wrong_lines.append(line_splits)
    # print("wrong_lines", len(wrong_lines))  # 约2w条

    # 2 处理原始数据
    data = pd.DataFrame(right_lines)

    parse_data(data)
    cleaned_file.close()
    before_click_file.close()

    # 3 数据统计
    data_statistics(data)
    pass


# 默认目标文件位置
cleaned_file_path = "D:/"
# 清洗输出文件
cleaned_file = ""
# 点击搜索路径文件
before_click_file = ""

if __name__ == '__main__':
    """
		程序入口 参数：input_dir output_dir
	"""
    input_dir = "C:/Users/senzs.zhang/Desktop/suggest_temp/"
    output_dir = "C:/Users/senzs.zhang/Desktop/suggest_output/"
    # input_dir = sys.argv[1]
    # output_dir = sys.argv[2]

    # 对目录中所有文件迭代
    pathDir = os.listdir(input_dir)
    for childFile in pathDir:
        fileName = childFile
        # 1.匹配到了时间，则根据时间创建输出目录，没有则使用是默认目录
        m = re.search("\d+", fileName)
        if m:
            cleaned_file_path = output_dir + "/" + m.group() + "_cleaned/"
            if os.path.exists(cleaned_file_path):  # 目录存在，先删除
                shutil.rmtree(cleaned_file_path)
            os.makedirs(cleaned_file_path)

        # 创建清洗结果文件
        cleaned_file = open(cleaned_file_path + "/suggest_cleaned.txt", "a+", encoding='utf-8')
        # 创建点击前搜索路径文件
        before_click_file = open(cleaned_file_path + "/click_search_route.txt", "a+", encoding='utf-8')

        print('start calc, input_dir:', input_dir, ', file:', fileName)
        start = time.time()
        main(input_dir, fileName)
        end = time.time()
        print('finish, time:', end - start)
        pass
