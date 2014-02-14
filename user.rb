# -*- encoding : utf-8 -*-
require "addressable/uri"
require "./api"
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
      :version => '4.54',
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
      club = ""
      begin
        club = person[17].split('#')[6]
      rescue
      end

      person_data = {
        :uid => person[0],
        :name => person[1],
        :loginTime => person[2],
        :level => person[3],
        :monsterId => person[8],
        :monsterLevel => person[10],
        :skillLevel => person[11],
        :friendPoint => person[13].to_i || 0,
        :coolDown => "#{Integer(@monster.data[person[8]][:normalSkill][:maxCoolDown]) - Integer(person[11]) + 1}",
        :club => club ,
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
    puts "魔石：#{@data['diamond']}"
    puts "體力：#{@data['currentStamina']}/#{@data['maxStamina']}"
    puts "背包：#{@data['totalCards']}/#{@data['inventoryCapacity']}"
  end

  def print_loots
    puts "戰勵品：".bg_blue.yellow.bold
    @loots.each do |l|
      if l['type'] == 'monster'
        begin
          puts "%3d lv%2d %s" % [l['card']['cardId'],l['card']['level'],@monster.data[l['card']['monsterId'].to_s][:monsterName]]
        rescue
          puts "l=#{l}"
=begin 
#debug block
          card = l == nil || l.has_key?('card') == false ? {} : l['card']
          puts "card=#{card}"
          cardId = card.has_key?('cardId') ? card['cardId'] : 0
          puts "cardId=#{cardId}"
          monsterId = card.has_key?('monsterId') ? card['monsterId'] : 0
          puts "monsterId=#{monsterId}"
          puts "monster.data=#{@monster.data}"
          puts "monster[#{monsterId}]=#{@monster.data[monsterId]}"
=end
        end
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
=begin
    uri = Addressable::URI.new
    uri.query_values = post_data
    url = "/api/card/sell?#{uri.query}"
    #puts url
    return "#{url}&hash=#{encypt.getHash(url, '')}"
=end
    return TosUrl.new :path => "/api/card/sell" ,:data => post_data
  end

  def print_cards
    @cards.each do |card|
      puts card[1].inspect
    end
  end

  def get_source_card(source, merge_card)
    sourceCardId = nil
    @cards.each do |card|
      stop_at_lv_max = true
      stop_at_cd_max = true
      monster = @monster.data[card[1][:monsterId]]
      next if source.to_i != monster[:monsterId].to_i
      if merge_card['stop_at_lv_max']
        stop_at_lv_max = false if card[1][:level].to_i < monster[:maxLevel].to_i
      else
        stop_at_lv_max = false
      end
      if merge_card['stop_at_cd_max']
        stop_at_cd_max = false if card[1][:skillLevel].to_i < monster[:normalSkill][:maxLevel].to_i
      else
        stop_at_cd_max = false
      end
      if (stop_at_lv_max == merge_card['stop_at_lv_max'] and stop_at_cd_max == merge_card['stop_at_cd_max']) and (merge_card['stop_at_lv_max'] or merge_card['stop_at_cd_max'])
        card[1][:merged] = true
        next
      end
      sourceCardId = card[1][:cardId]
      #puts "source:#{monster[:monsterName]}"
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

  def get_master_merge_card(sourceCardId, merge_card)
    targetCardIds = []
    source = @monster.data[@cards[sourceCardId][:monsterId]]
    #puts "source:#{source.inspect}"
    @cards.each do |l|
      next if sourceCardId == l[1][:cardId]
      next if l[1][:merged]
      next if @bookmarks.include? l[1][:cardId]
      target = @monster.data[l[1][:monsterId]]
      #puts "target:#{target.inspect}"
      next unless merge_card['target_cards'].include? target[:monsterId].to_i
      if source[:monsterId] == target[:monsterId]
        next if l[1][:level].to_i > @cards[sourceCardId][:level].to_i
        next if l[1][:level].to_i == target[:maxLevel].to_i
        next if l[1][:skillLevel].to_i == target[:normalSkill][:maxLevel].to_i
      end
      #puts "target:#{target[:monsterName]}"
      #puts "source:#{source[:attribute]} target:#{target[:attribute]}"
      next if l[1][:level].to_i < merge_card['require_target_lv'] and l[1][:level].to_i < target[:maxLevel].to_i
      if source[:attribute] == target[:attribute]
        l[1][:merged] = true
        targetCardIds << l[1][:cardId]
        break if targetCardIds.length >= merge_card['require_target_amount_max']
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
=begin
    uri = Addressable::URI.new
    uri.query_values = post_data
    url = "/api/card/merge?#{uri.query}"
    #puts url
    return "#{url}&hash=#{encypt.getHash(url, '')}"
=end
    return TosUrl.new :path => "/api/card/merge" ,:data => post_data
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
        print "lv%2d %s" % [card[:level],monster[:monsterName]]
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
      #puts "[#{index}] #{h[:uid]} #{h[:name]} #{h[:level]} #{h[:monster_name]}"
      puts "[%3d] LV:%2d CD:%2d FP+%2s %s : %s %s" % [index,h[:monsterLevel],h[:coolDown],h[:friendPoint],h[:monster_name],is_empty(h[:club]) ? "" : "【#{h[:club]}】".yellow,h[:name]]
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
        :skillLevel => card_data[4],
        :create_at => card_data[5]
      }
      #puts card.inspect
      @cards[card_data[0]] = card
    end
    @cards = Hash[@cards.sort_by {|k,v| v[:create_at] }]
  end

  def get_login_url
=begin
    encypt = Checksum.new
    @post_data[:timestamp] = Time.now.to_i
    @post_data[:nData] = encypt.getNData
    uri = Addressable::URI.new
    uri.query_values = @post_data
    login_url = "/api/user/login?#{uri.query}"
    return "#{login_url}&hash=#{encypt.getHash(login_url, '')}"
=end
    return TosUrl.new :path => "/api/user/login" ,:data => @post_data
  end

  def get_luckydraw_url
    encypt = Checksum.new
    post_data = {
      :quantity => 1,
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
    login_url = "/api/user/diamond/luckydraw?#{uri.query}"
    return "#{login_url}&hash=#{encypt.getHash(login_url, '')}"
  end
end
