require "addressable/uri"
require './checksum'

class Floor
  attr_accessor :zones, :stages, :floors

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
  end

  def parse_floor_data(data)
    data['stageList'].each do |s|
      stage = s.split('|')
      @stages << {:id => stage[0], :zone => stage[3], :name => stage[9]}
    end
    data['floorList'].each do |f|
      floor = f.split('|')
      @floors << {:id => floor[0], :stage => floor[1], :name => floor[7]}
    end
  end

  def get_helpers_url(user, floorId)
    encypt = Checksum.new
    post_data = {
      :floorId => floorId,
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

  def get_enter_url(user, floorId, team, helper)
    encypt = Checksum.new
    post_data = {
      :floorId => floorId,
      :team => team,
      :helperUid => helper[:uid],
      :clientHelperCard => helper[:clientHelperCard],
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

  def get_complete_url(user, post, acs)
    encypt = Checksum.new
    post[:uid] = user.data['uid']
    post[:session] = user.data['session']
    post[:language] = user.post_data[:language]
    post[:platform] = user.post_data[:platform]
    post[:version] = user.post_data[:version]
    post[:timestamp] = Time.now.to_i
    post[:timezone] = user.post_data[:timezone]
    post[:nData] = encypt.getNData

    acs_uri = Addressable::URI.new
    acs_uri.query_values = acs
    acs_url = acs_uri.query
    acs_url = "#{acs_url}&acsh=#{encypt.getHash(acs_url, '')}"
    #puts acs_url

    uri = Addressable::URI.new
    uri.query_values = post
    url = "/api/floor/complete?#{uri.query}&#{acs_url}"
    #puts url
    return "#{url}&hash=#{encypt.getHash(url, '')}"
  end
end
