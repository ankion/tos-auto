# -*- encoding : utf-8 -*-
require 'net/http'
require 'json'
require 'logger'
require 'mechanize'
require './api'
require './user'
require './monster'
require './floor'
require './setting'

class Tos
  def initialize
    file_name = "logfile.log.#{ARGV[0] ? ARGV[0] : 'defaults'}"
    File.delete(file_name) if File.exists? file_name
    @logger = Logger.new(file_name)
    @tos_url = Settings['tos_url']
    @user = User.new
    #@monster = Monster.new
    @floor = Floor.new
    @web = Mechanize.new { |agent|
      agent.follow_meta_refresh = true
    }
    @auto_repeat = false
    @auto_sell = false #Settings['auto_sell'] || false
    @sell_cards = Settings['sell_cards'] || []
    @auto_merge = Settings['auto_merge'] || false
    @merge_cards = Settings['merge_cards'] || []
    @last_zone = nil
  end

  def login
    puts '登入遊戲中.....'
    page = @web.get("#{@tos_url}#{@user.get_login_url}")
    @logger.info page.body
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
    @user.monster.parse_normal_skill(res_json['data']['normalSkills'])
    @user.monster.parse_data(res_json['data']['monsters'])
    @floor.stage_bonus = res_json['data']['stageBonus']
    puts '======================================'
    @user.print_user_sc
    print 'Auto replay the same floor?(y/N)'
    choice_auto_repeat = $stdin.gets.chomp
    exit if choice_auto_repeat == 'q'
    @auto_repeat = true if choice_auto_repeat == 'y'
    #puts @user.cards['10'].inspect
    #@user.print_teams
    @user.print_teams
    auto_team = @user.auto_get_team
    print 'Choice team?'
    print "[#{auto_team}]" if auto_team
    choice_team =  $stdin.gets.chomp
    exit if choice_team == 'q'
    choice_team = auto_team if auto_team and choice_team == ''
    @floor.wave_team = choice_team.to_i - 1
    @floor.wave_team_data = @user.data["team#{@floor.wave_team}Array"].split(',')
  end

  def choice_floor
    puts 'Zone list'
    @floor.zones.each do |index, z|
      if z[:requireFloor]
        next unless (@user.data['completedFloorIds'].include? z[:requireFloor].to_i)
      end
      puts "[%3d] %s%s" % [index,z[:name],(@floor.stage_bonus['zone'].to_i == index.to_i) ? ' (bonus)'.gold : '']
    end
    print 'Choice zone?(b:back,q:quit)'
    print "[#{@last_zone}]" if @last_zone
    choice_zone = $stdin.gets.chomp
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
      print "[%3d]" % [s[:id]]
      print ((@user.data['completedStageIds'].include? s[:id].to_i) ? 'v' : ' ').bold.green
      print s[:name]
      #print "(completed)".bold if (@user.data['completedStageIds'].include? s[:id].to_i)
      print " #{Time.at(s[:start_at].to_i).strftime('%m/%d %H:%M')} ~ #{Time.at(s[:end_at].to_i).strftime('%m/%d %H:%M')}" unless s[:start_at] == ''
      bonus = @floor.stage_bonus['stages'].select {|v| v['stageId'].to_i == s[:id].to_i }
      print " (#{@floor.bonus_type[bonus.first['bonusType'].to_i]})".gold if bonus.length > 0
      print "\n"
      if choice_zone.to_i < 7
        last_stage = s[:id]
        break unless (@user.data['completedStageIds'].include? s[:id].to_i)
      end
    end
    print 'Choice stage?(b:back,q:quit)'
    print "[#{last_stage}]" if last_stage
    choice_stage = $stdin.gets.chomp
    exit if choice_stage == 'q'
    return false if choice_stage == 'b'
    choice_stage = last_stage if last_stage and choice_stage == ''

    puts "Floor list"
    last_floor = nil
    floors = @floor.floors.select {|k| k[:stage] == choice_stage}

    #puts @floor.stage_bonus['stages']
    stage_bonus = @floor.stage_bonus['stages'].select {|v| v['stageId'].to_s == choice_stage}
    halfStamina = stage_bonus != nil && stage_bonus.length > 0
    puts stage_bonus
    halfStamina = stage_bonus.first['bonusType'].to_s == '1' if halfStamina
    floors.each do |f|
      stamina = halfStamina ? (f[:stamina].to_i/2.0).round : f[:stamina]
      puts "[%3d]%s %2d %s" % [f[:id],((@user.data['completedFloorIds'].include? f[:id].to_i) ? 'v' : ' ').bold.green,stamina,f[:name]]
      last_floor = f[:id]
      break unless (@user.data['completedFloorIds'].include? f[:id].to_i)
    end
    print 'Choice floor?(b:back,q:quit)'
    print "[#{last_floor}]" if last_floor
    choice_floor =  $stdin.gets.chomp
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
    @logger.info page.body
    #uri = URI("#{@tos_url}#{@floor.get_helpers_url(@user, 16)}")
    #res = Net::HTTP.get_response(uri)
    res_json = JSON.parse(page.body)
    return get_error(res_json) if res_json['respond'].to_i != 1
    helpers = res_json['data']['alluserList']
    #puts res_json['data']
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
    choice_helper =  $stdin.gets.chomp
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
    @logger.info page.body
    #puts page.body
    res_json = JSON.parse(page.body)
    if @auto_repeat and res_json['respond'].to_i == 3
      puts res_json['errorMessage']
      wait_secs = 60 * 10
      puts "Auto play again start at #{wait_secs} sec."
      print "[                                        ]\r["
      40.times do
        sleep (wait_secs/40)
        print '#'
      end
      print "\n"

      return false
    end
    return get_error(res_json) if res_json['respond'].to_i != 1
    @floor.waves_data = res_json['data']

    @floor.set_complete(@user)
    #puts finish_data.inspect
    #puts acs_data.inspect
    @floor.acs_data[:e] = 10.0 if @floor.wave_fail and not @floor.one_time_floor?
    puts "waiting complete.(#{@floor.acs_data[:e]})[#{Time.now.strftime("%I:%M:%S%p")} - #{(Time.now + @floor.acs_data[:e]).strftime("%I:%M:%S%p")}]"
    print "[                                        ]\r["
    40.times do
      sleep (@floor.acs_data[:e]/40)
      print '#'
    end
    print "\n"

    res_json = nil
    if @floor.wave_fail and not @floor.one_time_floor?
      page = @web.get("#{@tos_url}#{@floor.get_fail_url(@user)}")
      @logger.info page.body
      res_json = JSON.parse(page.body)
      return get_error(res_json) if res_json['respond'].to_i != 1
      @user.data['currentStamina'] = res_json['user']['currentStamina']
    else
      #@floor.get_complete_url(@user, finish_data, acs_data)
      page = @web.get("#{@tos_url}#{@floor.get_complete_url(@user)}")
      @logger.info page.body
      #puts page.body
      res_json = JSON.parse(page.body)
      return get_error(res_json) if res_json['respond'].to_i != 1
      puts "友情點數：#{res_json['data']['friendpoint']}"
      puts "經驗值  ：#{res_json['data']['expGain']}"
      puts "金錢    ：#{res_json['data']['coinGain']}"
      @user.parse_card_data(res_json['cards'])
      @user.data = res_json['user']
      @user.loots = res_json['data']['loots']
      @user.print_loots

      auto_merge_card if @auto_merge

      if @auto_sell
        loop do
          targetCardIds = @user.get_sell_card(@sell_cards)
          break if targetCardIds.length == 0
          puts "Selling cards(#{targetCardIds.join(',')})"
          page = @web.get("#{@tos_url}#{@user.get_sell_url(targetCardIds)}")
          @logger.info page.body
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
    return false if  $stdin.gets.chomp == 'y'
    return true
  end

  def auto_merge_card(debug = false)
    puts "Mergeing master cards"
    @merge_cards.each do |key, merge_card|
      merge_card['source_cards'].each do |s|
        loop do
          sourceCardId = @user.get_source_card(s, merge_card)
          #puts "sourceCardId:#{sourceCardId}"
          break unless sourceCardId
          targetCardIds = @user.get_master_merge_card(sourceCardId, merge_card)
          break if targetCardIds.length == 0
          break if targetCardIds.length < merge_card['require_target_amount_min']
          print "#{sourceCardId} lv#{@user.cards[sourceCardId][:level]} #{@user.monster.data[s.to_s][:monsterName]} <= ("
          targetCardIds.each do |t|
            card = @user.cards[t]
            print "," unless t == targetCardIds.first
            print "lv#{card[:level]} #{@user.monster.data[card[:monsterId]][:monsterName]}"
          end
          print ")\n"
          unless debug
            page = @web.get("#{@tos_url}#{@user.get_merge_url(sourceCardId, targetCardIds)}")
            @logger.info page.body
            res_json = JSON.parse(page.body)
            break get_error(res_json) if res_json['respond'].to_i != 1
            @user.parse_card_data(res_json['cards'])
            @user.data['coin'] = res_json['user']['coin']
            @user.data['totalCards'] = res_json['user']['totalCards']
          end
        end
      end
    end

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
