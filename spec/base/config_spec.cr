require "./spec_helper"

describe Config do

  Config::INSTANCE.configure do |conf|
    conf.environment = "production"
    conf.app_dir     = "dir"
  end
end
