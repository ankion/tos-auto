# -*- encoding : utf-8 -*-
require 'digest/md5'
require './setting'

class Checksum
  def key
    Settings['tos_key']
  end

  def getHash(input, salt = '')
    str = "#{key}#{salt}"
    str2 = Digest::MD5.hexdigest(input)[8..11]
    return Digest::MD5.hexdigest("#{str2}#{str}")
  end

  def getNData
    first_rand_number = rand(16)
    second_rand_number = rand(16) + first_rand_number - 1
    return Digest::MD5.hexdigest(key[first_rand_number..second_rand_number])
  end
end
