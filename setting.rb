# -*- encoding : utf-8 -*-
require 'settingslogic'

class Settings < Settingslogic
  source "#{File.dirname(__FILE__)}/config.yml"
  namespace 'defaults'
end
