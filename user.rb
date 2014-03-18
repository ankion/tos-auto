# -*- encoding : utf-8 -*-
require "addressable/uri"
require "./api"
require "./checksum"
require "./floor"
require "./setting"
require "./http"
require "./gamedata"

class User
  attr_accessor :data, :current_team, :cards

  def initialize(uniqueKey, deviceKey)
    @uniqueKey = uniqueKey
    @deviceKey = deviceKey
    @data = {
      "uid" => nil,
      "session" => nil,
      "name" => nil,
      "level" => nil,
      "exp" => nil,
      "team0Array" => nil,
      "team1Array" => nil,
      "team2Array" => nil,
      "team3Array" => nil,
      "team4Array" => nil,
      "inventoryCapacity" => nil,
      "totalCards" => nil,
      "currentStamina" => nil,
      "maxStamina" => nil,
      "friendPoint" => nil,
      "coin" => nil,
      "diamond" => nil,
      "bookmarks" => nil,
      "guildId" => nil,
      "completedFloorIds" => nil,
      "completedStageIds" => nil,
    }
    @game_data = GameData.new
    @current_floor = nil
    @current_team = nil
    @cards = {}
  end

  def login
    get_data = {
      'type' => 'device',
      'uniqueKey' => @uniqueKey,
      'deviceKey' => @deviceKey,
      'sysInfo' => Settings['sysInfo'],
    }
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/user/login", get_data)
    self.update_data(res_json)
    @game_data.update_monster(res_json)
    self.update_cards(res_json)
    @game_data.update_floors(res_json, @data['guildId'].to_i != 0)
  end

  def floors
    @game_data.floors
  end

  def floor(floor_data)
    @current_floor = Floor.new(@game_data, self, floor_data, @current_team)
  end

  def update_cards(res_json)
    return unless res_json['cards']
    @cards = {}
    res_json['cards'].each do |val|
      card_data = val.split('|')
      @cards[card_data[0].to_i] = {
        'cardId' => card_data[0],
        'monsterId' => card_data[1],
        'exp' => card_data[2],
        'level' => card_data[3],
        'skillLevel' => card_data[4],
        'create_at' => card_data[5],
        'monster' => @game_data.monster(card_data[1], card_data[3], card_data[4]),
        'bookmark' => @data['bookmarks'].include?(card_data[0]) | @data['teamArray'].include?(card_data[0])
      }
    end
  end

  def update_data(res_json)
    return unless res_json['user']
    @data.each do |key, val|
      @data[key] = res_json['user'][key] if res_json['user'][key]
    end
    @data['next_exp'] = @game_data.next_exp @data['level']
    @data['teamArray'] = []
    @data['teamArray'] += @data['team0Array'].split(',')
    @data['teamArray'] += @data['team1Array'].split(',')
    @data['teamArray'] += @data['team2Array'].split(',')
    @data['teamArray'] += @data['team3Array'].split(',')
    @data['teamArray'] += @data['team4Array'].split(',')
    @data['teamArray'].delete 0
  end

  def teams
    {
      1 => self.team(1),
      2 => self.team(2),
      3 => self.team(3),
      4 => self.team(4),
      5 => self.team(5)
    }
  end

  def team(index)
    team_data = @data["team#{index - 1}Array"].split(',')
    team = []
    team_data.each do |val|
      next if val.to_i == 0
      card = @cards[val.to_i]
      team << card
    end
    team
  end

  def select_team(index)
    @current_team = {
      'teamId' => index - 1,
      'teamId_s' => "team#{index - 1}Array"
    }
    @current_team['teams'] = self.team(index)
    @current_team['hp'] = 0
    @current_team['attack'] = 0
    @current_team['recover'] = 0
    @current_team['teams'].each do |member|
      @current_team['hp'] += member['monster']['hp'].to_i
      @current_team['attack'] += member['monster']['attack'].to_i
      @current_team['recover'] += member['monster']['recover'].to_i
    end

  end

  def first_team
    (0..4).each do |t|
      next if @data["team#{t}Array"] == '0,0,0,0,0'
      return (t + 1).to_s
    end
    return nil
  end

  def cards_full?
    @data['totalCards'].to_i >= (@data['inventoryCapacity'].to_i + 10)
  end

  def sell_cards(cards)
    card_count = cards.count
    sell_time = 1
    first = 1
    if card_count <= 10
      last = card_count
    else
      last = 10
      sell_time = card_count / 10
      sell_time += 1 if card_count % 10
    end
    res_json = nil
    merge_time.times do
      get_data = {
        'targetCardIds' => cards[(first-1)..(last-1)].join(',')
      }
      toshttp = TosHttp.new(@data)
      res_json = toshttp.post("/api/card/sell", get_data)
      first = last + 1
      last = last + 10
      last = card_count if last > card_count
    end
    self.update_data(res_json)
    self.update_cards(res_json)
    res_json['data']
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

  def merge_card(sourceCardId, targetCardIds)
    card_count = targetCardIds.count
    merge_time = 1
    first = 1
    if card_count <= 5
      last = card_count
    else
      last = 5
      merge_time = card_count / 5
      merge_time += 1 if card_count % 5
    end
    res_json = nil
    merge_time.times do
      get_data = {
        'sourceCardId' => sourceCardId,
        'targetCardIds' => targetCardIds[(first-1)..(last-1)].join(',')
      }
      toshttp = TosHttp.new(@data)
      res_json = toshttp.post("/api/card/merge", get_data)
      first = last + 1
      last = last + 5
      last = card_count if last > card_count
    end
    self.update_data(res_json)
    self.update_cards(res_json)
    card = res_json['data']['card']
    card['monster'] = @game_data.monster(card['monsterId'], card['level'], card['skillLevel'])
    card
  end

  def find_cards_by_monster(id)
    @cards.select {|k,v| v['monsterId'].to_i == id.to_i and not v['bookmark']}
  end

  def get_evolve_card(cardId)
    monster = @cards[cardId.to_i]['monster']
    evolutions = []
    (0..4).each do |index|
      evolution = @game_data.monster(monster["evolutionRule#{index}"].to_i)
      evolutions << evolution if evolution
    end
    evolutions
  end

  def evolve_card(sourceCardId, targetCardIds)
    get_data = {
      'sourceCardId' => sourceCardId,
      'targetCardIds' => targetCardIds.join(',')
    }
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/card/evolve", get_data)
    self.update_data(res_json)
    self.update_cards(res_json)
    card = res_json['data']['card']
    card['monster'] = @game_data.monster(card['monsterId'], card['level'], card['skillLevel'])
    card
  end

  def frienddraw(quantity = 1)
    get_data = {
      'quantity' => quantity
    }
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/user/friendpoint/luckydraw", get_data)
    self.update_data(res_json)
    self.update_cards(res_json)
    cards_data = res_json['data']['cardIds']
    cards = []
    cards_data.each do |cardId|
      cards << @cards[cardId.to_i]
    end
    cards
  end

  def luckydraw
    get_data = {
      'quantity' => 1
    }
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/user/diamond/luckydraw", get_data)
    self.update_data(res_json)
    self.update_cards(res_json)
    card = res_json['data']['card']
    card['monster'] = @game_data.monster(card['monsterId'], card['level'], card['skillLevel'])
    card
  end

  def extend_box
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/user/diamond/extend_box")
    self.update_data(res_json)
  end

  def extend_friend
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/user/diamond/extend_friend")
    self.update_data(res_json)
  end

  def restore_stamina
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/user/diamond/restore_stamina")
    self.update_data(res_json)
  end
end
