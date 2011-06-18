RSpec.configure do
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
end

shared_examples_for "existing session" do
  before(:all) { @session = session }
end

shared_examples_for "logged in" do
  # Tag this entire example group as an online-spec
  metadata[:logged_in] = true

  before(:all) do
    unless session.logged_in?
      session.login ENV['HALLON_USERNAME'], ENV['HALLON_PASSWORD']
      session.process_events_on(:logged_in) { session.logged_in? }
    end

    session.should be_logged_in
  end

  before(:each) { session.should be_logged_in }
end
