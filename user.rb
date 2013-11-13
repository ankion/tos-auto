# -*- encoding : utf-8 -*-
require "addressable/uri"
require "./checksum"
require "./monster"
require "./setting"

class User
  attr_accessor :monster, :data, :cards, :post_data, :helpers

  def initialize
    @monster = Monster.new
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

  def print_user_sc
    puts "session：#{@data['session']}"
    puts "uid：#{@data['uid']}"
    puts "名稱：#{@data['name']}"
    puts "等級：#{@data['level']}"
    puts "經驗值：#{@data['exp']}"
    puts "金錢：#{@data['coin']}"
    puts "靈魂石：#{@data['diamond']}"
    puts "體力：#{@data['currentStamina']}/#{@data['maxStamina']}"
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
    data.each do |d|
      card_data = d.split('|')
      card = {
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
