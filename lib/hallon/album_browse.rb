module Hallon
  # AlbumBrowse objects are for retrieving additional data from
  # an album that cannot otherwise be acquired. This includes
  # tracks, reviews, copyright information.
  #
  # AlbumBrowse object triggers the `:load` callback on itself
  # when it loads.
  #
  # @example
  #   browse = album.browse # album is a Hallon::Album
  #   browse.on(:load) do
  #     puts "Album browser for #{browse.album.name} has been loaded!"
  #   end
  #   session.wait_for { browse.loaded? } # will eventually trigger above callback
  #
  # @see Album
  # @see http://developer.spotify.com/en/libspotify/docs/group__albumbrowse.html
  class AlbumBrowse < Base
    include Observable

    # Creates an AlbumBrowse instance from an Album or an Album pointer.
    #
    # @note Use {Album#browse} to browse an Album.
    # @param [Album, Spotify::Pointer] album
    def initialize(album)
      pointer = album
      pointer = pointer.pointer if pointer.respond_to?(:pointer)

      unless Spotify::Pointer.typechecks?(pointer, :album)
        given = pointer.respond_to?(:type) ? pointer.type : pointer.inspect
        raise TypeError, "expected album pointer, was given #{given}"
      end

      @callback = proc { trigger(:load) }
      @pointer  = Spotify.albumbrowse_create!(session.pointer, pointer, @callback, nil)
    end

    # @return [Boolean] true if the album is loaded
    def loaded?
      Spotify.albumbrowse_is_loaded(pointer)
    end

    # @see Error
    # @return [Symbol] album browser error status
    def error
      Spotify.albumbrowse_error(pointer)
    end

    # @return [String] album review
    def review
      Spotify.albumbrowse_review(pointer)
    end

    # @return [Artist, nil] artist performing this album
    def artist
      artist = Spotify.albumbrowse_artist!(pointer)
      Artist.new(artist) unless artist.null?
    end

    # @return [Album, nil] album this object is browsing
    def album
      album = Spotify.albumbrowse_album!(pointer)
      Album.new(album) unless album.null?
    end

    # @return [Enumerator<String>] list of copyright notices
    def copyrights
      size = Spotify.albumbrowse_num_copyrights(pointer)
      Enumerator.new(size) do |i|
        Spotify.albumbrowse_copyright(pointer, i)
      end
    end

    # @return [Enumerator<Track>] list of tracks
    def tracks
      size = Spotify.albumbrowse_num_tracks(pointer)
      Enumerator.new(size) do |i|
        track = Spotify.albumbrowse_track!(pointer, i)
        Track.new(track) unless track.null?
      end
    end
  end
end
