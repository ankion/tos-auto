# -*- encoding : utf-8 -*-
require "addressable/uri"
require "./checksum"
require "./monster"
require "./setting"
require "./exp"

class User
  attr_accessor :monster, :data, :cards, :post_data, :helpers, :loots, :bookmarks

  def initialize
    @monster = Monster.new
    @exp = Exp.new
    @stage_require_floor = {
      '8' => 23, # 一封
      '9' => 28,
      '10' => 33,
      '11' => 38,
      '12' => 43,
      '13' => 48,
      '14' => 53, # 二封
      '15' => 58,
      '16' => 63,
      '17' => 68,
      '18' => 73,
      '19' => 78,
      '20' => 83, # 三封
      '21' => 88,
      '22' => 93,
      '23' => 98,
      '24' => 103,
      '25' => 108,
      '26' => 113, # 四封
      '27' => 118,
      '28' => 123,
      '29' => 128,
      '30' => 133,
      '31' => 138,
      '32' => 143, # 五封
      '87' => 148,
      '88' => 281,
      '89' => 286,
      '90' => 291,
      '91' => 296,
      '92' => 301 # 六封
    }
    @post_data = {
      :type => 'facebook',
      :uniqueKey => Settings['uniqueKey'],
      :deviceKey => Settings['deviceKey'],
      :sysInfo => Settings['sysInfo'],
      #:session => 'c51b955d9535eb1722e898e683be51e3',
      :language => 'zh_TW',
      :platform => Settings['platform'],
      :version => '3.27',
      :timestamp => '',
      :timezone => '8',
      :nData => ''
    }
    @data = nil
    @cards = {}
    @helpers = nil
    @loots = nil
    @bookmarks = nil
  end

  def stage_can_enter?(stage)
    return true unless @stage_require_floor[stage]
    @data['completedFloorIds'].include? @stage_require_floor[stage]
  end

  def parse_helpers_data(data)
    @helpers = {}
    data.each_index do |index|
      person = data[index].split('|')
      person_data = {
        :uid => person[0],
        :name => person[1],
        :level => person[3],
        :monsterId => person[8],
        :monsterLevel => person[10],
        :monster_name => @monster.data[person[8]][:monsterName],
        :clientHelperCard => "#{person[7..11].join('|')}|0|0"
      }
      @helpers[index+1] = person_data
    end
  end

  def cards_full?
    @data['totalCards'].to_i >= (@data['inventoryCapacity'].to_i + 10)
  end

  def print_user_sc
    puts "session：#{@data['session']}"
    puts "uid：#{@data['uid']}"
    puts "名稱：#{@data['name']}"
    puts "等級：#{@data['level']}"
    next_exp = @exp.data[@data['level'].to_i + 1]
    puts "經驗值：#{@data['exp']}/#{next_exp} (#{next_exp - @data['exp'].to_i})"
    puts "金錢：#{@data['coin']}"
    puts "靈魂石：#{@data['diamond']}"
    puts "體力：#{@data['currentStamina']}/#{@data['maxStamina']}"
    puts "背包：#{@data['totalCards']}/#{@data['inventoryCapacity']}"
  end

  def print_loots
    puts '戰勵品：'
    @loots.each do |l|
      if l['type'] == 'monster'
        puts "#{l['card']['cardId']} lv#{l['card']['level']} #{@monster.data[l['card']['monsterId']][:monsterName]}"
      else
        l['merged'] = true
      end
    end
  end

  def get_sell_card(target_cards)
    targetCardIds = []
    @loots.each do |l|
      next unless l['card']
      next if l['selled']
      next if l['merged']
      next unless target_cards.include? l['card']['monsterId']
      targetCardIds << l['card']['cardId']
      l['selled'] = true
      break if targetCardIds.length == 10
    end
    return targetCardIds
  end

  def get_sell_url(targetCardIds)
    encypt = Checksum.new
    post_data = {
      :targetCardIds => targetCardIds.join(','),
      :uid => @data['uid'],
      :session => @data['session'],
      :language => @post_data[:language],
      :platform => @post_data[:platform],
      :version => @post_data[:version],
      :timestamp => Time.now.to_i,
      :timezone => @post_data[:timezone],
      :nData => encypt.getNData
    }
    uri = Addressable::URI.new
    uri.query_values = post_data
    url = "/api/card/sell?#{uri.query}"
    #puts url
    return "#{url}&hash=#{encypt.getHash(url, '')}"
  end

  def print_cards
    @cards.each do |card|
      puts card[1].inspect
    end
  end

  def get_source_card(source)
    sourceCardId = nil
    @cards.each do |card|
      monster = @monster.data[card[1][:monsterId]]
      next if source.to_i != monster[:monsterId].to_i
      next if card[1][:level].to_i == monster[:maxLevel].to_i
      sourceCardId = card[1][:cardId]
      break
    end
    return sourceCardId
  end

  def get_merge_card(sourceCardId, target_cards)
    targetCardIds = []
    source = @monster.data[@cards[sourceCardId][:monsterId]]
    #puts "source:#{source.inspect}"
    @cards.each do |l|
      next if sourceCardId == l[1][:cardId]
      next if l[1][:merged]
      next if @bookmarks.include? l[1][:cardId]
      target = @monster.data[l[1][:monsterId]]
      #puts "target:#{target.inspect}"
      next unless target_cards.include? target[:monsterId]
      #puts "source:#{source[:attribute]} target:#{target[:attribute]}"
      if source[:attribute] == target[:attribute]
        l[1][:merged] = true
        targetCardIds << l[1][:cardId]
        break if targetCardIds.length == 5
      end
    end
    return targetCardIds
  end

  def get_master_merge_card(sourceCardId, target_cards, max_lv = 0)
    targetCardIds = []
    source = @monster.data[@cards[sourceCardId][:monsterId]]
    #puts "source:#{source.inspect}"
    @cards.each do |l|
      next if sourceCardId == l[1][:cardId]
      next if l[1][:merged]
      next if @bookmarks.include? l[1][:cardId]
      target = @monster.data[l[1][:monsterId]]
      #puts "target:#{target.inspect}"
      next unless target_cards.include? target[:monsterId]
      #puts "source:#{source[:attribute]} target:#{target[:attribute]}"
      next if l[1][:level].to_i < max_lv and l[1][:level].to_i < target[:maxLevel].to_i
      if source[:attribute] == target[:attribute]
        l[1][:merged] = true
        targetCardIds << l[1][:cardId]
        break if targetCardIds.length == 5
      end
    end
    return targetCardIds
  end

  def get_merge_url(sourceCardId, targetCardIds)
    encypt = Checksum.new
    post_data = {
      :sourceCardId => sourceCardId,
      :targetCardIds => targetCardIds.join(','),
      :uid => @data['uid'],
      :session => @data['session'],
      :language => @post_data[:language],
      :platform => @post_data[:platform],
      :version => @post_data[:version],
      :timestamp => Time.now.to_i,
      :timezone => @post_data[:timezone],
      :bookmarks => @bookmarks.join(','),
      :nData => encypt.getNData
    }
    uri = Addressable::URI.new
    uri.query_values = post_data
    url = "/api/card/merge?#{uri.query}"
    #puts url
    return "#{url}&hash=#{encypt.getHash(url, '')}"
  end

  def auto_get_team
    (0..4).each do |t|
      next if @data["team#{t}Array"] == '0,0,0,0,0'
      return (t + 1).to_s
    end
    return nil
  end

  def print_teams(helper = nil)
    (0..4).each do |t|
      total_hp = 0
      total_attack = 0
      total_recover = 0
      #puts @user.data["team#{t}Array"]
      next if @data["team#{t}Array"] == '0,0,0,0,0'
      team = @data["team#{t}Array"].split(',')
      print "隊伍#{t + 1}：\n"
      team.each do |m|
        card = @cards[m]
        next unless card
        monster = @monster.data[card[:monsterId]]
        print "\t"
        print "lv#{card[:level]} "
        print "#{monster[:monsterName]}"
        print "\n"
        #puts @monster.data[card[:monsterId]].inspect
      end
      #print "\n"
      #puts "total hp:#{get_team_hp(team, helper)} total attack:#{get_team_attack(team, helper)} total recover:#{get_team_recover(team, helper)}"
    end
  end

  def get_team_hp(teams, helper = nil)
    total_hp = 0
    teams.each do |t|
      card = @cards[t]
      next unless card
      monster = @monster.data[card[:monsterId]]
      hp = ((monster[:maxCardHP].to_i - monster[:minCardHP].to_i) * (card[:level].to_f / monster[:maxLevel].to_f) + monster[:minCardHP].to_i).to_i
      total_hp += hp
    end
    if helper
      monster = @monster.data[helper[:monsterId]]
      hp = ((monster[:maxCardHP].to_i - monster[:minCardHP].to_i) * (helper[:monsterLevel].to_f / monster[:maxLevel].to_f) + monster[:minCardHP].to_i).to_i
      total_hp += hp
    end
    return total_hp
  end

  def get_team_attack(teams, helper = nil)
    total_attack = 0
    teams.each do |t|
      card = @cards[t]
      next unless card
      monster = @monster.data[card[:monsterId]]
      attack = ((monster[:maxCardAttack].to_i - monster[:minCardAttack].to_i) * (card[:level].to_f / monster[:maxLevel].to_f) + monster[:minCardAttack].to_i).to_i
      total_attack += attack
    end
    if helper
      monster = @monster.data[helper[:monsterId]]
      attack = ((monster[:maxCardAttack].to_i - monster[:minCardAttack].to_i) * (helper[:monsterLevel].to_f / monster[:maxLevel].to_f) + monster[:minCardAttack].to_i).to_i
      total_attack += attack
    end
    return total_attack
  end

  def get_team_recover(teams, helper = nil)
    total_recover = 0
    teams.each do |t|
      card = @cards[t]
      next unless card
      monster = @monster.data[card[:monsterId]]
      recover = ((monster[:maxCardRecover].to_i - monster[:minCardRecover].to_i) * (card[:level].to_f / monster[:maxLevel].to_f) + monster[:minCardRecover].to_i).to_i
      total_recover += recover
    end
    if helper
      monster = @monster.data[helper[:monsterId]]
      recover = ((monster[:maxCardRecover].to_i - monster[:minCardRecover].to_i) * (helper[:level].to_f / monster[:maxLevel].to_f) + monster[:minCardRecover].to_i).to_i
      total_recover += recover
    end
    return total_recover
  end

  def print_helpers
    @helpers.each do |index, h|
      puts "[#{index}] #{h[:uid]} #{h[:name]} #{h[:level]} #{h[:monster_name]}"
    end
  end

  def parse_card_data(data)
    @cards = {}
    data.each do |d|
      card_data = d.split('|')
      card = {
        :cardId => card_data[0],
        :monsterId => card_data[1],
        :exp => card_data[2],
        :level => card_data[3],
        :skillLevel => card_data[4]
      }
      #puts card.inspect
      @cards[card_data[0]] = card
    end
  end

  def get_login_url
    encypt = Checksum.new
    @post_data[:timestamp] = Time.now.to_i
    @post_data[:nData] = encypt.getNData
    uri = Addressable::URI.new
    uri.query_values = @post_data
    login_url = "/api/user/login?#{uri.query}"
    return "#{login_url}&hash=#{encypt.getHash(login_url, '')}"
  end
end
