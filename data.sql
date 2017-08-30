select uid, uname, platform, atime, eventorder, eventname
, suggest_search_key,suggest_search_result_num
,suggest_view_num,suggest_view_line,suggest_point_city,suggest_point_airport
, ROW_NUMBER() OVER(PARTITION BY uid ORDER BY otime, eventorder) AS rn
,list_point_city--城市列表点选内容
,suggest_button_cancel--suggest按钮取消
,suggest_other_cancel--suggest其他取消
,list_cancel--城市列表取消
, action
from (
select uid, uname, platform
, split(action, '\\*')[0] as atime
, (split(action, '\\*')[0] - split(action, '\\*')[0] % 10 ) as otime
, action
, case
 WHEN (instr(action, 'to*FCityVC*') > 0
 or instr(action, 'to*flight.FlightCityActivity*') >0)
  THEN '4'
 WHEN (instr(action, 'to*') > 0
 and instr(action, '*FCityVC') > 0
 )
        or
 (instr(action, 'to*') > 0
 and instr(action, '*flight.FlightCityActivity') > 0
 )
  THEN '1'
 WHEN instr(action, 'set*FCityVCNetResult') > 0
 THEN '2'
 WHEN instr(action, 'click**FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/UIView[0_0_0_0_#00000099]/SUIButton[FCityVC_searchCancel：_0_0_0_0]*')>0
 THEN '2'--suggest其他取消
 WHEN instr(action, 'click**FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/NaviBar[0_0_0_0]/SearchBar[0_0_0_0]/UIButton[SearchBar_searchBarButtonClicked：_1_1_1_0]*取消*')>0
 THEN '2'--suggest按钮取消
 WHEN instr(action, 'set*FCityVCNetClick') > 0
 THEN '3'
 WHEN (instr(action, 'click*')>0
  and instr(action, '*FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/FIndexTableView[0_1_0_0]/UITableViewPlainCell[-]*')>0
  )
      or
  (instr(action,'onItemClick:LinearLayout*0*ContextImpl:/MainWindow/FrameLayout[0]/LinearLayout[0]/LinearLayout[1]/LinearLayout[0]/LinearLayout[1]/RelativeLayout[3]/AmazingListView[2]/LinearLayout[-]*')>0)
  THEN '3'--城市列表点选
 WHEN instr(action, 'click**FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/NaviBar[0_0_0_0]/NaviBarItem[0_0_0_0]/SUIButton[FCityVC_goBack：_0_0_0_0]*取消*')>0
  or instr(action, '*onClick:TextView**flight.FlightCityActivity:/MainWindow/FrameLayout[0]/LinearLayout[0]/LinearLayout[1]/LinearLayout[0]/LinearLayout[1]/LinearLayout[0]/TextView[1]*取消*')>0
  THEN '3'--城市列表取消
 ELSE '#'
 END
 AS eventorder
--进入城市列表：1

--SUGGEST结果：2
--SUGGEST按钮取消：2 
--SUGGEST其他取消：2

--SUGGEST点选：3
--城市列表点选：3
--城市列表取消：3

--离开城市列表：4
, case
 WHEN (instr(action, 'to*FCityVC*') > 0
 or instr(action, 'to*flight.FlightCityActivity*') >0)
  THEN '离开城市列表'
 WHEN (instr(action, 'to*') > 0
 and instr(action, '*FCityVC') > 0
 )
        or
 (instr(action, 'to*') > 0
 and instr(action, '*flight.FlightCityActivity') > 0
 )
  THEN '进入城市列表'
 WHEN instr(action, 'set*FCityVCNetResult') > 0
 THEN 'SUGGEST结果'
 WHEN instr(action, 'click**FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/UIView[0_0_0_0_#00000099]/SUIButton[FCityVC_searchCancel：_0_0_0_0]*')>0
 THEN 'SUGGEST其他取消'
 WHEN instr(action, 'click**FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/NaviBar[0_0_0_0]/SearchBar[0_0_0_0]/UIButton[SearchBar_searchBarButtonClicked：_1_1_1_0]*取消*')>0
 THEN 'SUGGEST按钮取消'
 WHEN instr(action, 'set*FCityVCNetClick') > 0
 THEN 'SUGGEST点选'
 WHEN (instr(action, 'click*')>0
  and instr(action, '*FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/FIndexTableView[0_1_0_0]/UITableViewPlainCell[-]*')>0
  )
      or
  (instr(action,'onItemClick:LinearLayout*0*ContextImpl:/MainWindow/FrameLayout[0]/LinearLayout[0]/LinearLayout[1]/LinearLayout[0]/LinearLayout[1]/RelativeLayout[3]/AmazingListView[2]/LinearLayout[-]*')>0)
  THEN '城市列表点选'
 WHEN instr(action, 'click**FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/NaviBar[0_0_0_0]/NaviBarItem[0_0_0_0]/SUIButton[FCityVC_goBack：_0_0_0_0]*取消*')>0
  or instr(action, '*onClick:TextView**flight.FlightCityActivity:/MainWindow/FrameLayout[0]/LinearLayout[0]/LinearLayout[1]/LinearLayout[0]/LinearLayout[1]/LinearLayout[0]/TextView[1]*取消*')>0
 THEN '城市列表取消'
 ELSE 'unknow'
 END
 AS eventname
, CASE
 WHEN instr(action, 'set*FCityVCNetResult') > 0
 THEN regexp_extract(action, '.*set\\*FCityVCNetResult：(.*?)-.*', 1)
  ELSE 'K'
 END
 AS suggest_search_key
, CASE
 WHEN instr(action, 'set*FCityVCNetResult') > 0
 THEN regexp_extract(action, '.*set\\*FCityVCNetResult：.*?-(.*)', 1)
  ELSE '-9999'
 END
 AS suggest_search_result_num
, CASE
 WHEN instr(action, 'set*FCityVCNetClick') > 0
 THEN regexp_extract(action, '.*set\\*FCityVCNetClick：([0-9]*)-.*', 1)
  ELSE '-9999'
 END
 AS suggest_view_num
, CASE
 WHEN instr(action, 'set*FCityVCNetClick') > 0
 THEN regexp_extract(action, '.*set\\*FCityVCNetClick：([0-9]*)-([0-9]*)-.*', 2)
  ELSE '-9999'
 END
 AS suggest_view_line
, CASE
WHEN instr(action, 'set*FCityVCNetClick') > 0 AND platform = 'ios'
 THEN regexp_extract(action, '.*set\\*FCityVCNetClick：([0-9]*)-([0-9]*)-(.*?)-(.*)', 3)
WHEN instr(action, 'set*FCityVCNetClick') > 0 AND platform = 'adr'
 THEN regexp_extract(action, '.*set\\*FCityVCNetClick：([0-9]*)-([0-9]*)-(.*)', 3)
  ELSE 'X'
 END
 AS suggest_point_city
, CASE
WHEN instr(action, 'set*FCityVCNetClick') > 0 AND platform = 'ios'
 THEN regexp_extract(action, '.*set\\*FCityVCNetClick：([0-9]*)-([0-9]*)-(.*?)-(.*)', 4)
WHEN instr(action, 'set*FCityVCNetClick') > 0 AND platform = 'adr'
 THEN regexp_extract(action, '.*set\\*FCityVCNetClick：([0-9]*)-([0-9]*)-(.*)', 3)
  ELSE 'X'
 END
 AS suggest_point_airport
 , CASE
 WHEN instr(action, 'click*')>0
  and instr(action, '*FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/FIndexTableView[0_1_0_0]/UITableViewPlainCell[-]*')>0
  and platform ='ios'
 THEN regexp_extract(action,'.*click\\*.*\\*FCityVC:in:/UIWindow\\[0_0_0_0\\]/RootVCController\\[0_0_0_0_\\#FFFFFFFF\\]/FCityVC\\[0_0_0_0_\\#EFEFF4FF\\]/FIndexTableView\\[0_1_0_0\\]/UITableViewPlainCell\\[-\\]\\*(.*)\\*.*\\*',1)
 WHEN instr(action, 'onItemClick:LinearLayout*0*ContextImpl:/MainWindow/FrameLayout[0]/LinearLayout[0]/LinearLayout[1]/LinearLayout[0]/LinearLayout[1]/RelativeLayout[3]/AmazingListView[2]/LinearLayout[-]*')>0
  and platform ='adr'
 THEN regexp_extract(action,'.*onItemClick:LinearLayout\\*0\\*ContextImpl:/MainWindow/FrameLayout\\[0\\]/LinearLayout\\[0\\]/LinearLayout\\[1\\]/LinearLayout\\[0\\]/LinearLayout\\[1\\]/RelativeLayout\\[3\\]/AmazingListView\\[2\\]/LinearLayout\\[-\\]\\*(.*)\\*.*\\*',1)
 ELSE 'X'
 END
 AS list_point_city--城市列表点选
,CASE
 WHEN instr(action, 'click**FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/NaviBar[0_0_0_0]/SearchBar[0_0_0_0]/UIButton[SearchBar_searchBarButtonClicked：_1_1_1_0]*取消*')>0
 THEN '1'
 ELSE '0'
 END
 AS suggest_button_cancel--suggest按钮取消
,CASE
 WHEN instr(action, 'click**FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/UIView[0_0_0_0_#00000099]/SUIButton[FCityVC_searchCancel：_0_0_0_0]*')>0
 THEN '1'
 ELSE '0'
 END
 AS suggest_other_cancel--suggest其他取消
,CASE
 WHEN instr(action, 'click**FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/NaviBar[0_0_0_0]/NaviBarItem[0_0_0_0]/SUIButton[FCityVC_goBack：_0_0_0_0]*取消*')>0
  or instr(action, '*onClick:TextView**flight.FlightCityActivity:/MainWindow/FrameLayout[0]/LinearLayout[0]/LinearLayout[1]/LinearLayout[0]/LinearLayout[1]/LinearLayout[0]/TextView[1]*取消*')>0
 THEN '1'
 ELSE '0'
 END
 AS list_cancel--城市列表取消

 from flightdata.ods_client_behavior_hour4spark
where dt='2017-08-28'
and (vid >= 80011139 or (vid >= 60001173 and vid < 80000000))
and
(
 action like '%set*FCityVCNetClick%'--suggest选中结果
 or action like '%set*FCityVCNetResult%'--suggest返回结果
 or action like '%to*FCityVC*%'--ios离开城市列表
 or action like '%to*%*FCityVC%'--ios进入城市列表
 or action like '%to*%*flight.FlightCityActivity*%'--adr进入城市列表
 or action like '%to*flight.FlightCityActivity*%'--adr离开城市列表
 or action like '%click*%*FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/FIndexTableView[0_1_0_0]/UITableViewPlainCell[-]*%'--ios点击城市列表
 or action like '%onItemClick:LinearLayout*0*ContextImpl:/MainWindow/FrameLayout[0]/LinearLayout[0]/LinearLayout[1]/LinearLayout[0]/LinearLayout[1]/RelativeLayout[3]/AmazingListView[2]/LinearLayout[-]*%'--adr点击城市列表
 or action like '%click**FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/UIView[0_0_0_0_#00000099]/SUIButton[FCityVC_searchCancel：_0_0_0_0]*%'--ios在suggest输入框未操作点击其他位置取消
 or action like '%click**FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/NaviBar[0_0_0_0]/SearchBar[0_0_0_0]/UIButton[SearchBar_searchBarButtonClicked：_1_1_1_0]*取消*%'--ios在suggest输入框未操作点击“取消”按钮取消
 or action like '%click**FCityVC:in:/UIWindow[0_0_0_0]/RootVCController[0_0_0_0_#FFFFFFFF]/FCityVC[0_0_0_0_#EFEFF4FF]/NaviBar[0_0_0_0]/NaviBarItem[0_0_0_0]/SUIButton[FCityVC_goBack：_0_0_0_0]*取消*%'--ios在城市列表页点击取消
 or action like '%*onClick:TextView**flight.FlightCityActivity:/MainWindow/FrameLayout[0]/LinearLayout[0]/LinearLayout[1]/LinearLayout[0]/LinearLayout[1]/LinearLayout[0]/TextView[1]*取消*%'--adr在城市列表页点击取消
)
) ttp
limit 1000;