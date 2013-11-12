require "addressable/uri"
require './checksum'

class Floor
  attr_accessor :zones, :stages, :floors, :wave_team, :wave_team_data, :wave_floor, :wave_helper, :waves_data, :finish_data, :acs_data

  def initialize
    @zones = {
      '1' => {:name => '寒霜冰川'},
      '2' => {:name => '熾熱荒土'},
      '3' => {:name => '神木森林'},
      '4' => {:name => '聖光之城'},
      '5' => {:name => '暗夜深淵'},
      '6' => {:name => '以諾塔'},
      '7' => {:name => '古神遺跡'},
      '8' => {:name => '旅人的記憶'}
    }
    @stages = []
    @floors = []
    @waves_data = nil
    @wave_team = nil
    @wave_team_data = nil
    @wave_floor = nil
    @wave_helper = nil
    @finish_data = nil
    @acs_data = nil
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
      :a => 0,
      :b => @waves_data['waves'].length,
      :c => "#{rand(1)},#{rand(1)},#{rand(1)},#{rand(1)},#{rand(1)},#{rand(1)}",
      :d => 0,
      :e => 0,
      :f => @waves_data['waves'].length,
      :g => 0,
      :h => 0,
      :i => 0,
      :j => 1,
      :k => 0,
      :l => 0,
      :n => nil,
      :o => 0,
      :p => 0,
      :r => 0,
      :s => 0,
      :t => 0,
      :u => 0,
      :v => 0,
      :w => 0,
      :x => 100 + rand(500)
    }
  end

  def set_complete(user)
    reset_complete
    team_hp = user.get_team_hp(@wave_team_data, @wave_helper)
    team_attack = user.get_team_attack(@wave_team_data, @wave_helper)
    team_recover = user.get_team_recover(@wave_team_data, @wave_helper)
    #puts "current hp:#{team_hp} attack:#{team_attack} recover:#{team_recover}"
    puts "Monster list"
    @waves_data['waves'].each_index do |index|
      puts "第 #{index + 1} 波"
      #puts waves[index]['enemies'].inspect
      enemy_hp = 0
      enemy_attack = 0
      @waves_data['waves'][index]['enemies'].each do |e|
        monster = user.monster.data[e['monsterId']]
        enemy_hp += monster[:minEnemyHP].to_i + (monster[:incEnemyHP].to_i * e['level'].to_i)
        enemy_attack += monster[:minEnemyAttack].to_i + (monster[:incEnemyAttack].to_i * e['level'].to_i)

        #puts e.inspect
        puts "\tlv#{e['level']} #{user.monster.data[e['monsterId']][:monsterName]}"
        if e['lootItem']
          loot = e['lootItem']
          puts "\t\t掉落: lv#{loot['card']['level']} #{user.monster.data[loot['card']['monsterId']][:monsterName]}" if loot['type'] == 'monster'
          puts "\t\t掉落: #{loot['amount']} Gold" if loot['type'] == 'money'
        end
      end
      #puts "enemy_hp:#{enemy_hp} enemy_attack:#{enemy_attack}"
      wave_hp = team_hp
      @acs_data[:l] = wave_hp
      @acs_data[:k] = wave_hp
      @acs_data[:g] += @waves_data['waves'][index]['enemies'].length
      loop do
        @acs_data[:a] += 1
        wave_recover = team_hp - wave_hp
        wave_hp = team_hp
        wave_combo = 6 + rand(5)
        wave_attack = team_attack * (wave_combo * 0.3)
        #puts "recover:#{wave_recover} hp:#{wave_hp} combo:#{wave_combo} attack:#{wave_attack}"
        @finish_data[:maxCombo] = wave_combo if @finish_data[:maxCombo] < wave_combo
        @finish_data[:maxAttack] = wave_attack if @finish_data[:maxAttack] < wave_attack
        if wave_recover > 0
          @acs_data[:u] = wave_recover if @acs_data[:u] < wave_recover
          @acs_data[:v] = wave_recover if @acs_data[:v] > wave_recover or @acs_data[:v] == 0
          @acs_data[:w] += wave_recover
        end
        enemy_hp -= wave_attack
        break if enemy_hp < 1
        if rand(3) == 1
          wave_hp -= enemy_attack
          wave_hp = rand(100) + 1 if wave_hp < 1
          wave_damage = team_hp - wave_hp
          @acs_data[:k] = wave_hp if @acs_data[:k] > wave_hp
          @acs_data[:r] += wave_damage
          @acs_data[:p] = wave_damage if @acs_data[:p] < wave_damage
          @acs_data[:o] = wave_damage if @acs_data[:o] > wave_damage or @acs_data[:o] == 0
          @acs_data[:i] += 1
        end
      end
    end
    @acs_data[:e] = (Time.now + ((6 + rand(3)) * @acs_data[:a] )) - Time.now
    loop do
      break if @acs_data[:e] < 1000
      @acs_data[:e] -= 100
    end
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
    uri = Addressable::URI.new
    uri.query_values = post_data
    url = "/api/floor/helpers?#{uri.query}"
    #puts url
    return "#{url}&hash=#{encypt.getHash(url, '')}"
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
    uri = Addressable::URI.new
    uri.query_values = post_data
    url = "/api/floor/enter?#{uri.query}"
    #puts url
    return "#{url}&hash=#{encypt.getHash(url, '')}"
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
