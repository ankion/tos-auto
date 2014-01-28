# -*- encoding : utf-8 -*-
require "addressable/uri"
require './api'
require './checksum'

class Floor
  attr_accessor :zones, :stages, :floors, :wave_team, :wave_team_data, :wave_floor, :wave_helper, :waves_data, :wave_fail, :finish_data, :acs_data, :stage_bonus, :bonus_type

  def initialize
    @zones = {
      '1' => {:name => '寒霜冰川', :requireFloor => 8},
      '2' => {:name => '熾熱荒土', :requireFloor => 11},
      '3' => {:name => '神木森林', :requireFloor => 14},
      '4' => {:name => '聖光之城', :requireFloor => 17},
      '5' => {:name => '暗夜深淵', :requireFloor => 20},
      '6' => {:name => '以諾塔'},
      '7' => {:name => '古神遺跡', :requireFloor => 23},
      '8' => {:name => '旅人的記憶', :requireFloor => 88}
    }
    @zones.each do |index, z|
      #puts "zones %s %s" % [index,z]
      z[:name] = attribute_color(z[:name],index.to_i) if z[:name]
    end
    @bonus_type = {
      0 => 'NONE',
      1 => '體力消耗減 50%',
      2 => '封印卡掉落率 200%',
      3 => 'Exp 獲得量 200%',
      4 => 'RARE_APPEAR',
      5 => '碎片掉落 200%',
      6 => 'REWARD',
      7 => 'ALERT'
    }
    @one_time_floors = [222, 488]
    @one_time_stages = [63, 150, 132, 178]
    @stages = []
    @floors = []
    @waves_data = nil
    @wave_team = nil
    @wave_team_data = nil
    @wave_floor = nil
    @wave_helper = nil
    @wave_fail = false
    @finish_data = nil
    @acs_data = nil
    @max_round = 100
    @stage_bonus = nil
  end

  def one_time_floor?
    @one_time_floors.include? @wave_floor.to_i
  end

  def one_time_stage?(stage)
    @one_time_stages.include? stage.to_i
  end

  def reset_complete
    @finish_data = {
      :floorId => @wave_floor,
      :team => @wave_team,
      :floorHash => @waves_data['floorHash'],
      :helper_uid => @wave_helper[:uid],
      :waves => @waves_data['waves'].length,
      :maxAttack => 0,
      :maxCombo => 0,
      :minLoad => 43.73095703125 + rand(50),
      :maxLoad => 3965.69897460938 + rand(5000),
      :avgLoad => 1327.46998355263 + rand(500),
      :bootTime => 27418.5180664063 + rand(50000)
    }
    @acs_data = {
      # Game.runtimeData.eatGemRound
      :a => 0,
      # Game.runtimeData.waveMovedTime
      :b => 0,
      # Game.runtimeData.SkillUsedTime
      :c => "#{rand(1)},#{rand(1)},#{rand(1)},#{rand(1)},#{rand(1)},#{rand(1)}",
      # Game.runtimeData.retryTime
      :d => 0,
      # Game.runtimeData.gameplayTime
      :e => 0,
      # Game.runtimeData.numOfwave
      :f => @waves_data['waves'].length,
      # Game.runtimeData.monsterNum
      :g => 6,
      # Game.runtimeData.dieTime
      :h => 0,
      # Game.runtimeData.monsterAttackTime
      :i => 0,
      #
      :j => 1,
      # Game.runtimeData.minHP
      :k => 0,
      # Game.runtimeData.maxHP
      :l => 0,
      #
      :n => nil,
      # Game.runtimeData.minDamageTaken
      :o => 0,
      # Game.runtimeData.maxDamageTaken
      :p => 0,
      # Game.runtimeData.totalDamageTaken
      :r => 0,
      # Game.runtimeData.gamePlayError
      :s => 0,
      # Game.runtimeData.restoreCount
      :t => 1,
      # Game.runtimeData.maxRecoverHP
      :u => 0,
      # Game.runtimeData.minRecoverHP
      :v => 0,
      # Game.runtimeData.totalRecoverHP
      :w => 0,
      # BootLoader.upTime
      :x => 100 + rand(500)
    }
  end

  def set_complete(user)
    reset_complete
    team_hp = user.get_team_hp(@wave_team_data, @wave_helper)
    team_attack = user.get_team_attack(@wave_team_data, @wave_helper)
    team_recover = user.get_team_recover(@wave_team_data, @wave_helper)
    #puts "current hp:#{team_hp} attack:#{team_attack} recover:#{team_recover}"
    @acs_data[:l] = team_hp
    @acs_data[:k] = team_hp
    @wave_fail = false
    enemyAttackCountPerWave_array = []
    enemyDamageTakenPerWave_array = []
    maxDamageTakenPerWave_array = []
    maxComboPerWave_array = []
    minPlayerHPPerWave_array = []
    maxPlayerAttackPerWave_array = []
    maxAttackPerRoundDuringBossWave = 0
    baseCombo = 8
    maxCombo = rand(6) + 1
    puts "Monster list"
    @waves_data['waves'].each_index do |index|
      puts "第 #{index + 1} 波"
      #puts waves[index]['enemies'].inspect
      enemy_hp = 0
      enemy_attack = 0

      wave_hp = team_hp
      #@acs_data[:g] += @waves_data['waves'][index]['enemies'].length
      enemyAttackCountPerWave = 0
      enemyDamageTakenPerWave = 0
      maxDamageTakenPerWave = 0
      maxComboPerWave = 0
      minPlayerHPPerWave = wave_hp
      maxPlayerAttackPerWave = 0

      @waves_data['waves'][index]['enemies'].each do |e|
        break if @acs_data[:a] > @max_round
        monster = user.monster.data[e['monsterId'].to_s]
        enemy_hp = monster[:minEnemyHP].to_i + (monster[:incEnemyHP].to_i * e['level'].to_i)
        enemy_attack = monster[:minEnemyAttack].to_i + (monster[:incEnemyAttack].to_i * e['level'].to_i)
        enemy_defense = monster[:minEnemyDefense].to_i + (monster[:incEnemyDefense].to_i * e['level'].to_i)

        #puts e.inspect
        puts "\tlv%3d %s" % [e['level'],monster[:monsterName]]
        if e['lootItem']
          loot = e['lootItem']
          prefix = "戰勵品：".bg_blue.yellow.bold
          puts "\t#{prefix} lv%d %s" % [loot['card']['level'],user.monster.data[loot['card']['monsterId']][:monsterName]] if loot['type'] == 'monster'
          puts "\t#{prefix} #{loot['amount']} 金" if loot['type'] == 'money'
        end
        #puts "enemy_hp:#{enemy_hp} enemy_attack:#{enemy_attack}"
        loop do
          break if @acs_data[:a] > @max_round
          @acs_data[:a] += 1
          wave_recover = team_hp - wave_hp
          wave_hp = team_hp
          wave_combo = baseCombo + rand(maxCombo)
          wave_attack = team_attack * ((1 + rand(5)) + (wave_combo * 0.3))
          wave_attack *= (1 + rand(5))
          #puts "recover:#{wave_recover} hp:#{wave_hp} combo:#{wave_combo} attack:#{wave_attack}"
          enemy_damage = wave_attack - enemy_defense
          enemy_damage = 1 if enemy_damage < 1
          @finish_data[:maxCombo] = wave_combo if @finish_data[:maxCombo] < wave_combo
          maxComboPerWave = wave_combo if maxComboPerWave < wave_combo
          @finish_data[:maxAttack] = enemy_damage.to_i if @finish_data[:maxAttack] < enemy_damage
          maxPlayerAttackPerWave = enemy_damage.to_i if maxPlayerAttackPerWave < enemy_damage
          if wave_recover > 0
            @acs_data[:u] = wave_recover if @acs_data[:u] < wave_recover
            @acs_data[:v] = wave_recover if @acs_data[:v] > wave_recover or @acs_data[:v] == 0
            @acs_data[:w] += wave_recover
          end
          enemy_hp -= enemy_damage
          break if enemy_hp < 1
          if rand(5) < 3
            wave_hp -= enemy_attack
            wave_hp = rand(100) + 1 if wave_hp < 1
            wave_damage = team_hp - wave_hp
            @acs_data[:k] = wave_hp if @acs_data[:k] > wave_hp
            minPlayerHPPerWave = wave_hp if minPlayerHPPerWave > wave_hp
            @acs_data[:r] += wave_damage
            enemyDamageTakenPerWave += wave_damage
            @acs_data[:p] = wave_damage if @acs_data[:p] < wave_damage
            maxDamageTakenPerWave = wave_damage if maxDamageTakenPerWave < wave_damage
            @acs_data[:o] = wave_damage if @acs_data[:o] > wave_damage or @acs_data[:o] == 0
            @acs_data[:i] += 1
            enemyAttackCountPerWave += 1
          end
        end
      end
      if @acs_data[:a] > @max_round
        puts 'This wave is fail.'
        @acs_data[:h] += 1
        @acs_data[:k] = 0
        @wave_fail = true
        break
      end
      @acs_data[:b] += 1
      enemyAttackCountPerWave_array << enemyAttackCountPerWave
      enemyDamageTakenPerWave_array << enemyDamageTakenPerWave
      maxDamageTakenPerWave_array << maxDamageTakenPerWave
      maxComboPerWave_array << maxComboPerWave
      minPlayerHPPerWave_array << minPlayerHPPerWave
      maxPlayerAttackPerWave_array << maxPlayerAttackPerWave
      maxAttackPerRoundDuringBossWave = maxPlayerAttackPerWave
      maxAttackPerRoundDuringBossWave = 0 if @acs_data[:b] != @acs_data[:f]
    end
    (@acs_data[:f] - @acs_data[:b]).times do
      enemyAttackCountPerWave_array << 0
      enemyDamageTakenPerWave_array << 0
      maxDamageTakenPerWave_array << 0
      maxComboPerWave_array << 0
      minPlayerHPPerWave_array << 0
      maxPlayerAttackPerWave_array << 0
    end
    @acs_data[:y] = enemyAttackCountPerWave_array.join('|')
    @acs_data[:z] = enemyDamageTakenPerWave_array.join('|')
    @acs_data[:ab] = maxDamageTakenPerWave_array.join('|')
    @acs_data[:ac] = maxComboPerWave_array.join('|')
    @acs_data[:ad] = minPlayerHPPerWave_array.join('|')
    @acs_data[:ae] = maxPlayerAttackPerWave_array.join('|')
    @acs_data[:am] = maxAttackPerRoundDuringBossWave
    floor_data = @floors.select {|k| k[:id] == @wave_floor}
    #puts "floor:#{floor_data.first[:name]}"
    #if floor_data.first[:name].include? '地獄級'
      #puts 'Hell level!!!!!'
      #@acs_data[:d] += 1 + rand(5)
      #@acs_data[:h] = @acs_data[:d]
      #@acs_data[:c] = "#{rand(5)},#{rand(5)},#{rand(5)},#{rand(5)},#{rand(5)},#{rand(5)}"
    #end
    base_time = (6 + rand(3))
    bonus_time = 1
    bonus_time += 1 if @acs_data[:a] > 20
    bonus_time += 1 if @acs_data[:a] > 40

    if Settings['fast_mode']
      base_time = 3
      bonus_time = 1
    end

    @acs_data[:e] = (Time.now + ((base_time * (@acs_data[:a] + @acs_data[:d]) ) * bonus_time)) - Time.now

    @acs_data[:e] = 25.0 if @acs_data[:e] < 25.0
    #loop do
      #break if @acs_data[:e] < 1200
      #@acs_data[:e] -= 100
    #end
    puts "floorId:#{@wave_floor}"
    puts "maxAttack:#{@finish_data[:maxAttack]} maxCombo:#{@finish_data[:maxCombo]}"
    puts "round:#{@acs_data[:a]} retry:#{@acs_data[:d]} die:#{@acs_data[:h]}"
    puts "monsterAttackTime:#{@acs_data[:i]} totalDamage:#{@acs_data[:r]}"
    #puts @acs_data.inspect
  end

  def parse_floor_data(data)
    data['stageList'].each do |s|
      stage = s.split('|')
      @stages << {:id => stage[0], :zone => stage[3], :name => stage[9], :start_at => stage[7], :end_at => stage[8]}
    end
    data['floorList'].each do |f|
      floor = f.split('|')
      @floors << {:id => floor[0], :stage => floor[1], :name => floor[7], :stamina => floor[4]}
    end
  end

  def get_helpers_url(user)
    encypt = Checksum.new
    post_data = {
      :floorId => @wave_floor,
      :uid => user.data['uid'],
      :session => user.data['session'],
      :language => user.post_data[:language],
      :platform => user.post_data[:platform],
      :version => user.post_data[:version],
      :timestamp => Time.now.to_i,
      :timezone => user.post_data[:timezone],
      :nData => encypt.getNData
    }
