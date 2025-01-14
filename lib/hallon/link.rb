# coding: utf-8
module Hallon
  # Wraps Spotify URIs in a class, giving access to methods performable on them.
  #
  # @see http://developer.spotify.com/en/libspotify/docs/group__link.html
  class Link < Base
    # True if the given Spotify URI is valid (parsable by libspotify).
    #
    # @param [#to_s] spotify_uri
    # @return [Boolean]
    def self.valid?(spotify_uri)
      if spotify_uri.is_a?(Link)
        return true
      end

      link = Spotify.link_create_from_string!(spotify_uri.to_s)
      not link.null?
    end

    # Parse the given Spotify URI into a Link.
    #
    # @note Unless you have a {Session} initialized, this will segfault!
    # @param [#to_str] uri
    # @raise [ArgumentError] link could not be parsed
    def initialize(uri)
      @pointer = to_pointer(uri, :link) do
        Spotify.link_create_from_string!(uri.to_str)
      end
    end

    # Link type as a symbol.
    #
    # @return [Symbol]
    def type
      Spotify.link_type(pointer)
    end

    # Spotify URI length.
    #
    # @return [Fixnum]
    def length
      Spotify.link_as_string(pointer, nil, 0)
    end

    # Get the Spotify URI this Link represents.
    #
    # @see #length
    # @param [Fixnum] length truncate to this size
    # @return [String]
    def to_str(length = length)
      FFI::Buffer.alloc_out(length + 1) do |b|
        Spotify.link_as_string(pointer, b, b.size)
        return b.get_string(0)
      end
    end

    # Retrieve the full Spotify HTTP URL for this Link.
    #
    # @return [String]
    def to_url
      "http://open.spotify.com/%s" % to_str[8..-1].gsub(':', '/')
    end

    # True if this link equals `other.to_str`
    #
    # @param [#to_str] other
    # @return [Boolean]
    def ==(other)
      return super unless other.respond_to?(:to_str)
      to_str == other.to_str
    end

    # String representation of the given Link.
    #
    # @return [String]
    def to_s
      "<#{self.class.name} #{to_str}>"
    end

    # Retrieve the underlying pointer. Used by {Linkable}.
    #
    # @param [Symbol] expected_type if given, makes sure the link is of this type
    # @return [FFI::Pointer]
    # @raise ArgumentError if `type` is given and does not match link {#type}
    def pointer(expected_type = nil)
      unless type == expected_type or (expected_type == :playlist and type == :starred)
        raise ArgumentError, "expected #{expected_type} link, but it is of type #{type}"
      end if expected_type
      super()
    end
  end
end
