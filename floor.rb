# -*- encoding : utf-8 -*-
require "addressable/uri"
require './api'
require './checksum'

class Floor
  attr_accessor :helpers, :choice_helper, :waves, :is_mission

  def initialize(game_data, user, floor_data, team)
    @game_data = game_data
    @user = user
    @user_data = @user.data
    @floor_data = floor_data
    @floorId = @floor_data['id']
    @toshttp = TosHttp.new(@user_data)
    @helpers = nil
    @choice_helper = nil
    @team = team
    @waves = nil
    @floorHash = nil
    @get_data = nil
    @acs_data = nil
    @ext_acs_data = nil
    @complete_data = nil
    @is_mission = false
  end

  def helper
    return nil unless @choice_helper
    @helpers[@choice_helper]
  end

  def get_helpers
    get_data = {
      'floorId' => @floorId
    }
    res_json = @toshttp.post("/api/floor/helpers", get_data)
    @helpers = []
    res_json['data']['alluserList'].each do |helper|
      user = helper.split('|')
      guild = (user[17]) ? (user[17].split('#'))[6] : nil
      data = {
        'uid' => user[0],
        'name' => user[1],
        'loginTime' => user[2],
        'level' => user[3],
        'cardId' => user[7],
        'monsterId' => user[8],
        'monsterLevel' => user[10],
        'monster' => @game_data.monster(user[8], user[10], user[11]),
        'skillLevel' => user[11],
        'friendPoint' => user[13].to_i || 0,
        'guild' => guild,
        'clientHelperCard' => "#{user[7..11].join('|')}|0|0",
      }
      @helpers << data
    end
  end

  def enter
    get_data = {
      'floorId' => @floorId,
      'team' => @team['teamId']
    }
    if @choice_helper
      get_data['helperUid'] = self.helper['uid']
      get_data['clientHelperCard'] = self.helper['clientHelperCard']
    end
    get_data['isMission'] = 'true' if @is_mission
    res_json = @toshttp.post("/api/floor/enter", get_data)
    update_waves(res_json)
  end

  def update_waves(res_json)
    @floorHash = res_json['data']['floorHash']
    @waves = []
    res_json['data']['waves'].each do |enemies|
      wave = []
      enemies.each do |enemy_data|
        enemy_data[1].each do |enemy|
          enemy['monster'] = @game_data.monster(enemy['monsterId'], enemy['level'], 1, enemy['extras'])
          if enemy['lootItem']
            case enemy['lootItem']['type']
            when 'monster'
              card = enemy['lootItem']['card']
              monster = @game_data.monster(card['monsterId'], card['level'])
              enemy['lootItem_s'] = "lv%d %s" % [monster['level'], monster['monsterName']]
            when 'money'
              enemy['lootItem_s'] = "#{enemy['lootItem']['amount']} 金"
            when 'item'
              enemy['lootItem_s'] = @game_data.item(enemy['lootItem']['itemId'])
            end
          end
          wave << enemy
        end
      end
      @waves << wave
    end
  end

  def delay_time
    @acs_data['e']
  end

  def fight
    set_base_get_data
    set_base_acs_data
    calculate_data
  end

  def complete
    encypt = Checksum.new

    get_data = @get_data.merge(@acs_data)
    get_data['acsh'] = encypt.getHash('acsh', @ext_acs_data['acs'], '')
    res_json = @toshttp.post("/api/floor/complete", get_data, @ext_acs_data)
    @user.update_data(res_json)
    @user.update_cards(res_json)
    @complete_data = res_json['data']
  end

  def loots
    loots = []
    if @complete_data['loots']
      @complete_data['loots'].each do |loot|
        next unless loot['type'] == 'monster'
        card = loot['card']
        card['monster'] = @game_data.monster(card['monsterId'], card['level'], card['skillLevel'])
        loots << card
      end
    end
    loots
  end

  def loot_items
    loots = []
    if @complete_data['loots']
      @complete_data['loots'].each do |loot|
        next unless loot['type'] == 'item'
        item = loot
        item['itemName'] = @game_data.item(item['itemId'])
        loots << item
      end
    end
    loots
  end

  def gains
    {
      'friendpoint' => @complete_data['friendpoint'],
      'expGain' => @complete_data['expGain'],
      'coinGain' => @complete_data['coinGain'],
      'guildExpContribute' => @complete_data['guildExpContribute'],
      'guildExpBonus' => @complete_data['guildExpBonus'],
      'guildCoinBonus' => @complete_data['guildCoinBonus'],
      'diamonds' => @complete_data['diamonds'],
    }
  end

  def get_team_monster_data
    data_string = ''
    (0..4).each do |index|
      if @team['teams'][index]
        monster = @team['teams'][index]['monster']
        data_string += "%s|%s|%s|%s|%s|%s," % [
           monster['attack'].to_s,
           monster['recover'].to_s,
           monster['leaderSkill'].to_s,
           monster['normalSkill']['skillId'].to_s,
           monster['coolDown'].to_s,
           monster['skillLevel'].to_s
        ]
      else
        data_string += "0|0|0|0|0|0,"
      end
    end
    if self.helper
      monster = self.helper['monster']
      data_string += "%s|%s|%s|%s|%s|%s" % [
         monster['attack'].to_s,
         monster['recover'].to_s,
         monster['leaderSkill'].to_s,
         monster['normalSkill']['skillId'].to_s,
         monster['coolDown'].to_s,
         monster['skillLevel'].to_s
      ]
    else
      data_string += "0|0|0|0|0|0"
    end
  end

  def get_team_data
    data_string = ''
    (0..4).each do |index|
      if @team['teams'][index]
        monster = @team['teams'][index]['monster']
        data_string += "%s|%s|%s|%s|%s|%s," % [
          @team['teams'][index]['cardId'].to_s,
          monster['monsterId'].to_s,
          monster['attack'].to_s,
          monster['recover'].to_s,
          monster['HP'].to_s,
          monster['skillLevel'].to_s
        ]
      else
        data_string += "0|0|0|0|0|0,"
      end
    end
    if self.helper
      monster = self.helper['monster']
      data_string += "%s|%s|%s|%s|%s|%s" % [
        self.helper['cardId'].to_s,
        monster['monsterId'].to_s,
        monster['attack'].to_s,
        monster['recover'].to_s,
        monster['HP'].to_s,
        monster['skillLevel'].to_s
      ]
    else
      data_string += "0|0|0|0|0|0"
    end
  end

  def get_team_size
    total_size = 0
    @team['teams'].each do |card|
      monster = card['monster']
      total_size += monster['size'].to_i
    end
    total_size
  end

  def get_team_list
    team_list = []
    (0..4).each do |index|
      if @team['teams'][index]
        monster = @team['teams'][index]['monster']
        team = {
          "monsterId" => monster['monsterId'],
          "monsterLevel" => monster['level'],
          "attackCount" => 0
        }
      else
        team = {
          "monsterId" => 0,
          "monsterLevel" => 0,
          "attackCount" => 0
        }
      end
      team_list << team
    end
    team_list
  end

  def set_base_get_data
    @get_data = {
      'floorId' => @floorId,
      'team' => @team['teamId'],
      'floorHash' => @floorHash,
      'waves' => @waves.length,
      'maxAttack' => 0,
      'maxCombo' => 0,
      'minLoad' => 43.73095703125 + rand(50),
      'maxLoad' => 3965.69897460938 + rand(5000),
      'avgLoad' => 1327.46998355263 + rand(500),
      'bootTime' => 27418.5180664063 + rand(50000)
    }
    @get_data['helper_uid'] = self.helper['uid'] if @choice_helper
  end

  def set_base_acs_data
    @acs_data = {
      # Game.runtimeData.eatGemRound
      'a' => 0,
      # Game.runtimeData.waveMovedTime
      'b' => 0,
      # Game.runtimeData.SkillUsedTime
      'c' => "#{rand(1)},#{rand(1)},#{rand(1)},#{rand(1)},#{rand(1)},#{rand(1)}",
      # Game.runtimeData.retryTime
      'd' => 0,
      # Game.runtimeData.gameplayTime
      'e' => 0,
      # Game.runtimeData.numOfwave
      'f' => @waves.length,
      # Game.runtimeData.monsterNum
      'g' => 6,
      # Game.runtimeData.dieTime
      'h' => 0,
      # Game.runtimeData.monsterAttackTime
      'i' => 0,
      #
      'j' => 1,
      # Game.runtimeData.minHP
      'k' => 0,
      # Game.runtimeData.maxHP
      'l' => 0,
      #
      'n' => nil,
      # Game.runtimeData.minDamageTaken
      'o' => 0,
      # Game.runtimeData.maxDamageTaken
      'p' => 0,
      # Game.runtimeData.totalDamageTaken
      'r' => 0,
      # Game.runtimeData.gamePlayError
      's' => 0,
      # Game.runtimeData.restoreCount
      't' => 1,
      # Game.runtimeData.maxRecoverHP
      'u' => 0,
      # Game.runtimeData.minRecoverHP
      'v' => 0,
      # Game.runtimeData.totalRecoverHP
      'w' => 0,
      # BootLoader.upTime
      'x' => 100 + rand(500)
    }
    @ext_acs_data = {}
  end

  def calculate_data
    team_hp = @team['hp']
    team_attack = @team['attack']
    team_recover = @team['recover']
    @acs_data['l'] = team_hp
    @acs_data['k'] = team_hp
    enemyAttackCountPerWave_array = []
    enemyDamageTakenPerWave_array = []
    maxDamageTakenPerWave_array = []
    maxComboPerWave_array = []
    minPlayerHPPerWave_array = []
    maxPlayerAttackPerWave_array = []
    maxAttackPerRoundDuringBossWave = 0
    totalDamageToEnemy = 0
    minDamageToEnemy = 0
    maxDamageToEnemy = 0
    totalDamageCountToEnemy = 0
    baseCombo = 8
    maxCombo = rand(6) + 1
    @waves.each do |wave|
      enemy_hp = 0
      enemy_attack = 0

      wave_hp = team_hp
      enemyAttackCountPerWave = 0
      enemyDamageTakenPerWave = 0
      maxDamageTakenPerWave = 0
      maxComboPerWave = 0
      minPlayerHPPerWave = wave_hp
      maxPlayerAttackPerWave = 0

      wave.each do |enemy|
        monster = enemy['monster']
        enemy_hp = monster['enemyHP'].to_i
        enemy_attack = monster['enemyAttack'].to_i
        enemy_defense = monster['enemyDefense'].to_i

        loop do
          @acs_data['a'] += 1
          wave_recover = team_hp - wave_hp
          wave_hp = team_hp
          wave_combo = baseCombo + rand(maxCombo)
          wave_attack = team_attack * ((1 + rand(5)) + (wave_combo * 0.3))
          wave_attack *= (1 + rand(5))
          # "BOSS_DESC_2", "召喚師完全回復生命力後，剩餘的回復力會轉化為攻擊力"
          if enemy['characteristic'].to_i == 2
            wave_attack = team_recover * ((1 + rand(5)) + (wave_combo * 0.3))
            wave_attack *= (1 + rand(5))
          end
          #puts "recover:#{wave_recover} hp:#{wave_hp} combo:#{wave_combo} attack:#{wave_attack}"
          enemy_damage = wave_attack - enemy_defense
          enemy_damage = 6 if enemy_damage < 1
          totalDamageToEnemy += enemy_damage.to_i
          totalDamageCountToEnemy += 1
          if minDamageToEnemy == 0
            minDamageToEnemy = enemy_damage.to_i
            maxDamageToEnemy = enemy_damage.to_i
          else
            minDamageToEnemy = enemy_damage.to_i if minDamageToEnemy > enemy_damage
            maxDamageToEnemy = enemy_damage.to_i if maxDamageToEnemy < enemy_damage
          end

          @get_data['maxCombo'] = wave_combo if @get_data['maxCombo'] < wave_combo
          maxComboPerWave = wave_combo if maxComboPerWave < wave_combo
          @get_data['maxAttack'] = enemy_damage.to_i if @get_data['maxAttack'] < enemy_damage
          maxPlayerAttackPerWave = enemy_damage.to_i if maxPlayerAttackPerWave < enemy_damage
          if wave_recover > 0
            @acs_data['u'] = wave_recover if @acs_data['u'] < wave_recover
            @acs_data['v'] = wave_recover if @acs_data['v'] > wave_recover or @acs_data['v'] == 0
            @acs_data['w'] += wave_recover
          end
          enemy_hp -= enemy_damage
          break if enemy_hp < 1
          if rand(5) < 3
            wave_hp -= enemy_attack
            wave_hp = rand(100) + 1 if wave_hp < 1
            wave_damage = team_hp - wave_hp
            @acs_data['k'] = wave_hp if @acs_data['k'] > wave_hp
            minPlayerHPPerWave = wave_hp if minPlayerHPPerWave > wave_hp
            @acs_data['r'] += wave_damage
            enemyDamageTakenPerWave += wave_damage
            @acs_data['p'] = wave_damage if @acs_data['p'] < wave_damage
            maxDamageTakenPerWave = wave_damage if maxDamageTakenPerWave < wave_damage
            @acs_data['o'] = wave_damage if @acs_data['o'] > wave_damage or @acs_data['o'] == 0
            @acs_data['i'] += 1
            enemyAttackCountPerWave += 1
          end
        end
      end
      @acs_data['b'] += 1
      enemyAttackCountPerWave_array << enemyAttackCountPerWave
      enemyDamageTakenPerWave_array << enemyDamageTakenPerWave
      maxDamageTakenPerWave_array << maxDamageTakenPerWave
      maxComboPerWave_array << maxComboPerWave
      minPlayerHPPerWave_array << minPlayerHPPerWave
      maxPlayerAttackPerWave_array << maxPlayerAttackPerWave
      maxAttackPerRoundDuringBossWave = maxPlayerAttackPerWave
      maxAttackPerRoundDuringBossWave = 0 if @acs_data['b'] != @acs_data['f']
    end
    (@acs_data['f'] - @acs_data['b']).times do
      enemyAttackCountPerWave_array << 0
      enemyDamageTakenPerWave_array << 0
      maxDamageTakenPerWave_array << 0
      maxComboPerWave_array << 0
      minPlayerHPPerWave_array << 0
      maxPlayerAttackPerWave_array << 0
    end
    @ext_acs_data['y'] = enemyAttackCountPerWave_array.join(',')
    @ext_acs_data['z'] = enemyDamageTakenPerWave_array.join(',')
    @ext_acs_data['aa'] = self.get_team_data
    @ext_acs_data['ab'] = maxDamageTakenPerWave_array.join(',')
    @ext_acs_data['ac'] = maxComboPerWave_array.join(',')
    @ext_acs_data['ad'] = minPlayerHPPerWave_array.join(',')
    @ext_acs_data['ae'] = maxPlayerAttackPerWave_array.join(',')
    @ext_acs_data['af'] = self.get_team_monster_data
    @ext_acs_data['ag'] = 'null'
    @ext_acs_data['ah'] = 'null'
    @ext_acs_data['ai'] = 'null'
    @ext_acs_data['aj'] = 'null'
    @ext_acs_data['ak'] = 0
    @ext_acs_data['al'] = 0
    @ext_acs_data['am'] = maxAttackPerRoundDuringBossWave
    temp_acs_data = @acs_data.merge @ext_acs_data
    @ext_acs_data['acs'] = temp_acs_data.to_json
    gamePlayData = {
      "stage" => {
        "stageType" => "NORMAL",
        "stageID" => @floor_data['stageId'],
        "stageZone" => @game_data.floors[@floor_data['zoneId'].to_i]['scene']
      },
      "floor" => {
        "staminaCost" => @floor_data['stamina']
      },
      "user" => {
        "staminaBeforeBattle" => @user_data['currentStamina'].to_i - @floor_data['stamina'].to_i,
        "staminaAfterBattle" => @user_data['currentStamina']
      },
      "team" => {
        "maxHP" => @acs_data['k'],
        "maxRecover" => @acs_data['u'],
        "endHP" => @acs_data['l'],
        "teamSize" => self.get_team_size,
        "teamList" => self.get_team_list,
        "totalDamageByEnemy" => @acs_data['r'],
        "totalDamageCountByEnemy" => @acs_data['i'],
        "minDamageByEnemy" => @acs_data['o'],
        "maxDamageByEnemy" => @acs_data['p'],
        "totalDamageToEnemy" => totalDamageToEnemy,
        "totalDamageCountToEnemy" => totalDamageCountToEnemy,
        "minDamageToEnemy" => minDamageToEnemy,
        "maxDamageToEnemy" => maxDamageToEnemy,
        "maxAttackPerRoundDuringBossWave" => maxAttackPerRoundDuringBossWave
      }
    }
    gamePlayData['team']["helperUid"] = self.helper['uid'] if self.helper
    @ext_acs_data['gamePlayData'] = gamePlayData.to_json
    sysinfo = Settings['sysInfo'].split('|')
    systemInfo = {
      "appVersion" => Settings['tos_version'],
      "deviceModel" => "Motorola MB525",
      "deviceType" => "Handheld",
      "deviceUniqueIdentifier" => Settings['deviceKey'],
      "operatingSystem" => sysinfo[0],
      "systemVersion" => "2.3.7",
      "processorType" => sysinfo[1],
      "processorCount" => sysinfo[2],
      "systemMemorySize" => sysinfo[3],
      "graphicsMemorySize" => sysinfo[4],
      "graphicsDeviceName" => sysinfo[5],
      "graphicsDeviceVendor" => "Imagination Technologies",
      "graphicsDeviceVersion" => sysinfo[7],
      "emua" => "FALSE",
      "emub" => "FALSE",
      "npotSupport" => sysinfo[8],
      "supportsAccelerometer" => "True",
      "supportsGyroscope" => "False",
      "supportsLocationService" => "True",
      "supportsVibration" => "True",
      "maxTextureSize" => sysinfo[10],
      "screenWidth" => "480",
      "screenHeight" => "854",
      "screenDPI" => "264.7876",
      "IDFA" => "",
      "IDFV" => "",
      "MAC" => sysinfo[14],
      "networkType" => "WIFI"
    }
    @ext_acs_data['systemInfo'] = systemInfo.to_json

    base_time = (6 + rand(3))
    bonus_time = 1
    bonus_time += 1 if @acs_data['a'] > 20

    if Settings['fast_mode']
      base_time = 3
      bonus_time = 1
    end

    @acs_data['e'] = (Time.now + ((base_time * (@acs_data['a'] + @acs_data['d']) ) * bonus_time)) - Time.now

    @acs_data['e'] = 25.0 if @acs_data['e'] < 25.0
  end
end