=begin    
    uri = Addressable::URI.new
    uri.query_values = post_data
    url = "/api/floor/helpers?#{uri.query}"
    #puts url
    return "#{url}&hash=#{encypt.getHash(url, '')}"
=end
    return TosUrl.new :path => "/api/floor/helpers" ,:data => post_data
  end

  def get_enter_url(user)
    encypt = Checksum.new
    post_data = {
      :floorId => @wave_floor,
      :team => @wave_team,
      :helperUid => @wave_helper[:uid],
      :clientHelperCard => @wave_helper[:clientHelperCard],
      :uid => user.data['uid'],
      :session => user.data['session'],
      :language => user.post_data[:language],
      :platform => user.post_data[:platform],
      :version => user.post_data[:version],
      :timestamp => Time.now.to_i,
      :timezone => user.post_data[:timezone],
      :nData => encypt.getNData
    }
=begin
    uri = Addressable::URI.new
    uri.query_values = post_data
    url = "/api/floor/enter?#{uri.query}"
    #puts url
    return "#{url}&hash=#{encypt.getHash(url, '')}"
=end
    return TosUrl.new :path => "/api/floor/enter" ,:data => post_data
  end

  def get_fail_url(user)
    encypt = Checksum.new
    post_data = {
      :floorId => @wave_floor,
      :team => @wave_team,
      :helperUid => @wave_helper[:uid],
      :uid => user.data['uid'],
      :session => user.data['session'],
      :language => user.post_data[:language],
      :platform => user.post_data[:platform],
      :version => user.post_data[:version],
      :timestamp => Time.now.to_i,
      :timezone => user.post_data[:timezone],
      :nData => encypt.getNData
    }
