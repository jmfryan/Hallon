module Hallon
  # Albums are non-detailed metadata about actual music albums.
  #
  # To retrieve copyrights, album review and tracks you need to browse
  # the album, which is not currently supported by Hallon. You can retrieve
  # the {#pointer} use the raw Spotify API on it, however.
  #
  # @note All metadata methods require the album to be {Album#loaded?}
  #
  # @see http://developer.spotify.com/en/libspotify/docs/group__album.html
  class Album < Base
    def self.types
      Spotify.enum_type(:albumtype).to_hash
    end

    extend Linkable

    from_link :as_album
    to_link   :from_album

    # Construct an Album from a link.
    #
    # @param [String, Link, FFI::Pointer] link
    def initialize(link)
      @pointer = Spotify::Pointer.new from_link(link), :album, true
    end

    # Name of album.
    #
    # @return [String]
    def name
      Spotify.album_name(@pointer)
    end

    # Release year of album.
    #
    # @return [Integer]
    def year
      Spotify.album_year(@pointer)
    end

    # Retrieve album type.
    #
    # @return [Symbol] one of {Album.types}
    def type
      Spotify.album_type(@pointer)
    end

    # True if the album is available from the current session.
    #
    # @return [Boolean]
    def available?
      Spotify.album_is_available(@pointer)
    end

    # True if album has been loaded.
    #
    # @return [Boolean]
    def loaded?
      Spotify.album_is_loaded(@pointer)
    end

    # Not yet implemented.
    def cover
      return if (ptr = Spotify.album_cover(@pointer)).null?
      raise NotImplementedError
    end

    # Not yet implemented.
    def artist
      return if (ptr = Spotify.album_artist(@pointer)).null?
      raise NotImplementedError
    end
  end
end
