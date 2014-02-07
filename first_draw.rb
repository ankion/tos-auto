# -*- encoding : utf-8 -*-
require "./api"
require './checksum'
require "./monster"
require 'json'
require 'logger'
require 'mechanize'

@tos_url = Settings['tos_url']

def general_uniquekey(deviceKey)
  seed_string = "#{deviceKey}#{Time.now.to_i}#{rand(999999999)}"
  Digest::MD5.hexdigest(seed_string)
end
#########################################
def general_devicekey
  seed_string = "#{Time.now.to_i}#{rand(999999999)}"
  Digest::MD5.hexdigest(seed_string)
end

def is_good_card(card_id)
  goods = [
    # 西遊神
    221,222,223,224,225,226,227,228,229,230,
    # 希臘神
    191,192,193,194,195,196,197,198,199,200,
    # 北歐神
    201,202,203,204,205,206,207,208,209,210,
    # 龍魂使
    413,414,415,416,417,418,419,420,421,422,
    # 新狂魔
    466,467,468,469,470,471,472,473,474,475,
    # 十二宮
    355,356,357,358,359,360,361,362,363,364,365,366,
    367,368,369,370,371,372,373,374,375,376,377,378,
    # 三巫
    344,345,346,347,348,349,
    # 埃及神
    211,212,213,214,215,216,217,218,219,220,
    # 魔族
    388,389,390,391,392,393,394,395,396,397,
    # 五星中國神獸
    24,28,32,36,40,
    # 五星妹子
    118,121,124,127,130,
    # 五星西方魔獸
    178,181,184,187,190,
    # 五星異界龍
    310,312,314,316,318
  ]
  goods.include? card_id.to_i
end
#########################################
def send_tos(web,encypt,url)
  res_json = nil
  begin
    full_url = "http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}"
    page = web.post(full_url, {
      "systemInfo" => "%7b%22appVersion%22%3a%224.54%22%2c%22deviceModel%22%3a%22Motorola+MB525%22%2c%22deviceType%22%3a%22Handheld%22%2c%22deviceUniqueIdentifier%22%3a%22#{@dKey}%22%2c%22operatingSystem%22%3a%22Android+OS+2.3.7+%2f+API-10+(GWK74%2f20130501)%22%2c%22systemVersion%22%3a%222.3.7%22%2c%22processorType%22%3a%22ARMv7+VFPv3+NEON%22%2c%22processorCount%22%3a%221%22%2c%22systemMemorySize%22%3a%22477%22%2c%22graphicsMemorySize%22%3a%2235%22%2c%22graphicsDeviceName%22%3a%22PowerVR+SGX+530%22%2c%22graphicsDeviceVendor%22%3a%22Imagination+Technologies%22%2c%22graphicsDeviceVersion%22%3a%22OpenGL+ES-CM+1.1%22%2c%22emua%22%3a%22FALSE%22%2c%22emub%22%3a%22FALSE%22%2c%22npotSupport%22%3a%22None%22%2c%22supportsAccelerometer%22%3a%22True%22%2c%22supportsGyroscope%22%3a%22False%22%2c%22supportsLocationService%22%3a%22True%22%2c%22supportsVibration%22%3a%22True%22%2c%22maxTextureSize%22%3a%222048%22%2c%22screenWidth%22%3a%22480%22%2c%22screenHeight%22%3a%22854%22%2c%22screenDPI%22%3a%22264.7876%22%2c%22IDFA%22%3a%22%22%2c%22IDFV%22%3a%22%22%2c%22MAC%22%3a%2240%3afc%3a89%3a02%3ab3%3a55%22%2c%22networkType%22%3a%22WIFI%22%7d",
      "frags" => Digest::MD5.hexdigest(Digest::MD5.hexdigest(full_url)),
      "attempt" => "1"
    })
    #page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
    res_json = JSON.parse(page.body)
    respond = res_json['respond'].to_i
    if respond != 1
      print '\n'
      if respond == 6
        # 6=error
        puts res_json.inspect
        def_wait = 60
        wait = 0
        begin
          wait=Integer(res_json['wait'])
        rescue
          wait=60
        end
        wait = def_wait if wait == 0
        print "retry after #{wait} secs > "
        print_wait(wait)
      else
        puts res_json.inspect
        exit
      end
    end
  rescue
    puts res_json.inspect
    exit
  end while res_json != nil && res_json['respond'].to_i == 6
  return res_json
