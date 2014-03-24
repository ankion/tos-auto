# -*- encoding : utf-8 -*-
require "./api"
require "./user"
require 'json'
require 'logger'

def general_uniquekey(deviceKey)
  seed_string = "#{deviceKey}#{Time.now.to_i}#{rand(999999999)}"
  Digest::MD5.hexdigest(seed_string)
end
#########################################
def general_devicekey
  seed_string = "#{Time.now.to_i}#{rand(999999999)}"
  Digest::MD5.hexdigest(seed_string)
end

def is_best_card(card_id)
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
    367,368,369,370,371,372,373,374,375,376,377,378
  ]
  goods.include? card_id.to_i
end
def is_good_card(card_id)
  goods = [
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
count = 500
nowTStr = "card/accountlist.log"
dir = File.dirname(nowTStr)
FileUtils.mkdir_p(dir) unless File.directory?(dir)
@logger = Logger.new(nowTStr)
@good_logger = Logger.new("card/good_account.log")
@best_logger = Logger.new("card/best_account.log")
index = 0
count.times do
  deviceKey = general_devicekey
  uniqueKey = general_uniquekey(deviceKey)
  user = User.new(uniqueKey, deviceKey)
  index = index + 1
  puts "[#{index}/#{count}|#{deviceKey}|#{uniqueKey}]"
  print 'user/register > '
  user.register('king', 1)
  print "#{user.data['uid']}/#{user.data['session']} "
  puts_wait(1)

  user.select_team(1)
###############################################
  floor = user.floor(user.find_floor_by(1))
  print 'floor/enter > '
  floor.enter
  floor.fight
  print_wait(20)
###############################################
  print 'floor/complete > '
  floor.complete
  print_wait(1)
###############################################
  print 'user/team/save > '
  user.team_save(0, "1,2,3,#{floor.loots.first['cardId']},0")
  print_wait(1)
###############################################
  floor = user.floor(user.find_floor_by(2))
  print 'floor/helpers > '
  floor.get_helpers
  floor.choice_helper = 0
  print_wait(1)
###############################################
  print 'floor/enter > '
  floor.enter
  floor.fight
  print_wait(20)
###############################################
  print 'floor/complete > '
  floor.complete
  print_wait(1)
###############################################
  print 'card/merge > '
  if floor.loots.count > 1
    user.merge_card(1, [floor.loots.first['cardId']])
    print_wait(1)
###############################################
    print 'card/evolve > '
    user.evolve_card(1, [floor.loots.last['cardId']])
    print_wait(1)
  end
###############################################
  floor = user.floor(user.find_floor_by(3))
  print 'floor/helpers > '
  floor.get_helpers
  floor.choice_helper = 0
  print_wait(1)
###############################################
  print 'floor/enter > '
  floor.enter
  floor.fight
  print_wait(20)
###############################################
  print 'floor/complete > '
  floor.complete
  print_wait(1)
###############################################
  print 'user/diamond/luckydraw > '
  card = user.luckydraw
  monster = card['monster']
  print_wait(1)
###############################################
  print 'user/set_helper > '
  user.set_helper(card['cardId'])
  puts ""
###############################################
  puts "<#{monster['level']}> #{monster['monsterId']} #{monster['monsterName']}"
  hehagame = "http://tos.hehagame.com/Category_show.php?ide=#{monster['monsterId']}".blue.bold.ul
  puts hehagame
###############################################
  if is_best_card(monster['monsterId'])
    @best_logger.info "#{monster['monsterId']}|#{monster['monsterName']}|#{user.data['uid']}|#{uniqueKey}|#{deviceKey}"
  elsif is_good_card(monster['monsterId'])
    @good_logger.info "#{monster['monsterId']}|#{monster['monsterName']}|#{user.data['uid']}|#{uniqueKey}|#{deviceKey}"
  else
    @logger.info "#{monster['monsterId']}|#{monster['monsterName']}|#{user.data['uid']}|#{uniqueKey}|#{deviceKey}"
  end
  print 'wait to next : '
  puts_wait(3)
end
