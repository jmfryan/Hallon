# coding: utf-8
require 'singleton'

module Hallon
  class Session < Base
    # The options Hallon used at {Session#initialize}.
    # 
    # @see Session#merge_defaults
    # @return [Hash]
    attr_reader :options
    
    # Application key used at {Session#initialize}
    #
    # @return [String]
    attr_reader :appkey
    
    # libspotify only allows one session per process.
    include Singleton
    
    # Allows you to create a Spotify session. Subsequent calls to this method
    # will return the previous instance, ignoring any passed arguments.
    #
    # @param (see Session#initialize)
    # @see Session#initialize
    # @return [Session]
    def Session.instance(*args, &block)
      @__instance__ ||= new(*args, &block)
    end
    
    # True if currently logged in.
    # @see #status
    def logged_in?
      status == :logged_in
    end
    
    # True if logged out.
    # @see #status
    def logged_out?
      status == :logged_out
    end
    
    # True if session has been disconnected.
    # @see #status
    def disconnected?
      status == :disconnected
    end
    
    # Executed on #notify_main_thread callback from libspotify
    def on_process_events
      process_events
    end
    
    private
      # Merge the given hash with default options for Session#initialize
      #
      # @note This is called automatically by Session#initialize.
      # @return [Hash]
      def merge_defaults(options)
        options = options || {}        
        {
          :user_agent => "Hallon",
          :settings_path => "tmp",
          :cache_path => "",
          
          :load_playlists => true,
          :compress_playlists => true,
          :cache_playlist_metadata => true
        }.merge(options)
      end
  end
end