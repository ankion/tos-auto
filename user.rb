# -*- encoding : utf-8 -*-
require "addressable/uri"
require "./api"
require "./checksum"
require "./floor"
require "./setting"
require "./http"
require "./gamedata"

class User
  attr_accessor :data, :current_team, :cards, :guildMission

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
      "guild" => nil,
      "completedFloorIds" => nil,
      "completedStageIds" => nil,
      "items" => nil,
    }
    @game_data = GameData.new
    @current_floor = nil
    @current_team = nil
    @cards = {}
    @guildMission = nil
  end

  def register(name, attribute)
    get_data = {
      'name' => name,
      'attribute' => attribute,
      'type' => 'device',
      'uniqueKey' => @uniqueKey,
      'deviceKey' => @deviceKey,
      'sysInfo' => Settings['sysInfo'],
    }

    systemInfo_data = {
      #"appVersion" => Settings['tos_version'],
      #"deviceModel" => "Motorola MB525",
      #"deviceType" => "Handheld",
      "deviceUniqueIdentifier" => @deviceKey,
      #"operatingSystem" => "Android OS 2.3.7 / API-10 (GWK74/20130501)",
      #"systemVersion" => "2.3.7",
      #"processorType" => "ARMv7 VFPv3 NEON",
      #"processorCount" => "1",
      #"systemMemorySize" => "477",
      #"graphicsMemorySize" => "35",
      #"graphicsDeviceName" => "PowerVR SGX 530",
      #"graphicsDeviceVendor" => "Imagination Technologies",
      #"graphicsDeviceVersion" => "OpenGL ES-CM 1.1",
      #"emua" => "FALSE",
      #"emub" => "FALSE",
      #"npotSupport" => "None",
      #"supportsAccelerometer" => "True",
      #"supportsGyroscope" => "False",
      #"supportsLocationService" => "True",
      #"supportsVibration" => "True",
      #"maxTextureSize" => "2048",
      #"screenWidth" => "480",
      #"screenHeight" => "854",
      #"screenDPI" => "264.7876",
      #"IDFA" => "",
      #"IDFV" => "",
      #"MAC" => "40:fc:89:02:b3:55",
      #"networkType" => "WIFI"
    }
    post_data = {
      'systemInfo' => systemInfo_data.to_json
    }
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/user/register", get_data, post_data)
    self.update_data(res_json)
    @game_data.update_monster(res_json)
    self.update_cards(res_json)
    @game_data.update_floors(res_json, @data['guildId'].to_i != 0)
  end

  def team_save(index, team)
    get_data = {
      "team#{index}" => team
    }
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/user/team/save", get_data)
  end

  def set_helper(id)
    get_data = {
      "cardId" => id
    }
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/user/set_helper", get_data)
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

  def find_floor_by(id)
    @game_data.find_floor_by(id)
  end

  def update_cards(res_json)
    return unless res_json['cards']
    count_card = {}
    @cards = {}
    res_json['cards'].each do |val|
      card_data = val.split('|')
      if count_card[card_data[1].to_i]
        count_card[card_data[1].to_i] += 1
      else
        count_card[card_data[1].to_i] = 1
      end
      @cards[card_data[0].to_i] = {
        'cardId' => card_data[0],
        'monsterId' => card_data[1],
        'exp' => card_data[2],
        'level' => card_data[3],
        'skillLevel' => card_data[4],
        'create_at' => card_data[5],
        'monster' => @game_data.monster(card_data[1], card_data[3], card_data[4]),
        'bookmark' => @data['bookmarks'].include?(card_data[0]) | @data['teamArray'].include?(card_data[0]),
        'index' => count_card[card_data[1].to_i]
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

  def level_to_exp(expType, level)
    exp = (((level.to_i - 1).to_f ** 2.0) * (expType.to_f * 52.06164)).ceil
  end

  def find_cards_by_monster(id)
    cards = @cards.select {|k,v| v['monsterId'].to_i == id.to_i}
    cards = cards.sort_by {|k, v| v['create_at'].to_i}
  end

  def find_cards_by_monsters(ids)
    cards = @cards.select {|k,v| ids.include? v['monsterId'].to_i}
    cards = cards.sort_by {|k, v| v['create_at'].to_i}
  end

  def find_cards_by_monsters_skill(ids)
    cards = @cards.select {|k,v| ids.include? v['monsterId'].to_i \
      and v['monster']['skillLevel'].to_i < v['monster']['normalSkill']['maxLevel'].to_i}
    cards = cards.sort_by {|k, v| v['create_at'].to_i}
  end

  def find_cards_by_monster_bookmark(id)
    @cards.select {|k,v| v['monsterId'].to_i == id.to_i and not v['bookmark']}
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
    sell_time.times do
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

  def guild_donate_coin(amount)
    get_data = {
      'guildId' => @data['guildId'],
      'coin' => amount
    }
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/guild/donate", get_data)
    self.update_data(res_json)
  end

  def update_guild_mission(res_json)
    @guildMission = res_json['data']['guildMission']
    @guildMission['rewardMonsters'] = []
    @guildMission['rewardMonstersIds'].each do |id|
      @guildMission['rewardMonsters'] << @game_data.monster(id)
    end
    @guildMission['guildMissions'].each do |mission|
      name = "任務類別 %s" % [mission['type']]
      case mission['type']
      when '1'
        name = "牲品的獻祭 (Card:%s)" % [mission['typeValue']]
        mission['monsters'] = @game_data.monsters(mission['typeValue'].split(','))
      when '2'
        name = "靈魂的獻祭 (Exp:%s)" % [mission['typeValue']]
      when '3'
        name = "無私的奉獻 (Coin:%s)" % [mission['typeValue']]
      when '4'
        name = "淨化地下城任務 (Floor:%s)" % [mission['typeValue']]
      when '6'
        name = "搜集繁星的碎片 (%s %d/20)" % [@game_data.item(mission['typeValue']), @data['items'][mission['typeValue']]]
      end
      mission['name'] = name
    end
  end

  def guild_mission_list
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/guild/mission/list")
    update_guild_mission(res_json)
  end

  def guild_mission_achieve(mission, cardIds = nil)
    get_data = {
      'missionId' => mission['missionId'],
      'missionKey' => @guildMission['missionKey']
    }
    get_data['cardIds'] = cardIds.join(',') if cardIds
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/guild/mission/achieve", get_data)
    self.update_data(res_json)
    self.update_cards(res_json)
  end

  def guild_mission_claim
    get_data = {
      'missionKey' => @guildMission['missionKey']
    }
    toshttp = TosHttp.new(@data)
    res_json = toshttp.post("/api/guild/mission/claim", get_data)
    self.update_data(res_json)
    self.update_cards(res_json)
    cards_data = res_json['data']['cardIds']
    cards = []
    cards_data.each do |cardId|
      cards << @cards[cardId.to_i]
    end
    cards
  end
end
