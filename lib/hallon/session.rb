# coding: utf-8
require 'singleton'
require 'timeout'
require 'thread'

module Hallon
  # The Session is fundamental for all communication with Spotify.
  # Pretty much all API calls require you to have established a session
  # with Spotify before using them.
  #
  # @see https://developer.spotify.com/en/libspotify/docs/group__session.html
  class Session < Base
    # The options Hallon used at {Session#initialize}.
    #
    # @return [Hash]
    attr_reader :options

    # The current session cache size (in megabytes).
    #
    # @note This is not provided by libspotify, and the value is only valid
    #       as long as the cache size is only adjusted through {#cache_size=}
    #       and not the Spotify FFI interface.
    #
    # @return [Integer]
    attr_reader :cache_size

    # libspotify only allows one session per process.
    include Singleton
    class << self
      undef :instance
    end

    # Session allows you to define your own callbacks.
    include Observable

    # Initializes the Spotify session. If you need to access the
    # instance at a later time, you can use {instance}.
    #
    # @see Session.instance
    # @see Session#initialize
    #
    # @param (see Session#initialize)
    # @return [Session]
    def Session.initialize(*args, &block)
      raise "Session has already been initialized" if @__instance__
      @__instance__ = new(*args, &block)
    end

    # Returns the previously initialized Session.
    #
    # @see Session.instance
    #
    # @return [Session]
    def Session.instance
      @__instance__ or raise "Session has not been initialized"
    end

    # @return [Array<Symbol>] list of available connection types.
    def self.connection_types
      Spotify.enum_type(:connection_type).symbols
    end

    # @return [Array<Symbol>] list of available connection rules
    def self.connection_rules
      Spotify.enum_type(:connection_rules).symbols
    end

    # Create a new Spotify session.
    #
    # @param [#to_s] appkey
    # @param [Hash] options
    # @option options [String] :user_agent ("Hallon") User-Agent to use (length < 256)
    # @option options [String] :settings_path ("tmp") where to save settings and user-specific cache
    # @option options [String] :cache_path ("") where to save cache files (set to "" to disable)
    # @option options [Bool]   :load_playlists (true) load playlists into RAM on startup
    # @option options [Bool]   :compress_playlists (true) compress local copies of playlists
    # @option options [Bool]   :cache_playlist_metadata (true) cache metadata for playlists locally
    # @yield allows you to define handlers for events (see {Hallon::Base#on})
    # @raise [ArgumentError] if `options[:user_agent]` is more than 256 characters long
    # @raise [Hallon::Error] if `sp_session_create` fails
    # @see http://developer.spotify.com/en/libspotify/docs/structsp__session__config.html
    def initialize(appkey, options = {}, &block)
      @options = {
        :user_agent => "Hallon",
        :settings_path => "tmp",
        :cache_path => "",
        :load_playlists => true,
        :compress_playlists => true,
        :cache_playlist_metadata => true
      }.merge(options)

      if @options[:user_agent].bytesize > 255
        raise ArgumentError, "User-agent must be less than 256 bytes long"
      end

      # Set configuration, as well as callbacks
      config  = Spotify::SessionConfig.new
      config[:api_version]   = Hallon::API_VERSION
      config.application_key = appkey
      @options.each { |(key, value)| config.send(:"#{key}=", value) }
      config[:callbacks]     = Spotify::SessionCallbacks.new(self, @sp_callbacks = {})

      # Default cache size is 0 (automatic)
      @cache_size = 0

      instance_eval(&block) if block_given?

      # You pass a pointer to the session pointer to libspotify >:)
      FFI::MemoryPointer.new(:pointer) do |p|
        Error::maybe_raise Spotify.session_create(config, p)
        @pointer = p.read_pointer
      end
    end

    # Process pending Spotify events (might fire callbacks).
    #
    # @return [Fixnum] time (in milliseconds) until it should be called again
    def process_events
      FFI::MemoryPointer.new(:int) do |p|
        Spotify.session_process_events(pointer, p)
        return p.read_int
      end
    end

    # Wait for the given callbacks to fire until the block returns true
    #
    # @note Given block will be called once instantly without parameters.
    # @note If no events happen for 0.25 seconds, the given block will be called
    #       with `:timeout` as parameter.
    # @param [Symbol, ...] *events list of events to wait for
    # @yield [Symbol, *args] name of the callback that fired, and its’ arguments
    # @return [Hash<Event, Arguments>]
    def process_events_on(*events)
      yield or protecting_handlers do
        channel = SizedQueue.new(1)
        on(*events) { |*args| channel << args }
        on(:notify_main_thread) { channel << :notify }

        loop do
          begin
            timeout = [process_events.fdiv(1000), 5].min # scope to five seconds
            params = Timeout::timeout(timeout) { channel.pop }
            redo if params == :notify
          rescue Timeout::Error
            params = :timeout
          end

          if result = yield(*params)
            return result
          end
        end
      end
    end
    alias :wait_for :process_events_on

    # Log into Spotify using the given credentials.
    #
    # @param [String] username
    # @param [String] password
    # @param [Boolean] remember_me have libspotify remember credentials for {#relogin}
    # @return [Session]
    # @see login!
    def login(username, password, remember_me = false)
      tap { Spotify.session_login(pointer, username, password, remember_me) }
    end

    # Login the remembered user (see {#login}).
    #
    # @raise [Hallon::Error] if no credentials are stored in libspotify
    # @see #relogin!
    def relogin
      Error.maybe_raise Spotify.session_relogin(pointer)
    end

    # Log in to Spotify using the given credentials.
    #
    # @note This function will not return until you’ve either logged in successfully,
    #       or until an error is raised.
    # @param (see #login)
    # @return [Session]
    # @raise [Error] if failed to log in
    # @see #login
    def login!(username, password, remember_me = false)
      login(username, password, remember_me)
      tap { wait_until_logged_in }
    end

    # Log in the remembered user.
    #
    # @note This method will not return until you’ve either logged in successfully
    #       or until an error is raised.
    # @return [Session]
    # @raise [Error] if failed to log in
    # @see #relogin
    def relogin!
      tap { relogin; wait_until_logged_in }
    end

    # Log out the current user.
    #
    # @note This method will not return until you’ve logged out successfully.
    # @return [Session]
    def logout!
      tap { logout; wait_for(:logged_out) { logged_out? } }
    end

    # Username of the user stored in libspotify-remembered credentials.
    #
    # @return [String]
    def remembered_user
      bufflen = Spotify.session_remembered_user(pointer, nil, 0)
      FFI::Buffer.alloc_out(bufflen + 1) do |b|
        Spotify.session_remembered_user(pointer, b, b.size)
        return b.get_string(0)
      end if bufflen > 0
    end

    # Remove stored login credentials in libspotify.
    #
    # @note If no credentials are stored nothing’ll happen.
    # @return [self]
    def forget_me!
      tap { Spotify.session_forget_me(pointer) }
    end

    # Logs out of Spotify. Does nothing if not logged in.
    #
    # @return [self]
    def logout
      tap { Spotify.session_logout(pointer) if logged_in? }
    end

    # Retrieve the currently logged in {User}.
    #
    # @return [User]
    def user
      user = Spotify.session_user!(pointer)
      User.new(user) unless user.null?
    end

    # Retrieve current connection status.
    #
    # @return [Symbol]
    def status
      Spotify.session_connectionstate(pointer)
    end

    # Set session cache size in megabytes.
    #
    # @param [Integer]
    # @return [Integer]
    def cache_size=(size)
      Spotify.session_set_cache_size(pointer, @cache_size = size)
    end

    # @return [String] Currently logged in users’ country.
    def country
      coded = Spotify.session_user_country(pointer)
      country = ((coded >> 8) & 0xFF).chr
      country << (coded & 0xFF).chr
    end

    # Star the given tracks.
    #
    # @example
    #   track = Hallon::Track.new("spotify:track:2LFQV2u6wXZmmySCWBkYGu")
    #   session.star(track)
    #
    # @param [Track…]
    # @return [Session]
    def star(*tracks)
      tap { tracks_starred(tracks, true) }
    end

    # Unstar the given tracks.
    #
    # @example
    #   track = Hallon::Track.new("spotify:track:2LFQV2u6wXZmmySCWBkYGu")
    #   session.unstar(track)
    #
    # @param [Track…]
    # @return [Session]
    def unstar(*tracks)
      tap { tracks_starred(tracks, false) }
    end

    # Set the connection rules for this session.
    #
    # @param [Symbol, …] connection_rules
    # @see Session.connection_rules
    def connection_rules=(connection_rules)
      rules = Array(connection_rules).reduce(0) do |mask, rule|
        mask | (Spotify.enum_value(rule) || 0)
      end

      Spotify.session_set_connection_rules(pointer, rules)
    end

    # Set the connection type for this session.
    #
    # @param [Symbol] connection_type
    # @see Session.connection_types
    def connection_type=(connection_type)
      Spotify.session_set_connection_type(pointer, connection_type)
    end

    # Remaining time left you can stay offline before needing to relogin.
    #
    # @return [Integer] offline time left in seconds
    def offline_time_left
      Spotify.offline_time_left(pointer)
    end

    # Offline synchronization status.
    #
    # @return [Hash, nil] sync status, or nil if not applicable
    # @see http://developer.spotify.com/en/libspotify/docs/structsp__offline__sync__status.html
    def offline_sync_status
      struct = Spotify::OfflineSyncStatus.new
      if Spotify.offline_sync_get_status(pointer, struct.pointer)
        Hash[struct.members.zip(struct.values)]
      end
    end

    # Number of playlists marked for offline sync.
    #
    # @return [Integer]
    def offline_playlists_count
      Spotify.offline_num_playlists(pointer)
    end

    # Number of offline tracks left to sync for offline mode.
    #
    # @return [Integer]
    def offline_tracks_to_sync
      Spotify.offline_tracks_to_sync(pointer)
    end

    # Set preferred offline bitrate.
    #
    # @example
    #   session.offline_bitrate = :'96k', true
    #
    # @param [Symbol] bitrate
    # @param [Boolean] resync (default: false)
    # @see Player.bitrates
    def offline_bitrate=(bitrate)
      bitrate, resync = Array(bitrate)
      Spotify.session_preferred_offline_bitrate(pointer, bitrate, !! resync)
    end

    # Retrieve the currently logged in users’ starred playlist.
    #
    # @note Returns nil when no user is logged in.
    # @return [Playlist, nil]
    def starred
      playlist = Spotify.session_starred_create!(pointer)
      Playlist.new(playlist) unless playlist.null?
    end

    # Retrieve the currently logged in users’ inbox playlist.
    #
    # @note Returns nil when no user is logged in.
    # @return [Playlist, nil]
    def inbox
      playlist = Spotify.session_inbox_create!(pointer)
      Playlist.new(playlist) unless playlist.null?
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

    # True if offline.
    # @see #status
    def offline?
      status == :offline
    end

    # String representation of the Session.
    #
    # @return [String]
    def to_s
      "<#{self.class.name}:0x#{object_id.to_s(16)} status=#{status} @options=#{options.inspect}>"
    end

    private
      # Set starred status of given tracks.
      #
      # @param [Array<Track>] tracks
      # @param [Boolean] starred
      def tracks_starred(tracks, starred)
        FFI::MemoryPointer.new(:pointer, tracks.size) do |ptr|
          ptr.write_array_of_pointer tracks.map(&:pointer)
          Spotify.track_set_starred(pointer, ptr, tracks.size, starred)
        end
      end

      # Waits until we’re either logged in or a failure occurs.
      #
      # @note You must call {#login} or {#relogin} before you call this method, or
      #       it will hang forever!
      # @see login!
      # @see relogin!
      def wait_until_logged_in
        # if the user does not have premium, libspotify will still fire logged_in as :ok,
        # but a few moments later it fires connection_error; waiting for both and checking
        # for errors on both hopefully circumvents this!
        wait_for(:logged_in, :connection_error) do |_, error|
          Error.maybe_raise(error)
          session.logged_in?
        end
      end
  end
end
