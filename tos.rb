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
    file_name = "log/logfile.log.#{ARGV[0] ? ARGV[0] : 'defaults'}"
    dir = File.dirname(file_name)
    FileUtils.mkdir_p(dir) unless File.directory?(dir)
    File.delete(file_name) if File.exists? file_name
    @logger = Logger.new(file_name)
    color_ui = Settings['color_ui']
    print "".sup_color(color_ui == true).ul
    @user = User.new(Settings['uniqueKey'], Settings['deviceKey'])
    @auto_repeat = false
    @auto_repeat_next = false
    @auto_merge = Settings['auto_merge'] || false
    @merge_cards = Settings['merge_cards'] || []
    @last_zone = nil
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
    puts "[%3d] %s" % [1, '隊伍']
    puts "[%3d] %s" % [2, '背包']
    puts "[%3d] %s" % [3, '商店']
    if @user.data['guildId'].to_i > 0
      puts "[%3d] %s" % [4, '公會']
    end
    prompt = 'Choice zone?(b:back,q:quit)'
    choice_zone = Readline.readline(prompt, true)
    exit if choice_zone == 'q'
    case choice_zone
    when '1'
      select_team
    when '2'
      select_cards
    when '3'
      select_diamond
    when '4'
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
    puts mission['name']
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
      cards = @user.find_cards_by_monster(evolution['monsterId'])
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

  def auto_merge_card(debug = false)
    puts "Mergeing master cards"
    @merge_cards.each do |key, merge_card|
      merge_card['source_cards'].each do |s|
        loop do
          sourceCardId = @user.get_source_card(s, merge_card)
          #puts "sourceCardId:#{sourceCardId}"
          break unless sourceCardId
          targetCardIds = @user.get_master_merge_card(sourceCardId, merge_card)
          break if targetCardIds.length == 0
          break if targetCardIds.length < merge_card['require_target_amount_min']
          print "#{sourceCardId} lv#{@user.cards[sourceCardId][:level]} #{@user.monster.data[s.to_s][:monsterName]} <= ("
          targetCardIds.each do |t|
            card = @user.cards[t]
            print "," unless t == targetCardIds.first
            print "lv#{card[:level]} #{@user.monster.data[card[:monsterId]][:monsterName]}"
          end
          print ")\n"
          unless debug
            res_json = page_post(@user.get_merge_url(sourceCardId, targetCardIds))
            @user.parse_card_data(res_json['cards'])
            @user.data['coin'] = res_json['user']['coin']
            @user.data['totalCards'] = res_json['user']['totalCards']
          end
        end
      end
    end
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