end
#########################################
count = 500
@dKey = nil
@monster = Monster.new
=begin
nowT = Time.new
nowTStr = nowT.strftime("%Y%m%d%H%M%S")
=end
nowTStr = "accountlist.log"
@logger = Logger.new(nowTStr)
@good_logger = Logger.new("good_account.log")
index = 0
count.times do
  encypt = Checksum.new
  deviceKey = general_devicekey
  @dKey = deviceKey
  uniqueKey = general_uniquekey(deviceKey)
  web = Mechanize.new { |agent|
    agent.follow_meta_refresh = true
  }
  index = index + 1
  puts "[#{index}/#{count}|#{deviceKey}|#{uniqueKey}]"
  print 'user/register > '
  url = "/api/user/register?type=device&name=king&attribute=1&uniqueKey=#{uniqueKey}&deviceKey=#{deviceKey}&sysInfo=Android+OS+2.3.7+%2f+API-10+(GWK74%2f20130501)%7cARMv7+VFPv3+NEON%7c1%7c477%7c35%7cPowerVR+SGX+530%7cFALSE%7cOpenGL+ES-CM+1.1%7cNone%7cFALSE%7c2048%7c3.27%7c%7c%7c40%3afc%3a89%3a02%3ab3%3a55&session=&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  res_json = send_tos(web,encypt,url)
  parsed = @monster.data.has_key?("1") && @monster.data["1"].has_key?(:monsterId)
  @monster.parse_normal_skill(res_json['data']['normalSkills']) if !parsed
  @monster.parse_data(res_json['data']['monsters']) if !parsed
  uData = res_json['user']
  uid = res_json['user']['uid']
  session = res_json['user']['session']
  print "#{uid}/#{session} "
  puts_wait(1)
###############################################
  print 'floor/enter > '
  url = "/api/floor/enter?floorId=1&team=0&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}&tutorialVersion=2"
  res_json = send_tos(web,encypt,url)
  floorHash = res_json['data']['floorHash']
  print_wait(20)
###############################################
  print 'floor/complete > '
  url = "/api/floor/complete?floorId=1&team=0&floorHash=#{floorHash}&waves=3&maxAttack=34&maxCombo=3&minLoad=151.123046875&maxLoad=3362.57885742188&avgLoad=825.908402876421&bootTime=17657.2880859375&a=4&b=3&c=0%2c0%2c0%2c0%2c0%2c0&d=0&e=82.80643&f=3&g=3&h=0&i=1&j=1&k=36&l=180&n=&o=144&p=144&r=144&s=0&t=0&u=75&v=75&w=75&x=167&acsh=14a79b7ae0ae352aeb7e6a15a75cd500&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  res_json = send_tos(web,encypt,url)
  print_wait(1)
###############################################
  print 'user/team/save > '
  url = "/api/user/team/save?team0=1%2c2%2c3%2c4%2c0&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  res_json = send_tos(web,encypt,url)
  print_wait(1)
###############################################
  print 'floor/helpers > '
  url = "/api/floor/helpers?floorId=2&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  res_json = send_tos(web,encypt,url)
  helperListStr = res_json['data']['alluserList']
  helperList = helperListStr[0].split('|')
  helperUid = helperList[0]
  print_wait(1)
###############################################
  print 'floor/enter > '
  url = "/api/floor/enter?floorId=2&team=0&helperUid=#{helperUid}&clientHelperCard=10005%7c116%7c2468%7c7%7c2%7c0%7c0&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}&tutorialVersion=2"
  res_json = send_tos(web,encypt,url)
  floorHash = res_json['data']['floorHash']
  print_wait(20)
