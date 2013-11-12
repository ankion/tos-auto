require 'net/http'
require 'json'
require 'mechanize'
require './user'
require './monster'
require './floor'
require './setting'

class Tos
  def initialize
    @tos_url = Settings['tos_url']
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
    @user.print_teams
    print 'Choice team?'
    choice_team = gets.chomp
    exit if choice_team == 'q'
    @floor.wave_team = choice_team.to_i - 1
    @floor.wave_team_data = @user.data["team#{@floor.wave_team}Array"].split(',')
  end

  def choice_floor
    puts 'Zone list'
    @floor.zones.each do |index, z|
      puts "#{index} #{z[:name]}"
    end
    print 'Choice zone?(b:back,q:quit)'
    choice_zone = gets.chomp
    exit if choice_zone == 'q'
    return false if choice_zone == 'b'

    puts "Stage list"
    stages = @floor.stages.select {|k| k[:zone] == choice_zone}
    stages.each do |s|
      unless s[:start_at] == ''
        next if Time.now.to_i < Time.at(s[:start_at].to_i).to_i
        next if Time.now.to_i > Time.at(s[:end_at].to_i).to_i
      end
      print "#{s[:id]} #{s[:name]}"
      print "(completed)" if (@user.data['completedStageIds'].include? s[:id].to_i)
      print " #{Time.at(s[:start_at].to_i).strftime('%m/%d %H:%M')} ~ #{Time.at(s[:end_at].to_i).strftime('%m/%d %H:%M')}" unless s[:start_at] == ''
      print "\n"
    end
    print 'Choice stage?(b:back,q:quit)'
    choice_stage = gets.chomp
    exit if choice_stage == 'q'
    return false if choice_stage == 'b'

    puts "Floor list"
    floors = @floor.floors.select {|k| k[:stage] == choice_stage}
    floors.each do |f|
      puts "#{f[:id]} #{f[:name]} #{f[:stamina]} #{((@user.data['completedFloorIds'].include? f[:id].to_i) ? '(completed)' : '')}"
    end
    print 'Choice floor?(b:back,q:quit)'
    choice_floor = gets.chomp
    exit if choice_floor == 'q'
    return false if choice_floor == 'b'
    @floor.wave_floor = choice_floor

    puts '取得隊友名單'
    page = @web.get("#{@tos_url}#{@floor.get_helpers_url(@user)}")
    #uri = URI("#{@tos_url}#{@floor.get_helpers_url(@user, 16)}")
    #res = Net::HTTP.get_response(uri)
    res_json = JSON.parse(page.body)
    helpers = res_json['data']['helperList']
    #puts helpers.inspect
    @user.parse_helpers_data(helpers)
    @user.print_helpers
    print 'Choice helper?(b:back,q:quit)'
    choice_helper = gets.chomp
    exit if choice_helper == 'q'
    return false if choice_helper == 'b'
    @floor.wave_helper = @user.helpers[choice_helper.to_i]
    #puts @user.helpers[choice_helper.to_i].inspect
    return true
  end

  def fighting
    #puts @floor.get_enter_url(@user, choice_floor, (choice_team.to_i - 1), @user.helpers[choice_helper.to_i])
    page = @web.get("#{@tos_url}#{@floor.get_enter_url(@user)}")
    #puts page.body
    res_json = JSON.parse(page.body)
    @floor.waves_data = res_json['data']

    @floor.set_complete(@user)
    #puts finish_data.inspect
    #puts acs_data.inspect
    puts "waiting complete.(#{@floor.acs_data[:e]})"
    print "[                                        ]\r["
    40.times do
      sleep (@floor.acs_data[:e]/40)
      print '#'
    end
    print "\n"
    #@floor.get_complete_url(@user, finish_data, acs_data)
    page = @web.get("#{@tos_url}#{@floor.get_complete_url(@user)}")
    #puts page.body
    res_json = JSON.parse(page.body)
    puts "友情點數：#{res_json['data']['friendpoint']}"
    puts "經驗值：#{res_json['data']['expGain']}"
    puts "金錢：#{res_json['data']['coinGain']}"
    @user.data = res_json['user']
    @user.parse_card_data(res_json['cards'])
    puts '======================================'
    @user.print_user_sc
  end
end

a = Tos.new
a.login
loop do
  next unless a.choice_floor
  a.fighting
end