=begin    
    uri = Addressable::URI.new
    uri.query_values = post_data
    url = "/api/floor/fail?#{uri.query}"
    #puts url
    return "#{url}&hash=#{encypt.getHash(url, '')}"
=end
    return TosUrl.new :path => "api/floor/fail" ,:data => post_data    
  end

  def get_complete_url(user)
    encypt = Checksum.new
    @finish_data[:uid] = user.data['uid']
    @finish_data[:session] = user.data['session']
    @finish_data[:language] = user.post_data[:language]
    @finish_data[:platform] = user.post_data[:platform]
    @finish_data[:version] = user.post_data[:version]
    @finish_data[:timestamp] = Time.now.to_i
    @finish_data[:timezone] = user.post_data[:timezone]
    @finish_data[:nData] = encypt.getNData
#
    acs_uri = Addressable::URI.new
    acs_uri.query_values = @acs_data
    acs_url = acs_uri.query
    acs_url = "#{acs_url}&acsh=#{encypt.getHash(acs_url, '')}"
    #puts acs_url

    uri = Addressable::URI.new
    uri.query_values = @finish_data
    url = "/api/floor/complete?#{uri.query}&#{acs_url}"
    #puts url
    return "#{url}&hash=#{encypt.getHash(url, '')}"
  end
end
