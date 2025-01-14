# coding: utf-8
module Hallon
  # Methods shared between objects that can be created from Spotify URIs,
  # or can be turned into Spotify URIs.
  #
  # @note Linkable is not part of Hallons’ public API.
  # @private
  module Linkable
    # Defines `#from_link`, used in converting a link to a pointer.
    #
    # @overload from_link(type)
    #   Convert from a link using said method.
    #
    #   @example
    #     from_link :as_album # => Spotify.link_as_album(pointer, *args)
    #
    #   @param [Symbol] as_object link conversion method, formatted `as_type`
    #
    # @overload from_link(type) { |*args| … }
    #   Use the given block to convert the link.
    #
    #   @example
    #     from_link :profile do |pointer|
    #       Spotify.link_as_user(pointer)
    #     end
    #
    #   @param [#to_s] type link type
    #   @yield [link, *args] called when conversion is needed from Link pointer
    #   @yieldparam [Hallon::Link] link
    #   @yieldparam *args any extra arguments given to `#from_link`
    #
    # @see Link#pointer
    def from_link(as_object, &block)
      block ||= Spotify.method(:"link_#{as_object}!")
      type    = as_object.to_s[/^(as_)?([^_]+)/, 2].to_sym

      define_method(:from_link) do |link, *args|
        if link.is_a?(FFI::Pointer) and not link.is_a?(Spotify::Pointer)
          link
        else
          unless Spotify::Pointer.typechecks?(link, :link)
            link = Link.new(link).pointer(type)
          end

          instance_exec(link, *args, &block)
        end
      end
    end

    # Defines `#to_link` method, which converts the the current object to a {Link}
    #
    # @example
    #   to_link :from_artist # => Spotify.link_create_from_artist
    #
    # @param [Symbol] cmethod object kind
    # @return [Link]
    def to_link(cmethod)
      define_method(:to_link) do |*args|
        link = Spotify.__send__(:"link_create_#{cmethod}!", pointer, *args)
        Link.new(link)
      end
    end
  end
end
