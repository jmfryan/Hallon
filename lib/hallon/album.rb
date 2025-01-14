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
    # An array of different kinds of albums. Singles, compilations etc.
    def self.types
      Spotify.enum_type(:albumtype).symbols
    end

    extend Linkable

    from_link :as_album
    to_link   :from_album

    # Construct an Album from a link.
    #
    # @param [String, Link, Spotify::Pointer] link
    def initialize(link)
      @pointer = to_pointer(link, :album)
    end

    # Name of album.
    #
    # @return [String]
    def name
      Spotify.album_name(pointer)
    end

    # Release year of album.
    #
    # @return [Integer]
    def year
      Spotify.album_year(pointer)
    end

    # Retrieve album type.
    #
    # @return [Symbol] one of {Album.types}
    def type
      Spotify.album_type(pointer)
    end

    # True if the album is available from the current session.
    #
    # @return [Boolean]
    def available?
      Spotify.album_is_available(pointer)
    end

    # True if album has been loaded.
    #
    # @return [Boolean]
    def loaded?
      Spotify.album_is_loaded(pointer)
    end

    # Retrieve album cover art.
    #
    # @param [Boolean] as_image true if you want it as an Image
    # @return [Image, Link, nil] album cover, or the link to it, or nil
    def cover(as_image = true)
      if as_image
        image_id = Spotify.album_cover(pointer)
        Image.new(image_id.read_string(20)) unless image_id.null?
      else
        link = Spotify.link_create_from_album_cover!(pointer)
        Link.new(link)
      end
    end

    # Retrieve the album Artist.
    #
    # @return [Artist, nil]
    def artist
      artist = Spotify.album_artist!(pointer)
      Artist.new(artist) unless artist.null?
    end

    # Retrieve an AlbumBrowse object for this Album.
    #
    # @return [AlbumBrowse]
    def browse
      AlbumBrowse.new(pointer)
    end
  end
end
