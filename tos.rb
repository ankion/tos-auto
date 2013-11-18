# -*- encoding : utf-8 -*-
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
    @auto_repeat = false
    @auto_sell = Settings['auto_sell'] || false
    @target_cards = Settings['target_cards'].split(',') || []
    @auto_merge = Settings['auto_merge'] || false
    @source_cards = Settings['source_cards'].split(',') || []
    @last_zone = nil
  end

  def login
    puts '登入遊戲中.....'
    page = @web.get("#{@tos_url}#{@user.get_login_url}")
    #uri = URI("#{@tos_url}#{@user.get_login_url}")
    #res = Net::HTTP.get_response(uri)
    puts '登入成功'
    res_json = JSON.parse(page.body)
    exit get_error(res_json) if res_json['respond'].to_i != 1
    puts '取得資料'
    @user.data = res_json['user']
    @user.bookmarks = res_json['user']['bookmarks']
    @user.parse_card_data(res_json['cards'])
    @floor.parse_floor_data(res_json['data'])
    @user.monster.parse_data(res_json['data']['monsters'])
    puts '======================================'
    @user.print_user_sc
    #puts @user.cards['10'].inspect
    #@user.print_teams
    @user.print_teams
    auto_team = @user.auto_get_team
    print 'Choice team?'
    print "[#{auto_team}]" if auto_team
    choice_team = gets.chomp
    exit if choice_team == 'q'
    choice_team = auto_team if auto_team and choice_team == ''
    @floor.wave_team = choice_team.to_i - 1
    @floor.wave_team_data = @user.data["team#{@floor.wave_team}Array"].split(',')
    print 'Auto replay the same floor?(y/N)'
    choice_auto_repeat = gets.chomp
    @auto_repeat = true if choice_auto_repeat == 'y'
  end

  def choice_floor
    puts 'Zone list'
    @floor.zones.each do |index, z|
      if z[:requireFloor]
        next unless (@user.data['completedFloorIds'].include? z[:requireFloor].to_i)
      end
      puts "#{index} #{z[:name]}"
    end
    print 'Choice zone?(b:back,q:quit)'
    print "[#{@last_zone}]" if @last_zone
    choice_zone = gets.chomp
    exit if choice_zone == 'q'
    return false if choice_zone == 'b'
    choice_zone = @last_zone if @last_zone and choice_zone == ''
    @last_zone = choice_zone

    puts "Stage list"
    last_stage = nil
    stages = @floor.stages.select {|k| k[:zone] == choice_zone}
    stages.each do |s|
      next if @floor.one_time_stage? s[:id]
      break unless @user.stage_can_enter? s[:id]
      unless s[:start_at] == ''
        next if Time.now.to_i < Time.at(s[:start_at].to_i).to_i
        next if Time.now.to_i > Time.at(s[:end_at].to_i).to_i
      end
      print "#{s[:id]} #{s[:name]}"
      print "(completed)" if (@user.data['completedStageIds'].include? s[:id].to_i)
      print " #{Time.at(s[:start_at].to_i).strftime('%m/%d %H:%M')} ~ #{Time.at(s[:end_at].to_i).strftime('%m/%d %H:%M')}" unless s[:start_at] == ''
      print "\n"
      if choice_zone.to_i < 7
        last_stage = s[:id]
        break unless (@user.data['completedStageIds'].include? s[:id].to_i)
      end
    end
    print 'Choice stage?(b:back,q:quit)'
    print "[#{last_stage}]" if last_stage
    choice_stage = gets.chomp
    exit if choice_stage == 'q'
    return false if choice_stage == 'b'
    choice_stage = last_stage if last_stage and choice_stage == ''

    puts "Floor list"
    last_floor = nil
    floors = @floor.floors.select {|k| k[:stage] == choice_stage}
    floors.each do |f|
      puts "#{f[:id]} #{f[:name]} #{f[:stamina]} #{((@user.data['completedFloorIds'].include? f[:id].to_i) ? '(completed)' : '')}"
      last_floor = f[:id]
      break unless (@user.data['completedFloorIds'].include? f[:id].to_i)
    end
    print 'Choice floor?(b:back,q:quit)'
    print "[#{last_floor}]" if last_floor
    choice_floor = gets.chomp
    exit if choice_floor == 'q'
    return false if choice_floor == 'b'
    choice_floor = last_floor if last_floor and choice_floor == ''
    @floor.wave_floor = choice_floor
    return true
  end

  def get_helper_list
    if @user.cards_full?
      puts 'Cards is full.'
      exit
    end
    puts '取得隊友名單'
    page = @web.get("#{@tos_url}#{@floor.get_helpers_url(@user)}")
    #uri = URI("#{@tos_url}#{@floor.get_helpers_url(@user, 16)}")
    #res = Net::HTTP.get_response(uri)
    res_json = JSON.parse(page.body)
    return get_error(res_json) if res_json['respond'].to_i != 1
    helpers = res_json['data']['helperList']
    #puts helpers.inspect
    @user.parse_helpers_data(helpers)
    @user.print_helpers
    if @auto_repeat
      choice_helper = (1 + rand(3)).to_s
      @floor.wave_helper = @user.helpers[choice_helper.to_i]
      puts "Auto choice helper?#{choice_helper}"
      return false
    end
    print 'Choice helper?(b:back,q:quit)'
    print "[auto]"
    choice_helper = gets.chomp
    exit if choice_helper == 'q'
    return true if choice_helper == 'b'
    choice_helper = (1 + rand(3)).to_s if choice_helper == ''
    @floor.wave_helper = @user.helpers[choice_helper.to_i]
    #puts @user.helpers[choice_helper.to_i].inspect
    return false
  end

  def fighting
    #puts @floor.get_enter_url(@user, choice_floor, (choice_team.to_i - 1), @user.helpers[choice_helper.to_i])
    page = @web.get("#{@tos_url}#{@floor.get_enter_url(@user)}")
    #puts page.body
    res_json = JSON.parse(page.body)
    return get_error(res_json) if res_json['respond'].to_i != 1
    @floor.waves_data = res_json['data']

    @floor.set_complete(@user)
    #puts finish_data.inspect
    #puts acs_data.inspect
    @floor.acs_data[:e] = 10.0 if @floor.wave_fail and not @floor.one_time_floor?
    puts "waiting complete.(#{@floor.acs_data[:e]})"
    print "[                                        ]\r["
    40.times do
      sleep (@floor.acs_data[:e]/40)
      print '#'
    end
    print "\n"

    res_json = nil
    if @floor.wave_fail and not @floor.one_time_floor?
      page = @web.get("#{@tos_url}#{@floor.get_fail_url(@user)}")
      res_json = JSON.parse(page.body)
      return get_error(res_json) if res_json['respond'].to_i != 1
      @user.data['currentStamina'] = res_json['user']['currentStamina']
    else
      #@floor.get_complete_url(@user, finish_data, acs_data)
      page = @web.get("#{@tos_url}#{@floor.get_complete_url(@user)}")
      #puts page.body
      res_json = JSON.parse(page.body)
      return get_error(res_json) if res_json['respond'].to_i != 1
      puts "友情點數：#{res_json['data']['friendpoint']}"
      puts "經驗值：#{res_json['data']['expGain']}"
      puts "金錢：#{res_json['data']['coinGain']}"
      @user.parse_card_data(res_json['cards'])
      @user.data = res_json['user']
      @user.loots = res_json['data']['loots']
      @user.print_loots

      if @auto_merge
        puts "Mergeing cards"
        @source_cards.each do |s|
          sourceCardId = @user.get_source_card s
          #puts "sourceCardId:#{sourceCardId}"
          next unless sourceCardId
          loop do
            targetCardIds = @user.get_merge_card(sourceCardId, @target_cards)
            break if targetCardIds.length == 0
            puts "#{sourceCardId} lv#{@user.cards[sourceCardId][:level]} #{@user.monster.data[s][:monsterName]} <= (#{targetCardIds.join(',')})"
            page = @web.get("#{@tos_url}#{@user.get_merge_url(sourceCardId, targetCardIds)}")
          end
          res_json = JSON.parse(page.body)
          break get_error(res_json) if res_json['respond'].to_i != 1
          @user.parse_card_data(res_json['cards'])
          @user.data['coin'] = res_json['user']['coin']
          @user.data['totalCards'] = res_json['user']['totalCards']
        end
      end

      if @auto_sell
        loop do
          targetCardIds = @user.get_sell_card(@target_cards)
          break if targetCardIds.length == 0
          puts "Selling cards(#{targetCardIds.join(',')})"
          page = @web.get("#{@tos_url}#{@user.get_sell_url(targetCardIds)}")
          res_json = JSON.parse(page.body)
          break get_error(res_json) if res_json['respond'].to_i != 1
          @user.parse_card_data(res_json['cards'])
          @user.data['coin'] = res_json['user']['coin']
          @user.data['totalCards'] = res_json['user']['totalCards']
        end
      end
    end
    puts '======================================'
    @user.print_user_sc
    if @auto_repeat
      print "Auto play again start at 5 sec."
      5.times do
        sleep 1.0
        print '.'
      end
      print "\n"
      return false
    end
    print 'Play again?(y/N)'
    return false if gets.chomp == 'y'
    return true
  end

  def get_error(data)
    puts data['errorMessage']
    true
  end
end

a = Tos.new
a.login
loop do
  next unless a.choice_floor
  loop do
    break if a.get_helper_list
    break if a.fighting
  end
end
