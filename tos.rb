require 'net/http'
require 'json'
require 'mechanize'
require './user'
require './monster'
require './floor'

class Tos
  def initialize
    @tos_url = 'http://zh.towerofsaviors.com'
    @user = User.new
    #@monster = Monster.new
    @floor = Floor.new
    @web = Mechanize.new { |agent|
      agent.follow_meta_refresh = true
    }
  end

  def login
    puts '登入遊戲中.....'
    page = @web.get("#{@tos_url}#{@user.get_login_url}")
    #uri = URI("#{@tos_url}#{@user.get_login_url}")
    #res = Net::HTTP.get_response(uri)
    puts '登入成功'
    res_json = JSON.parse(page.body)
    puts '取得資料'
    @user.data = res_json['user']
    @user.parse_card_data(res_json['cards'])
    @floor.parse_floor_data(res_json['data'])
    @user.monster.parse_data(res_json['data']['monsters'])
    puts '======================================'
    @user.print_user_sc
    #puts @user.cards['10'].inspect
    #@user.print_teams
  end

  def choice_floor
    puts 'Zone list'
    @floor.zones.each do |index, z|
      puts "#{index} #{z[:name]}"
    end
    print 'Choice zone?'
    choice_zone = gets.chomp
    exit if choice_zone == 'q'
    puts "Stage list"
    stages = @floor.stages.select {|k| k[:zone] == choice_zone}
    stages.each do |s|
      puts "#{s[:id]} #{s[:name]}"
    end
    print 'Choice stage?'
    choice_stage = gets.chomp
    exit if choice_stage == 'q'

    puts "Floor list"
    floors = @floor.floors.select {|k| k[:stage] == choice_stage}
    floors.each do |f|
      puts "#{f[:id]} #{f[:name]}"
    end
    print 'Choice floor?'
    choice_floor = gets.chomp
    exit if choice_floor == 'q'

    puts '取得隊友名單'
    page = @web.get("#{@tos_url}#{@floor.get_helpers_url(@user, choice_floor)}")
    #uri = URI("#{@tos_url}#{@floor.get_helpers_url(@user, 16)}")
    #res = Net::HTTP.get_response(uri)
    res_json = JSON.parse(page.body)
    helpers = res_json['data']['helperList']
    #puts helpers.inspect
    @user.parse_helpers_data(helpers)
    @user.print_helpers
    print 'Choice helper?'
    choice_helper = gets.chomp
    exit if choice_helper == 'q'
    #puts @user.helpers[choice_helper.to_i].inspect
    @user.print_teams(@user.helpers[choice_helper.to_i])
    print 'Choice team?'
    choice_team = gets.chomp
    exit if choice_team == 'q'

    #puts @floor.get_enter_url(@user, choice_floor, (choice_team.to_i - 1), @user.helpers[choice_helper.to_i])
    page = @web.get("#{@tos_url}#{@floor.get_enter_url(@user, choice_floor, (choice_team.to_i - 1), @user.helpers[choice_helper.to_i])}")
    #puts page.body
    res_json = JSON.parse(page.body)
    waves = res_json['data']['waves']

    finish_data = {
      :floorId => choice_floor,
      :team => choice_team.to_i - 1,
      :floorHash => res_json['data']['floorHash'],
      :helper_uid => @user.helpers[choice_helper.to_i][:uid],
      :waves => waves.length,
      :maxAttack => 0,
      :maxCombo => 0,
      :minLoad => 43.73095703125 + rand(50),
      :maxLoad => 3965.69897460938 + rand(5000),
      :avgLoad => 1327.46998355263 + rand(500),
      :bootTime => 27418.5180664063 + rand(50000)
    }
    acs_data = {
      :a => 0,
      :b => waves.length,
      :c => "#{rand(1)},#{rand(1)},#{rand(1)},#{rand(1)},#{rand(1)},#{rand(1)}",
      :d => 0,
      :e => 0,
      :f => waves.length,
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
    team = @user.data["team#{choice_team.to_i - 1}Array"].split(',')
    helper = @user.helpers[choice_helper.to_i]
    team_hp = @user.get_team_hp(team, helper)
    team_attack = @user.get_team_attack(team, helper)
    team_recover = @user.get_team_recover(team, helper)
    #puts "current hp:#{team_hp} attack:#{team_attack} recover:#{team_recover}"
    puts "Monster list"
    waves.each_index do |index|
      puts "第 #{index + 1} 波"
      #puts waves[index]['enemies'].inspect
      enemy_hp = 0
      enemy_attack = 0
      waves[index]['enemies'].each do |e|
        monster = @user.monster.data[e['monsterId']]
        enemy_hp += monster[:minEnemyHP].to_i + (monster[:incEnemyHP].to_i * e['level'].to_i)
        enemy_attack += monster[:minEnemyAttack].to_i + (monster[:incEnemyAttack].to_i * e['level'].to_i)

        #puts e.inspect
        puts "\tlv#{e['level']} #{@user.monster.data[e['monsterId']][:monsterName]}"
        if e['lootItem']
          loot = e['lootItem']
          puts "\t\tLoot: lv#{loot['card']['level']} #{@user.monster.data[loot['card']['monsterId']][:monsterName]}" if loot['type'] == 'monster'
          puts "\t\tLoot: #{loot['amount']} Gold" if loot['type'] == 'money'
        end
      end
      #puts "enemy_hp:#{enemy_hp} enemy_attack:#{enemy_attack}"
      wave_hp = team_hp
      acs_data[:l] = wave_hp
      acs_data[:k] = wave_hp
      acs_data[:g] += waves[index]['enemies'].length
      loop do
        acs_data[:a] += 1 + rand(waves[index]['enemies'].length)
        wave_recover = team_hp - wave_hp
        wave_hp = team_hp
        wave_combo = 6 + rand(5)
        wave_attack = team_attack * (wave_combo - 3)
        #puts "recover:#{wave_recover} hp:#{wave_hp} combo:#{wave_combo} attack:#{wave_attack}"
        finish_data[:maxCombo] = wave_combo if finish_data[:maxCombo] < wave_combo
        finish_data[:maxAttack] = wave_attack if finish_data[:maxAttack] < wave_attack
        if wave_recover > 0
          acs_data[:u] = wave_recover if acs_data[:u] < wave_recover
          acs_data[:v] = wave_recover if acs_data[:v] > wave_recover or acs_data[:v] == 0
          acs_data[:w] += wave_recover
        end
        enemy_hp -= wave_attack
        break if enemy_hp < 1
        if rand(3) == 1
          wave_hp -= enemy_attack
          wave_hp = rand(100) + 1 if wave_hp < 1
          wave_damage = team_hp - wave_hp
          acs_data[:k] = wave_hp if acs_data[:k] > wave_hp
          acs_data[:r] += wave_damage
          acs_data[:p] = wave_damage if acs_data[:p] < wave_damage
          acs_data[:o] = wave_damage if acs_data[:o] > wave_damage or acs_data[:o] == 0
          acs_data[:i] += 1
        end
      end
    end
    acs_data[:e] = (Time.now + ((6 + rand(5)) * acs_data[:a] )) - Time.now
    #puts finish_data.inspect
    #puts acs_data.inspect
    puts "waiting complete.(#{acs_data[:e]})"
    print "[                    ]\r"
    print "["
    20.times do
      sleep (acs_data[:e]/20)
      print '#'
    end
    print "\n"
    #@floor.get_complete_url(@user, finish_data, acs_data)
    page = @web.get("#{@tos_url}#{@floor.get_complete_url(@user, finish_data, acs_data)}")
    #puts page.body
    res_json = JSON.parse(page.body)
    puts "友情點數：#{res_json['data']['friendpoint']}"
    puts "經驗值：#{res_json['data']['expGain']}"
    puts "金錢：#{res_json['data']['coinGain']}"
  end
end

a = Tos.new
a.login
a.choice_floor
