# -*- encoding : utf-8 -*-
require 'digest/md5'
require "base64"
require './setting'

class Checksum
  def key
    Settings['tos_key']
  end

  def secret
    Settings['tos_secret'] || {}
  end

  def getHash(type, input, salt = '')
    eval Base64.decode64(secret[type]) if secret[type]
  end

  def getNData
    first_rand_number = rand(16)
    second_rand_number = rand(16) + first_rand_number - 1
    return Digest::MD5.hexdigest(key[first_rand_number..second_rand_number])
  end
end
