# -*- encoding : utf-8 -*-
require 'net/http'
require 'json'
require 'logger'
require 'mechanize'
require 'readline'
require './api'
require './user'
require './setting'
###########################################
=begin
colortable
puts "\033[31m▇\033[0m"
puts "▇".red
puts "▇".bold.color('blue')
puts "▇".bg_red.color('yyy')
show_wait_spinner {
	#sleep rand(4)+2 
}
puts "\t"+"獎勵".bg_blue.yellow.bold+"lv%d %s"
=end

def autoLogin 
  def_data = {
    :type => 'facebook',
    #:uniqueKey => Settings['uniqueKey'],
    #:deviceKey => Settings['deviceKey'],
    :sysInfo => 'iPhone OS 5.0.1|armv7f|2|504|128|PowerVR SGX 543|FALSE|OpenGL ES 2.0 IMGSGX543-63.14.2|Restricted|FALSE|4096|4.03|5.0.1|iPhone4,1|||',
    :language => 'zh_TW',
    :platform => Settings['platform'],
    :version => '4.51',
    #:timestamp => '',
    :timezone => '8',
    :nData => ''
  }
  @web = Mechanize.new { |agent|
    agent.follow_meta_refresh = true
  }
  line_num=0
  File.open('accountlist.txt').each do |line|
  	line = line.gsub("\n","") if line != nil
    puts "#{line_num += 1} #{line}"
    #next if line_num < 5
    act = line.split('|')
    keys = {
      :uniqueKey => act != nil && act.size > 2 ? act[act.size-2] : act ,
      :deviceKey => act != nil && act.size > 2 ? act[act.size-1] : act
    }
    post_data = def_data.merge!(keys)
    #puts post_data
    @user = User.new
    show_wait_spinner{
	  res_json = user_login(post_data)
	  #puts res_json['user']
	  user_data = {
        :uid => res_json['user']['uid'],
        :session => res_json['user']['session']
      }
	  post_data = post_data.merge!(user_data)
	  puts list_reward(post_data)
    }
    puts_wait 1
  end
end

def user_login(post_data={})
	puts __method__
	url = TosUrl.new :path => "/api/user/login" ,:data => post_data
	page_post(url)
end

def list_reward(post_data={})
	url = TosUrl.new :path => "/api/user/reward/list" ,:data => post_data
	page_post(url)
end

def page_post(url)
  puts __method__
  res_json = nil
  tos_url = Settings['tos_url']
  #puts tos_url
  begin
    loop do
  	  send_url = "#{tos_url}#{url}"
  	  #puts send_url
  	  page = @web.get(send_url)
      res_json = JSON.parse(page.body)
      puts " >> ok" if res_json['respond'].to_i == 1
      break if res_json['respond'].to_i == 1
      puts res_json.inspect
      if res_json['respond'].to_i == 6 or res_json['respond'].to_i == 3
        wait_time = res_json['wait'] ? res_json['wait'].to_i : 600
        print_wait(wait_time)
        next
      end
      #exit
    end
  rescue
	retry
  end
  res_json
end

begin
  Thread.new(autoLogin)
rescue Interrupt
  puts "\nQuitting."
end