###############################################
  print 'floor/complete > '
  url = "/api/floor/complete?floorId=2&team=0&floorHash=#{floorHash}&helper_uid=#{helperUid}&waves=3&maxAttack=105&maxCombo=3&minLoad=108.06201171875&maxLoad=3362.57885742188&avgLoad=468.569119966947&bootTime=17657.2880859375&a=7&b=3&c=0%2c0%2c0%2c0%2c0%2c0&d=0&e=72.23418&f=3&g=5&h=0&i=1&j=1&k=424&l=444&n=&o=20&p=20&r=20&s=0&t=0&u=294&v=294&w=294&x=317&acsh=6326e49693f85c18417fdff284c13ad2&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  res_json = send_tos(web,encypt,url)
  print_wait(1)
###############################################
  print 'card/merge > '
  url = "/api/card/merge?sourceCardId=1&targetCardIds=5&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  res_json = send_tos(web,encypt,url)
  print_wait(1)
###############################################
  print 'card/evolve > '
  url = "/api/card/evolve?sourceCardId=1&targetCardIds=6&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  res_json = send_tos(web,encypt,url)
  print_wait(1)
###############################################
  print 'floor/helpers > '
  url = "/api/floor/helpers?floorId=3&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  res_json = send_tos(web,encypt,url)
  helperList = res_json['data']['alluserList'][0].split('|')
  helperUid = helperList[0]
  print_wait(1)
###############################################
  print 'floor/enter > '
  url = "/api/floor/enter?floorId=3&team=0&helperUid=#{helperUid}&clientHelperCard=10007%7c23%7c175136%7c30%7c2%7c0%7c0&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}&tutorialVersion=2"
  res_json = send_tos(web,encypt,url)
  floorHash = res_json['data']['floorHash']
  print_wait(20)
###############################################
  print 'floor/complete > '
  url = "/api/floor/complete?floorId=3&team=0&floorHash=#{floorHash}&helper_uid=#{helperUid}&waves=3&maxAttack=1147&maxCombo=5&minLoad=80.994140625&maxLoad=3362.57885742188&avgLoad=344.047047932943&bootTime=17657.2880859375&a=3&b=3&c=1%2c0%2c0%2c0%2c0%2c0&d=0&e=51.50079&f=3&g=5&h=0&i=0&j=1&k=1616&l=1616&n=&o=0&p=0&r=0&s=0&t=0&u=580&v=580&w=580&x=493&acsh=6defba64223421bc6629eccf2b7f69a8&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  res_json = send_tos(web,encypt,url)
  print_wait(1)
###############################################
  print 'user/diamond/luckydraw > '
  url = "/api/user/diamond/luckydraw?quantity=1&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  res_json = send_tos(web,encypt,url)
  monster = res_json['data']['card']
  puts monster
  print_wait(1)
###############################################
  print 'user/set_helper > '
  url = "/api/user/set_helper?cardId=#{monster['cardId']}&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.54&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  res_json = send_tos(web,encypt,url)
  puts ""
###############################################
  puts "deviceKey:#{deviceKey}"
  puts "uniqueKey:#{uniqueKey}"
  puts "uid:#{uid}"
  mId = monster['monsterId']
  first_card = @monster.data[mId]
  mIdFmt = "%03d" %mId
  mName = first_card[:monsterName]
  puts "<#{monster['level']}> #{mIdFmt} #{mName}"
  hehagame = "http://tos.hehagame.com/Category_show.php?ide=#{mIdFmt}".blue.bold.ul
  puts hehagame
###############################################
  if is_good_card(mId)
    @good_logger.info "#{mIdFmt}|#{mName}|#{uid}|#{uniqueKey}|#{deviceKey}"
  else
    @logger.info "#{mIdFmt}|#{mName}|#{uid}|#{uniqueKey}|#{deviceKey}"
  end
  print 'wait to next : '
  puts_wait(3)
end
