require "addressable/uri"
require "./api"
require "./checksum"
require "./setting"
require "mechanize"

class TosHttp
  def initialize(user_data)
    file_name = "log/logfile.log.#{ARGV[0] ? ARGV[0] : 'defaults'}"
    dir = File.dirname(file_name)
    FileUtils.mkdir_p(dir) unless File.directory?(dir)
    File.delete(file_name) if File.exists? file_name
    @logger = Logger.new(file_name)
    @base_url = Settings['tos_url']
    @web = Mechanize.new { |agent|
      agent.follow_meta_refresh = true
    }
    @user_data = user_data
    @base_get_data = {
      'language' => 'zh_TW',
      'platform' => Settings['platform'],
      'version' => Settings['tos_version'],
      'timezone' => '8',
    }
    @base_post_data = {
      'attempt' => '1',
      'tvalid' => 'FALSE'
    }
    @encypt = Checksum.new
  end

  def init_base_get_data
    @base_get_data['timestamp'] = Time.now.to_i
    @base_get_data['nData'] = @encypt.getNData
    @base_get_data['uid'] = @user_data['uid'] if @user_data['uid']
    @base_get_data['session'] = @user_data['session'] if @user_data['session']
  end

  def init_base_post_data(full_url)
    @base_post_data["frags"] = @encypt.getHash('frags', full_url)
    @base_post_data["ness"] = @encypt.getHash('ness', full_url)
    @base_post_data["afe"] = @encypt.getHash('afe', full_url)
  end

  def post(api, get_data = {}, post_data = {})
    show_wait_spinner{
      res_json = nil
      loop do
        uri = Addressable::URI.new
        self.init_base_get_data
        salt = ''
        if api.include? 'user/login' or api.include? 'user/register'
          get_data['olv'] = @encypt.getHash('olv', @base_get_data['timestamp'], '00')
          salt = get_data['deviceKey']
        else
          get_data['olv'] = @encypt.getHash('olv', @base_get_data['timestamp'], "#{@user_data['level']}#{@user_data['exp']}")
          salt = "#{@base_get_data['uid']}#{@base_get_data['session']}"
        end
        get_data = @base_get_data.merge get_data
        uri.query_values = get_data
        api_url = "#{api}?#{uri.query}"
        api_url = "#{api_url}&hash=#{@encypt.getHash('base', api_url, salt)}"
        full_url = "#{@base_url}#{api_url}"

        self.init_base_post_data(full_url)
        post_data = @base_post_data.merge post_data

        page = @web.post(full_url, post_data)
        @logger.info page.body
        res_json = JSON.parse(page.body)
        break if res_json['respond'].to_i == 1
        puts res_json.inspect
        if res_json['respond'].to_i == 6 or res_json['respond'].to_i == 3
          #puts res_json['respond']['errorMessage']
          exit unless res_json['errorMessage'].include? 'Not enougth stamina'
          wait_time = res_json['wait'] ? res_json['wait'].to_i : 600
          print_wait(wait_time,false)
          next
        end
        exit
      end
      res_json
    }
  end
end
