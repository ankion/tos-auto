# -*- encoding : utf-8 -*-
require "addressable/uri"
require './setting'
require "./checksum"

## override String #######################################
class String
  def color(color,str=self)
    return str if Settings['no_color']
    colors = {
      'black'         => "\033[30m%s\033[0m",
      'red'           => "\033[31m%s\033[0m",  #紅
      'green'         => "\033[32m%s\033[0m",  #綠
      'yellow'        => "\033[33m%s\033[0m",  #黃
      'gold'          => "\033[1;33m%s\033[22;0m",  #金
      'blue'          => "\033[34m%s\033[0m",  #藍
      'pink'          => "\033[35m%s\033[0m",  #粉紅
      'cyan'          => "\033[36m%s\033[0m",  #青
      'gray'          => "\033[37m%s\033[0m",  #灰
      'bg_black'      => "\033[40m%s\033[0m",
      'bg_red'        => "\033[41m%s\033[0m",
      'bg_green'      => "\033[42m%s\033[0m",
      'bg_yellow'     => "\033[43m%s\033[0m",
      'bg_blue'       => "\033[44m%s\033[0m",
      'bg_pink'       => "\033[45m%s\033[0m",
      'bg_cyan'       => "\033[46m%s\033[0m",
      'bg_gray'       => "\033[47m%s\033[0m",
      'bold'          => "\033[1m%s\033[22m",  #高亮
      'reverse_color' => "\033[7m%s\033[27m"   #反白
    }
    #puts "colorStr(#{color} ,#{str}) : "
    str = colors[color.to_s] %str if colors[color.to_s]
    return str
  end
  def black;          color(__method__) end
  def red;            color(__method__) end
  def green;          color(__method__) end
  def yellow;         color(__method__) end
  def gold;           color(__method__) end
  def blue;           color(__method__) end
  def pink;           color(__method__) end
  def cyan;           color(__method__) end
  def gray;           color(__method__) end
  def bg_black;       color(__method__) end
  def bg_red;         color(__method__) end
  def bg_green;       color(__method__) end
  def bg_yellow;      color(__method__) end
  def bg_blue;        color(__method__) end
  def bg_pink;        color(__method__) end
  def bg_cyan;        color(__method__) end
  def bg_gray;        color(__method__) end
  def bold;           color(__method__) end
  def reverse_color;  color(__method__) end
end

## Set Time Zone #######################################
tz_name = 'Asia/Taipei'
prev_tz = ENV['TZ']
begin
  ENV['TZ'] = tz_name
rescue
  ENV['TZ'] = prev_tz
end
#########################################
def print_wait(times)
  chars = %w{ | / - \\ }
  count = times
  str_length = "#{count}".size
  (times * 10).times do
    print "#{Integer(count)}".rjust(str_length).bold.blue
    print chars[0].to_s.bold.yellow
    sleep 0.1
    count-=0.1
    print "\b" * (str_length+1)
    chars.push chars.shift
  end
end
#########################################
def puts_wait(times)
  print_wait(times)
  print " " * ("#{times*10}".size+1)
  print "\n"
end
#########################################
def spinner(code)
  chars = %w{ | / - \\ }
  t = Thread.new { code.call }
  while t.alive?
    print chars[0]
    sleep 0.1
    print "\b"
    chars.push chars.shift
  end
  t.join
end
=begin show_wait_spinner ##################
show_wait_spinner{
  # do some thing
  sleep rand(4)+2
}
=end   ##################
def show_wait_spinner(fps=10)
  chars = %w[| / - \\]
  delay = 1.0/fps
  iter = 0
  spinner = Thread.new do
    while iter do  # Keep spinning until told otherwise
      print chars[(iter+=1) % chars.length]
      sleep delay
      print "\b"
    end
    print " \b\07"    # beep
  end
  yield.tap{       # After yielding to the block, save the return value
    iter = false   # Tell the thread to exit, cleaning up after itself…
    spinner.join   # …and wait for it to do so.
  }                # Use the block's return value as the method's
end
#############################################
=begin
\e[D #left
\e[B
\e[D #left
\e[D #left

=end
####
#outputs color table to console, regular and bold modes
def colortable
  names = %w(black red green yellow blue pink cyan gray default)
  fgcodes = (30..39).to_a - [38]

  s = ''
  reg  = "\e[%d;%dm%s\e[0m"
  bold = "\e[1;%d;%dm%s\e[0m"
  puts '                       color table with these background codes:'
  puts '          40       41       42       43       44       45       46       47       49'
  names.zip(fgcodes).each {|name,fg|
    s = "#{fg}"
    puts "%7s "%name + "#{reg}  #{bold}   "*9 % [fg,40,s,fg,40,s,  fg,41,s,fg,41,s,  fg,42,s,fg,42,s,  fg,43,s,fg,43,s,
      fg,44,s,fg,44,s,  fg,45,s,fg,45,s,  fg,46,s,fg,46,s,  fg,47,s,fg,47,s,  fg,49,s,fg,49,s ]
  }
end
##########################################
def attribute_color(str,attribute=-1,prefix=false)
  typeList = ["★","㊌","㊋","㊍","☼","☀","06","07","08","09","10","人","獸","妖","龍","神","進","強","魔","19","20"]
  begin
  	type = typeList[attribute]
  rescue
    type = attribute.to_s
  end
  str = type + str if prefix
  case attribute
  when -1 #def
  when 0 #
  	str = str
  when 1 #water
    str = str.cyan.bold
  when 2 #fire
    str = str.red
  when 3 #wood
    str = str.green
  when 4 #light
    str = str.yellow.bold
  when 5 #dark
    str = str.blue.bold
  when 6 #以諾
    str = str.bold
  when 7 #古神遺跡
    str = str.yellow
  when 8 #旅人的記憶 12宮
    str = str.pink
#  when 11..20
#  	str = (type + str).pink.bold
  when 11 #人
    str = str
  when 12 #獸
    str = str.green
  when 13 #妖
    str = str.red
  when 14 #龍
    str = str.cyan
  when 15 #神
    str = str.yellow
  when 16 #進
    str = str.pink
  when 17 #強
    str = str.pink.bold
  when 18 #魔
    str = str.blue
  else #sp
  	str = str.bold
  end
  return str
end
## each time to string refresh timestamp & hash ###########
class TosUrl
  attr_reader :path, :data, :acs_path, :acs_data
  def initialize args
    args.each do |k,v|
      #puts "k:#{k} ,v:#{v}"
      instance_variable_set("@#{k}", v) unless v.nil?
    end
  end
  def to_s
    encypt = Checksum.new
    uri = Addressable::URI.new
    tmp = @data
    tmp[:timestamp]=Time.now.to_i
    tmp[:nData]=encypt.getNData
    uri.query_values = data
    rt = "#{@path}?#{uri.query}"
    rt = "#{rt}&hash=#{encypt.getHash(rt, '')}"
    #puts "TosUrl.to_s - #{rt}"
    return rt
  end
  def inspect
    to_s
  end
end
