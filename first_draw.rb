require './checksum'
require "./monster"
require 'json'
require 'logger'
require 'mechanize'

def general_uniquekey(deviceKey)
  seed_string = "#{deviceKey}#{Time.now.to_i}#{rand(999999999)}"
  Digest::MD5.hexdigest(seed_string)
end

def general_devicekey
  seed_string = "#{Time.now.to_i}#{rand(999999999)}"
  Digest::MD5.hexdigest(seed_string)
end

count = 48 * 1
@monster = Monster.new
@logger = Logger.new("accountlist.log")
count.times do |index|
  puts "#(#{index + 1}/#{count})"
  encypt = Checksum.new
  deviceKey = general_devicekey
  uniqueKey = general_uniquekey(deviceKey)

  web = Mechanize.new { |agent|
    agent.follow_meta_refresh = true
  }
  puts 'user/register'
  url = "/api/user/register?type=device&name=king&attribute=1&uniqueKey=#{uniqueKey}&deviceKey=#{deviceKey}&sysInfo=Android+OS+2.3.7+%2f+API-10+(GWK74%2f20130501)%7cARMv7+VFPv3+NEON%7c1%7c477%7c35%7cPowerVR+SGX+530%7cFALSE%7cOpenGL+ES-CM+1.1%7cNone%7cFALSE%7c2048%7c3.27%7c%7c%7c40%3afc%3a89%3a02%3ab3%3a55&session=&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  #puts url
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  1.times do
    print '.'
    sleep 1.0
  end
  print "\n"
  uid = res_json['user']['uid']
  session = res_json['user']['session']

  puts 'floor/enter'
  url = "/api/floor/enter?floorId=1&team=0&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}&tutorialVersion=2"
  #puts "http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}"
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  20.times do
    print '.'
    sleep 1.0
  end
  print "\n"
  floorHash = res_json['data']['floorHash']

  puts 'floor/complete'
  url = "/api/floor/complete?floorId=1&team=0&floorHash=#{floorHash}&waves=3&maxAttack=34&maxCombo=3&minLoad=151.123046875&maxLoad=3362.57885742188&avgLoad=825.908402876421&bootTime=17657.2880859375&a=4&b=3&c=0%2c0%2c0%2c0%2c0%2c0&d=0&e=82.80643&f=3&g=3&h=0&i=1&j=1&k=36&l=180&n=&o=144&p=144&r=144&s=0&t=0&u=75&v=75&w=75&x=167&acsh=14a79b7ae0ae352aeb7e6a15a75cd500&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  #puts url
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  1.times do
    print '.'
    sleep 1.0
  end
  print "\n"

  puts 'user/team/save'
  url = "/api/user/team/save?team0=1%2c2%2c3%2c4%2c0&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  #puts url
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  1.times do
    print '.'
    sleep 1.0
  end
  print "\n"

  puts 'floor/helpers'
  url = "/api/floor/helpers?floorId=2&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  #puts url
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  1.times do
    print '.'
    sleep 1.0
  end
  print "\n"
  helperListStr = res_json['data']['alluserList']
  helperList = helperListStr[0].split('|')
  helperUid = helperList[0]


  puts 'floor/enter'
  url = "/api/floor/enter?floorId=2&team=0&helperUid=#{helperUid}&clientHelperCard=10005%7c116%7c2468%7c7%7c2%7c0%7c0&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}&tutorialVersion=2"
  #puts url
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  20.times do
    print '.'
    sleep 1.0
  end
  print "\n"
  floorHash = res_json['data']['floorHash']

  puts 'floor/complete'
  url = "/api/floor/complete?floorId=2&team=0&floorHash=#{floorHash}&helper_uid=#{helperUid}&waves=3&maxAttack=105&maxCombo=3&minLoad=108.06201171875&maxLoad=3362.57885742188&avgLoad=468.569119966947&bootTime=17657.2880859375&a=7&b=3&c=0%2c0%2c0%2c0%2c0%2c0&d=0&e=72.23418&f=3&g=5&h=0&i=1&j=1&k=424&l=444&n=&o=20&p=20&r=20&s=0&t=0&u=294&v=294&w=294&x=317&acsh=6326e49693f85c18417fdff284c13ad2&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  #puts url
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  1.times do
    print '.'
    sleep 1.0
  end
  print "\n"

  puts 'card/merge'
  url = "/api/card/merge?sourceCardId=1&targetCardIds=5&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  #puts url
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  1.times do
    print '.'
    sleep 1.0
  end
  print "\n"

  puts 'card/evolve'
  url = "/api/card/evolve?sourceCardId=1&targetCardIds=6&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  #puts url
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  1.times do
    print '.'
    sleep 1.0
  end
  print "\n"


  puts 'floor/helpers'
  url = "/api/floor/helpers?floorId=3&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  #puts url
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  1.times do
    print '.'
    sleep 1.0
  end
  print "\n"
  helperList = res_json['data']['alluserList'][0].split('|')
  helperUid = helperList[0]


  puts 'floor/enter'
  url = "/api/floor/enter?floorId=3&team=0&helperUid=#{helperUid}&clientHelperCard=10007%7c23%7c175136%7c30%7c2%7c0%7c0&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}&tutorialVersion=2"
  #puts url
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  20.times do
    print '.'
    sleep 1.0
  end
  print "\n"
  floorHash = res_json['data']['floorHash']

  puts 'floor/complete'
  url = "/api/floor/complete?floorId=3&team=0&floorHash=#{floorHash}&helper_uid=#{helperUid}&waves=3&maxAttack=1147&maxCombo=5&minLoad=80.994140625&maxLoad=3362.57885742188&avgLoad=344.047047932943&bootTime=17657.2880859375&a=3&b=3&c=1%2c0%2c0%2c0%2c0%2c0&d=0&e=51.50079&f=3&g=5&h=0&i=0&j=1&k=1616&l=1616&n=&o=0&p=0&r=0&s=0&t=0&u=580&v=580&w=580&x=493&acsh=6defba64223421bc6629eccf2b7f69a8&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  #puts url
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  1.times do
    print '.'
    sleep 1.0
  end
  print "\n"


  puts 'user/diamond/luckydraw'
  url = "/api/user/diamond/luckydraw?quantity=1&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  #puts url
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  1.times do
    print '.'
    sleep 1.0
  end
  print "\n"
  monster = res_json['data']['card']


  puts 'user/set_helper'
  url = "/api/user/set_helper?cardId=#{monster['cardId']}&uid=#{uid}&session=#{session}&language=zh_TW&platform=android&version=4.03&timestamp=#{Time.now.to_i}&timezone=8&nData=#{encypt.getNData}"
  #puts url
  page = web.get("http://zh.towerofsaviors.com#{url}&hash=#{encypt.getHash(url, '')}")
  res_json = JSON.parse(page.body)
  if res_json['respond'].to_i != 1
    puts res_json.inspect
    exit
  end
  1.times do
    print '.'
    sleep 1.0
  end
  print "\n"

  puts "deviceKey:#{deviceKey}"
  puts "uniqueKey:#{uniqueKey}"
  puts "uid:#{uid}"
  first_card = @monster.data[monster['monsterId']]
  puts "#{monster['monsterId']} #{first_card[:monsterName]}"
  puts "http://tos.hehagame.com/Category_show.php?ide=#{monster['monsterId']}"
  @logger.info "#{monster['monsterId']}|#{first_card[:monsterName]}|#{uid}|#{uniqueKey}|#{deviceKey}"
end
