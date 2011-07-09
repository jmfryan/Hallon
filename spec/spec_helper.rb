# coding: utf-8
require 'hallon'

# Bail on failure
Thread.abort_on_exception = true

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true

  def options
    {
      :user_agent => "Hallon (rspec)",
      :settings_path => "tmp",
      :cache_path => "tmp/cache"
    }
  end

  def session
    @session ||= Hallon::Session.instance(Hallon::APPKEY, options)
  end

  def fixture_image_path
    File.expand_path('../fixtures/pink_cover.jpg', __FILE__)
  end
end

# Requires supporting files in ./support/ and ./fixtures/
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}
Dir["#{File.dirname(__FILE__)}/fixtures/**/*.rb"].each {|f| require f}

unless ENV.values_at(*%w(HALLON_APPKEY HALLON_USERNAME HALLON_PASSWORD)).all?
  abort <<-ERROR
    You must supply a valid Spotify username, password and application
    key in order to run Hallons specs. This is done by setting these
    environment variables:

    - HALLON_APPKEY (path to spotify_appkey.key)
    - HALLON_USERNAME (your spotify username)
    - HALLON_PASSWORD (your spotify password)
  ERROR
end

module Hallon
  APPKEY ||= IO.read File.expand_path(ENV['HALLON_APPKEY'])
end

# Hallon::Session#instance requires that a Session object have not been created
# so test it here instead. This assures it is tested before anything else!
describe Hallon::Session do
  it { Hallon::Session.should_not respond_to :new }

  describe "#instance" do
    it "should require an application key" do
      expect { Hallon::Session.instance }.to raise_error(ArgumentError)
    end

    it "should fail on an invalid application key" do
      expect { Hallon::Session.instance('invalid') }.to raise_error(Hallon::Error, /BAD_APPLICATION_KEY/)
    end

    it "should fail on a small user-agent of multibyte chars (> 255 characters)" do
      expect { Hallon::Session.send(:new, Hallon::APPKEY, :user_agent => 'ö' * 128) }.
        to raise_error(ArgumentError)
    end

    it "should fail on a huge user agent (> 255 characters)" do
      expect { Hallon::Session.send(:new, Hallon::APPKEY, :user_agent => 'a' * 256) }.
        to raise_error(ArgumentError)
    end
  end
end
