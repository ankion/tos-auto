# -*- encoding : utf-8 -*-
require 'json'
require 'logger'
require 'readline'
require './api'
require './user'
require './setting'

class Tos
  attr_accessor :user
  def initialize
    color_ui = Settings['color_ui']
    print "".sup_color(color_ui == true).ul
    @user = User.new(Settings['uniqueKey'], Settings['deviceKey'])
    @auto_repeat = false
    @auto_repeat_next = false
    @auto_merge = Settings['auto_merge'] || false
    @merge_cards = Settings['merge_cards'] || []
    @last_zone = nil
    @merges_level = {
      86 => 10,
      87 => 15,
      88 => 10,
      89 => 15,
      90 => 10,
      91 => 15,
      92 => 10,
      93 => 15,
      94 => 10,
      95 => 15,
    }
    @merges_keep = {
      #進化魂
      241 => 2,
      242 => 2,
      243 => 2,
      244 => 2,
      245 => 2,
      246 => 2,
      247 => 2,
      248 => 2,
      249 => 2,
      250 => 2,
      251 => 2,
      252 => 2,
      253 => 2,
      254 => 2,
      255 => 2,
      256 => 2,
      257 => 2,
      258 => 2,
      259 => 2,
      260 => 2,
      #龍蛋
      261 => 2,
      262 => 2,
      263 => 2,
      #魔劍
      264 => 2,
      265 => 2,
      266 => 2,
      #西瓜
      267 => 2,
      268 => 2,
      269 => 2,
      #星靈
      379 => 1,
      380 => 1,
      381 => 1,
      382 => 1,
      383 => 1,
      384 => 1,
    }
  end

  def login
    puts '登入遊戲中.....'
    @user.login
    puts '登入成功'
    self.print_user_sc
    prompt = 'Auto play?(y/N)'
    choice_auto_repeat = Readline.readline(prompt, true)
    exit if choice_auto_repeat == 'q'
    if choice_auto_repeat == 'y'
      @auto_repeat = true
      prompt = 'Auto play next floor?(y/N)'
      choice_auto_repeat_next = Readline.readline(prompt, true)
      @auto_repeat_next = true if choice_auto_repeat_next == 'y'
    end
    self.select_team
  end

  def user_zone
    self.print_user_sc
    puts "[%3d] %s" % [1, '自動強化合成']
    puts "[%3d] %s" % [2, '隊伍']
    puts "[%3d] %s" % [3, '背包']
    puts "[%3d] %s" % [4, '商店']
    if @user.data['guildId'].to_i > 0
      puts "[%3d] %s" % [5, '公會']
    end
    prompt = 'Choice zone?(b:back,q:quit)'
    choice_zone = Readline.readline(prompt, true)
    exit if choice_zone == 'q'
    case choice_zone
    when '1'
      merge_card
    when '2'
      select_team
    when '3'
      select_cards
    when '4'
      select_diamond
    when '5'
      select_guild
    end
    return false
  end

  def select_guild
    print_guild
    puts "[%3d] %s" % [1, '捐獻']
    puts "[%3d] %s" % [2, '公會任務']
    prompt = 'Choice operate?'
    choice = Readline.readline(prompt, true)
    exit if choice == 'q'
    case choice
    when '1'
      guild_donate_coin
    when '2'
      select_guild_mission
    end
  end

  def select_guild_mission
    @user.guild_mission_list
    unless @user.guildMission['rewardAvailable']
      puts "本日任務已完成。"
      return
    end
    mission_complete = true
    rewards = @user.guildMission['rewardMonsters']
    puts '任務獎賞：'
    rewards.each do |monster|
      puts "%3d lv%2d %s" % [monster['monsterId'], monster['level'], monster['monsterName']]
    end
    missions = @user.guildMission['guildMissions']
    missions.each_with_index do |mission, index|
      puts "[%3d]%s%s" % [index + 1, (mission['achieved']) ? 'v' : ' ', mission['name']]
      mission_complete = false unless mission['achieved']
    end
    if mission_complete
      puts "[%3d] 領取任務獎賞" % [6]
    end
    prompt = 'Choice mission?'
    choice = Readline.readline(prompt, true)
    exit if choice =='q'
    if choice == '6'
      cards = @user.guild_mission_claim
      puts '任務獎賞：'
      cards.each do |card|
        monster = card['monster']
        puts "%3d lv%2d %s" % [monster['monsterId'], monster['level'], monster['monsterName']]
      end
      return
    end
    mission = missions[choice.to_i - 1]
    if mission['type'].to_i <= 2
      mission_donate_monster(mission)
    elsif mission['type'].to_i == 4
      mission_complete_floor(mission)
    else
      @user.guild_mission_achieve(mission)
    end
    puts "%s 完成。" % [mission['name']]
  end

  def mission_complete_floor(mission)
    floor_data = @user.find_floor_by(mission['typeValue'])
    @floor = @user.floor(floor_data)
    @floor.is_mission = true
    self.get_helper_list
    self.fighting
    @user.guild_mission_achieve(mission)
  end

  def mission_donate_monster(mission)
    print mission['name']
    if mission['monsters']
      mission['monsters'].each do |monster|
        print "[%s]" % [monster['monsterName']]
      end
    end
    print "\n"
    cards = nil
    exp = nil
    if mission['type'].to_i == 1
      cards = mission['typeValue'].split(',')
    else
      exp = mission['typeValue'].to_i
    end
    @user.cards.each do |key, card|
      next if card['bookmark']
      monster = card['monster']
      if cards
        next unless cards.include? monster['monsterId']
      end
      if exp
        next if monster['exp'].to_i < exp
      end
      puts "[%3d]%s%3d lv%2d %s (Exp:%d)" % [
        card['cardId'],
        (card['bookmark']) ? '*' : ' ',
        monster['monsterId'],
        monster['level'],
        monster['monsterName'],
        monster['exp']
      ]
    end
    prompt = 'Choice target card?'
    choice =  Readline.readline(prompt, true)
    exit if choice == 'q'
    return if choice == 'b'
    targets = choice.split(',')
    @user.guild_mission_achieve(mission, targets)
  end

  def guild_donate_coin
    puts "金錢：%d" % [@user.data['coin']]
    puts "[%3d] %s" % [1, '捐獻  100 黃金 (100,000)']
    puts "[%3d] %s" % [2, '捐獻  200 黃金 (200,000)']
    puts "[%3d] %s" % [3, '捐獻  500 黃金 (500,000)']
    puts "[%3d] %s" % [4, '捐獻 1000 黃金 (1000,000)']
    prompt = 'Choice donate?'
    choice = Readline.readline(prompt, true)
    exit if choice == 'q'
    case choice
    when '1'
      @user.guild_donate_coin(100000)
      puts "成功捐獻 100 黃金至公會。"
    when '2'
      @user.guild_donate_coin(200000)
      puts "成功捐獻 200 黃金至公會。"
    when '3'
      @user.guild_donate_coin(500000)
      puts "成功捐獻 500 黃金至公會。"
    when '4'
      @user.guild_donate_coin(1000000)
      puts "成功捐獻 1000 黃金至公會。"
    end
  end

  def select_diamond
    qty = 1
    qty = 10 if @user.data['friendPoint'].to_i >= (200 * 10)
    puts "友情點數：%s" % [@user.data['friendPoint']]
    puts "魔法石：%s" % [@user.data['diamond']]
    puts "[%3d] %s (%d times)" % [1, '友情抽卡', qty]
    puts "[%3d] %s" % [2, '魔法石抽卡']
    puts "[%3d] %s" % [3, '回復體力']
    puts "[%3d] %s" % [4, '擴充背包容量']
    puts "[%3d] %s" % [5, '擴充朋友上限']

    prompt = 'Choice opeater?'
    choice =  Readline.readline(prompt, true)
    exit if choice == 'q'
    case choice
    when '1'
      cards = @user.frienddraw(qty)
      puts "抽卡結果："
      cards.each do |card|
        monster = card['monster']
        puts "\t%3d lv%2d %s" % [monster['monsterId'], monster['level'], monster['monsterName']]
      end
    when '2'
      res = @user.luckydraw
      monster = res['monster']
      puts "抽卡結果：%3d lv%2d %s" % [monster['monsterId'], monster['level'], monster['monsterName']]
    when '3'
      @user.restore_stamina
      puts "體力已完全回復"
    when '4'
      @user.extend_box
      puts "擴充背包容量至 %s" % [@user.data['inventoryCapacity']]
    when '5'
      @user.extend_friend
      puts "擴充朋友上限至 %s" % [@user.data['friendsCapacity']]
    end
  end

  def select_team
    self.print_teams
    auto_team = @user.first_team
    prompt = 'Choice team?'
    prompt += "[#{auto_team}]" if auto_team
    choice_team =  Readline.readline(prompt, true)
    exit if choice_team == 'q'
    choice_team = auto_team if auto_team and choice_team == ''
    @user.select_team(choice_team.to_i)
  end

  def select_cards
    @user.cards.each do |key, card|
      monster = card['monster']
      puts "[%3d]%s%3d lv%2d %s" % [
        card['cardId'],
        (card['bookmark']) ? '*' : ' ',
        monster['monsterId'],
        monster['level'],
        monster['monsterName']
      ]
    end
    prompt = 'Choice card?'
    choice_card =  Readline.readline(prompt, true)
    exit if choice_card == 'q'
    return if choice_card.length == 0
    choice_card_operate choice_card.to_i
  end

  def select_target_cards(sourceId)
    sourceCard = @user.cards[sourceId.to_i]
    sourceMonster = sourceCard['monster']
    puts "目前選擇：%3d lv%2d %s" % [sourceMonster['monsterId'], sourceMonster['level'], sourceMonster['monsterName']]

    @user.cards.each do |key, card|
      next if card['bookmark']
      next if card['cardId'].to_i == sourceId.to_i
      monster = card['monster']
      next if sourceMonster['attribute'] != monster['attribute']
      puts "[%3d]%s%3d lv%2d %s" % [
        card['cardId'],
        (card['bookmark']) ? '*' : ' ',
        monster['monsterId'],
        monster['level'],
        monster['monsterName']
      ]
    end
    prompt = 'Choice target card?'
    choice =  Readline.readline(prompt, true)
    exit if choice == 'q'
    return if choice.length == 0
    targets = choice.split(',')
    card = @user.merge_card(sourceId, targets)
    monster = card['monster']
    puts "強化完成：%3d lv%2d %s" % [monster['monsterId'], monster['level'], monster['monsterName']]
  end

  def preview_evolution(cardId)
    card = @user.cards[cardId]
    monster = card['monster']
    puts "目前選擇：%3d lv%2d %s" % [monster['monsterId'], monster['level'], monster['monsterName']]
    targets = []
    evolutions = @user.get_evolve_card(cardId)
    evolutions.each_with_index do |evolution, index|
      cards = @user.find_cards_by_monster_bookmark(evolution['monsterId'])
      cards_s = "(%s)" % [cards.keys.join(',')]
      targets << cards.keys.first if cards.keys.first
      puts "[%3d] %3d %s %s" % [index + 1, evolution['monsterId'], evolution['monsterName'], cards_s]
    end
    prompt = 'Evolution card?(y/N)'
    choice = Readline.readline(prompt, true)
    exit if choice == 'q'
    return if choice != 'y'
    if monster['level'].to_i != monster['maxLevel'].to_i
      puts "卡片等級不足以進化，目前等級 %s，需提升至 %s。" % [monster['level'], monster['maxLevel']]
      return
    end
    if evolutions.count != targets.count
      puts "進化素材不足，或素材已被標記為最愛或在隊伍中。"
      return
    end
    card = @user.evolve_card(cardId, targets)
    monster = card['monster']
    puts "進化完成：%3d lv%2d %s" % [monster['monsterId'], monster['level'], monster['monsterName']]
  end

  def choice_card_operate(cardId)
    card = @user.cards[cardId]
    monster = card['monster']
    puts "目前選擇：%3d lv%2d %s" % [monster['monsterId'], monster['level'], monster['monsterName']]
    puts "[%3d] %s" % [1, '強化合成']
    puts "[%3d] %s" % [2, '進化合成']
    puts "[%3d] %s" % [3, '賣出']
    prompt = 'Choice operate?'
    choice = Readline.readline(prompt, true)
    exit if choice == 'q'
    return if choice == 'b'
    case choice
    when '1'
      select_target_cards(cardId)
    when '2'
      preview_evolution(cardId)
    when '3'
      if card['bookmark']
        puts "該卡已設定為最愛或在隊伍，操作無法執行。"
        return
      end
      res = @user.sell_cards [cardId]
      puts "售出金額：%s" % [res['coin']]
    end
  end

  def choice_floor
    puts 'Zone list'
    puts "[%3d] %s" % [0, '召喚師之元']
    @user.floors.each do |index, zone|
      if zone['requireFloor']
        next unless (@user.data['completedFloorIds'].include? zone['requireFloor'].to_i)
      end
      puts "[%3d] %s%s" % [index,zone['name'],(zone['bonus']) ? ' (bonus)'.gold : '']
    end
    prompt = 'Choice zone?(b:back,q:quit)'
    prompt += "[#{@last_zone}]" if @last_zone
    choice_zone = Readline.readline(prompt, true)
    exit if choice_zone == 'q'
    return false if choice_zone == 'b'
    return user_zone if choice_zone == '0'
    choice_zone = @last_zone if @last_zone and choice_zone == ''
    @last_zone = choice_zone

    puts "Stage list"
    last_stage = nil
    stages = @user.floors[choice_zone.to_i]['stages']
    stages.each do |index, stage|
      unless stage['start_at'] == ''
        next if Time.now.to_i < Time.at(stage['start_at'].to_i).to_i
        next if Time.now.to_i > Time.at(stage['end_at'].to_i).to_i
      end
      print "[%3d]" % [stage['id']]
      print ((@user.data['completedStageIds'].include? stage['id'].to_i) ? 'v' : ' ').bold.green
      print stage['name']
      print " #{Time.at(stage['start_at'].to_i).strftime('%m/%d %H:%M')} ~ #{Time.at(stage['end_at'].to_i).strftime('%m/%d %H:%M')}" unless stage['start_at'] == ''
      bonus = stage['bonus']
      print " (#{bonus['bonusType_s']})".gold if bonus
      print "\n"
      if choice_zone.to_i < 7
        last_stage = stage['id']
        break unless (@user.data['completedStageIds'].include? stage['id'].to_i)
      end
    end
    prompt = 'Choice stage?(b:back,q:quit)'
    prompt += "[#{last_stage}]" if last_stage
    choice_stage = Readline.readline(prompt, true)
    exit if choice_stage == 'q'
    return false if choice_stage == 'b'
    choice_stage = last_stage if last_stage and choice_stage == ''

    puts "Floor list"
    last_floor = nil
    floors = stages[choice_stage.to_i]['floors']

    floors.each do |index, floor|
      puts "[%3d]%s %2d %s" % [floor['id'],((@user.data['completedFloorIds'].include? floor['id'].to_i) ? 'v' : ' ').bold.green,floor['stamina'],floor['name']]
      last_floor = floor['id'] unless last_floor
      last_floor = nil if @user.data['completedFloorIds'].include? floor['id'].to_i
    end
    prompt = 'Choice floor?(b:back,q:quit)'
    prompt += "[#{last_floor}]" if last_floor
    choice_floor = Readline.readline(prompt, true)
    exit if choice_floor == 'q'
    return false if choice_floor == 'b'
    choice_floor = last_floor if last_floor and choice_floor == ''
    @floor = @user.floor(floors[choice_floor.to_i])
    return true
  end

  def get_helper_list
    if @user.cards_full?
      puts 'Cards is full.'
      exit
    end
    puts '取得隊友名單'
    @floor.get_helpers
    self.print_helpers(@floor.helpers)
    if @auto_repeat
      choice_helper = (1 + rand(3)).to_s
      @floor.choice_helper = choice_helper.to_i - 1
      puts "Auto choice helper?#{choice_helper}"
      return false
    end
    prompt = 'Choice helper?(b:back,q:quit)'
    prompt += "[auto]"
    choice_helper = Readline.readline(prompt, true)
    exit if choice_helper == 'q'
    return true if choice_helper == 'b'
    choice_helper = (1 + rand(3)).to_s if choice_helper == ''
    @floor.choice_helper = choice_helper.to_i - 1
    return false
  end

  def fighting
    @floor.enter
    self.print_waves @floor.waves
    @floor.fight

    puts "waiting complete.(%s)[%s - %s]" % [
      @floor.delay_time.to_s,
      Time.now.strftime("%I:%M:%S%p").to_s,
      (Time.now + @floor.delay_time).strftime("%I:%M:%S%p").to_s
    ]
    print "[                                        ]\r["
    40.times do
      sleep (@floor.delay_time/40)
      print '#'
    end
    print "\n"

    @floor.complete
    print_gains(@floor.gains)
    print_loots(@floor.loots, @floor.loot_items)

      #auto_merge_card if @auto_merge

    #if @auto_repeat
      #@floor.wave_floor = (@floor.wave_floor.to_i + 1).to_s if @auto_repeat_next
      #print "Auto play again start at 5 sec."
      #5.times do
        #sleep 1.0
        #print '.'
      #end
      #print "\n"
      #return false
    #end
    unless @floor.is_mission
      self.print_user_sc
      prompt = 'Play again?(y/N)'
      return false if Readline.readline(prompt, true) == 'y'
    end
    return true
  end

  def print_guild
    guild = @user.data['guild']
    puts '======================================'
    puts "所屬公會：%s(%s)" % [guild['name'], guild['guildId']]
    puts "等級：%-3d 經驗值：%-10d 金錢：%-10d" % [guild['level'], guild['exp'], guild['coins']]
    puts "會員：%d/%d" % [guild['totalMembers'], guild['maxMembers']]
    puts guild['announcement']
    puts '======================================'
  end

  def print_user_sc
    data = @user.data
    puts '======================================'
    puts "session：#{data['session']}"
    puts "uid：#{data['uid']}"
    puts "名稱：#{data['name']}"
    puts "等級：#{data['level']}"
    puts "經驗值：#{data['exp']}/#{data['next_exp']} (#{data['next_exp'] - data['exp'].to_i})"
    puts "金錢：#{data['coin']}"
    puts "魔石：#{data['diamond']}"
    puts "體力：#{data['currentStamina']}/#{data['maxStamina']}"
    puts "背包：#{data['totalCards']}/#{data['inventoryCapacity']}"
    puts '======================================'
  end

  def print_teams
    teams = @user.teams
    teams.each do |index, team|
      next if team.length == 0
      print "隊伍#{index}：\n"
      team.each do |card|
        monster = card['monster']
        print "\t"
        print "lv%2d %s" % [monster['level'], monster['monsterName']]
        print "\n"
      end
    end
  end

  def print_waves(waves)
    waves.each_with_index do |wave, index|
      puts "第 #{index+1} 波"
      wave.each do |enemy|
        print "\tlv%3d %s" % [enemy['monster']['level'], enemy['monster']['monsterName']]
        print "\t(hp:%d, attack:%d, defense:%d)\n" % [
          enemy['monster']['enemyHP'],
          enemy['monster']['enemyAttack'],
          enemy['monster']['enemyDefense']
        ]
        if enemy['lootItem']
          prefix = "戰勵品：".bg_blue.yellow.bold
          puts "\t#{prefix}#{enemy['lootItem_s']}"
        end
      end
    end
  end

  def print_helpers(helpers)
    helpers.each_with_index do |helper, index|
      monster = helper['monster']
      puts "[%3d] LV:%2d CD:%2d FP+%2s %s : %s %s" % [index + 1, helper['monsterLevel'], monster['coolDown'],helper['friendPoint'], monster['monsterName'], is_empty(helper['guild']) ? "" : "【#{helper['guild']}】".yellow, helper['name']]
    end
  end

  def print_gains(gains)
    puts "友情點數：%s" % [gains['friendpoint']]
    puts "經驗值：%s(%s)" % [gains['expGain'], gains['guildExpBonus']]
    puts "金錢：%s(%s)" % [gains['coinGain'], gains['guildCoinBonus']]
    puts "公會經驗值：%s" % [gains['guildExpContribute']]
    puts "魔法石：%s" % [gains['diamonds']]
  end

  def print_loots(loots, loot_items)
    puts "戰勵品：".bg_blue.yellow.bold
    loots.each do |loot|
      monster = loot['monster']
      puts "%3d lv%2d %s" % [loot['cardId'], monster['level'], monster['monsterName']]
    end
    loot_items.each do |item|
      puts "%3d %s" % [item['itemId'], item['itemName']]
    end
  end

  def merge_card
    merges = [
      {
        'sources' => [
          86,87,88,89,90,91,92,93,94,95,           #小魔女
        ],
        'targets' => [
          56,57,58,59,60,61,62,63,64,65,           #地精
          66,67,68,69,70,71,72,73,74,75,           #精靈
          76,77,78,79,80,81,82,83,84,85,           #蜥蝪
          96,97,98,99,100,101,102,103,104,105,     #史萊姆
          106,107,108,109,110,111,112,113,114,115, #狼人
          241,242,243,244,245,246,247,248,249,250, #進化魂
          251,252,253,254,255,256,257,258,259,260, #進化魂
          261,262,263,                             #龍蛋
          264,265,266,                             #魔劍
          267,268,269,                             #西瓜
          270,271,272,273,274,                     #小靈魂石
          275,276,277,278,279,                     #靈魂石
          443,444,445,446,447,                     #鴨小兵
          #486,487,488,489,490,                     #龍牙棋
        ]
      },
      {
        'sources' => [
          319,321,323,325,327,                     #石像
        ],
        'targets' => [
          379,380,381,382,383,384,                 #星靈
          403,404,405,406,407,                     #十二宮小兵
        ]
      }
    ]

    auto_merge_cards = Settings['auto_merge_cards'] || []
    if auto_merge_cards.count > 0
      merge_data = {
        'sources' => auto_merge_cards,
        'targets' => [
          86,87,88,89,90,91,92,93,94,95,           #小魔女
          280,281,282,283,284,                     #千年靈魂石
          320,322,324,326,328,                     #二階石像
        ]
      }
      merges << merge_data
    end

    puts "自動強化合成："
    merges.each do |merge|
      merge['sources'].each do |sourceId|
        sourceCard = @user.find_cards_by_monster(sourceId).first
        next unless sourceCard
        sourceMonster = sourceCard.last['monster']
        targetIds = find_merge_card(sourceCard.last, merge['targets'], auto_merge_cards)
        next if targetIds.count == 0
        puts "%3d lv%2d %s <= {" % [sourceMonster['monsterId'], sourceMonster['level'], sourceMonster['monsterName']]
        targetCards = eval "@user.cards.values_at(#{targetIds.join(',')})"
        targetCards.each do |card|
          monster = card['monster']
          puts "\t%3d lv%2d %s" % [monster['monsterId'], monster['level'], monster['monsterName']]
        end
        card = @user.merge_card(sourceCard.last['cardId'], targetIds)
        monster = card['monster']
        puts "} => %3d lv%2d %s" % [monster['monsterId'], monster['level'], monster['monsterName']]
      end
    end
    puts '======================================'
  end

  def keep_index(card)
    keep = @merges_keep[card['monster']['monsterId'].to_i]
    return 0 unless keep
    keep
  end

  def max_level(monster)
    level = nil
    level = @merges_level[monster['monsterId'].to_i] if @merges_level[monster['monsterId'].to_i]
    level = monster['maxLevel'] if not level or level > monster['maxLevel'].to_i
    level
  end

  def merge_to_level(monster)
    level = self.max_level(monster)
    exp = @user.level_to_exp(monster['expType'], level)
  end

  def find_merge_card(sourceCard, targetIds, auto_merge_cards)
    #puts auto_merge_cards.inspect
    sourceMonster = sourceCard['monster']
    #puts sourceCard.inspect
    maxLevelExp = self.merge_to_level(sourceMonster)
    #puts "%d/%d %s" % [sourceCard['exp'], maxLevelExp, sourceMonster['monsterName']]
    cards = @user.cards.select do |index, card|
      monster = card['monster']
      targetIds.include? monster['monsterId'].to_i \
      and not card['bookmark'] \
      and card['cardId'] != sourceCard['cardId'] \
      and monster['attribute'].to_i == sourceMonster['attribute'].to_i \
      and card['index'].to_i > self.keep_index(card)
    end
    cards = cards.sort_by {|k, v| v['monsterId'].to_i}
    total_exp = 0
    cardIds = []
    cards.each do |index, card|
      break if (total_exp + sourceCard['exp'].to_i) > maxLevelExp
      monster = card['monster']
      if auto_merge_cards.include? sourceMonster['monsterId'].to_i
        level = self.max_level(monster)
        next if monster['level'].to_i < level.to_i
      end
      #puts "%3d lv%2d %s (%d)" % [monster['monsterId'], monster['level'], monster['monsterName'], monster['sameAttrExp']]
      total_exp += monster['sameAttrExp']
      cardIds << card['cardId'].to_i
    end
    #puts cardIds.join(',')
    cardIds
  end
end

def running
  a = Tos.new
  a.login
  loop do
    next unless a.choice_floor
    loop do
      break if a.get_helper_list
      break if a.fighting
    end
  end
end

begin
  Thread.new(running)
rescue Interrupt
  puts "\nQuitting."
end
