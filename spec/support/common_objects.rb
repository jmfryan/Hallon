# coding: utf-8
require 'time'

RSpec::Core::ExampleGroup.instance_eval do
  let(:mock_artist) { Spotify.mock_artist("Jem", true) }
  let(:mock_artist_two) { Spotify.mock_artist("Maroon 5", true) }

  let(:mock_album)  { Spotify.mock_album("Finally Woken", mock_artist, 2004, "DEADBEEFDEADBEEFDEAD", :single, true, true) }
  let(:mock_user)   { Spotify.mock_user("burgestrand", "Burgestrand", true) }
  let(:mock_image)  { Spotify.mock_image(mock_image_id, :jpeg, File.size(fixture_image_path), File.read(fixture_image_path), :ok) }

  let(:mock_track) do
    artists = pointer_array_with(mock_artist, mock_artist_two)
    Spotify.mock_track("They", artists.length, artists, mock_album, 123_456, 42, 2, 7, 0, true, :available, false, true, true)
  end

  let(:mock_track_two) do
    artists = pointer_array_with(mock_artist)
    Spotify.mock_track("Amazing", artists.length, artists, mock_album, 123_456, 42, 2, 7, 0, true, :available, false, true, true)
  end

  let(:mock_albumbrowse) do
    copyrights = %w[Kim Elin].map { |x| FFI::MemoryPointer.from_string(x) }
    copyrights = pointer_array_with(*copyrights)
    tracks     = pointer_array_with(mock_track, mock_track_two)
    review     = "This album is AWESOME"
    Spotify.mock_albumbrowse(:ok, mock_album, mock_artist, 2, copyrights, 2, tracks, review, nil, nil)
  end

  let(:mock_artistbrowse) do
    mock_image_pointer = FFI::MemoryPointer.from_string(mock_image_id)
    similar_artists    = pointer_array_with(mock_artist, mock_artist_two)
    portraits = pointer_array_with(mock_image_pointer, mock_image_pointer)
    tracks    = pointer_array_with(mock_track, mock_track_two)
    albums    = pointer_array_with(mock_album)

    Spotify.mock_artistbrowse(:ok, mock_artist, portraits.length, portraits, tracks.length, tracks, albums.length, albums, similar_artists.length, similar_artists, "grew up in DA BLOCK", :full, nil, nil)
  end

  let(:mock_toplistbrowse) do
    artists = pointer_array_with(mock_artist, mock_artist_two)
    albums  = pointer_array_with(mock_album)
    tracks  = pointer_array_with(mock_track, mock_track_two)
    Spotify.mock_toplistbrowse(:ok, artists.length, artists, albums.length, albums, tracks.length, tracks)
  end

  let(:mock_search) do
    artists = pointer_array_with(mock_artist, mock_artist_two)
    albums  = pointer_array_with(mock_album)
    tracks  = pointer_array_with(mock_track, mock_track_two)

    Spotify.mock_search(:ok, "my query", "another thing", 1337, tracks.length, tracks, 42, albums.length, albums, 81104, artists.length, artists, nil, nil)
  end

  let(:mock_subscribers) do
    people = %w[Kim Elin Ylva]
    people.map! { |x| FFI::MemoryPointer.from_string(x) }

    subscribers = FFI::MemoryPointer.new(:pointer, people.size)
    subscribers.write_array_of_pointer people

    Spotify.mock_subscribers(people.count, subscribers)
  end

  let(:mock_playlist) do
    num_tracks = 4
    tracks_ptr = FFI::MemoryPointer.new(Spotify::Mock::PlaylistTrack, num_tracks)
    tracks = num_tracks.times.map do |i|
      Spotify::Mock::PlaylistTrack.new(tracks_ptr + Spotify::Mock::PlaylistTrack.size * i)
    end

    tracks[0][:track] = mock_track
    tracks[0][:create_time] = Time.parse("2009-11-04").to_i
    tracks[0][:creator] = mock_user
    tracks[0][:message] = FFI::MemoryPointer.from_string("message this, YO!")
    tracks[0][:seen] = true

    tracks[1][:track] = mock_track_two
    tracks[1][:create_time] = Time.parse("2009-11-05").to_i
    tracks[1][:creator] = mock_user
    tracks[1][:message] = FFI::MemoryPointer.from_string("message this, YO!")
    tracks[1][:seen] = true

    tracks[2][:track] = mock_track
    tracks[2][:create_time] = Time.parse("2009-11-06").to_i
    tracks[2][:creator] = mock_user
    tracks[2][:message] = FFI::MemoryPointer.from_string("message this, YO!")
    tracks[2][:seen] = true

    tracks[3][:track] = mock_track_two
    tracks[3][:create_time] = Time.parse("2009-11-07").to_i
    tracks[3][:creator] = mock_user
    tracks[3][:message] = FFI::MemoryPointer.from_string("message this, YO!")
    tracks[3][:seen] = true

    Spotify.mock_playlist("Megaplaylist", true, mock_user, true, "Playlist description...?", mock_image_id, false, 1000, mock_subscribers, true, :no, 67, num_tracks, tracks_ptr)
  end

  let(:mock_image_hex) { "3ad93423add99766e02d563605c6e76ed2b0e450" }
  let(:mock_image_id)  { ":\xD94#\xAD\xD9\x97f\xE0-V6\x05\xC6\xE7n\xD2\xB0\xE4P".force_encoding("BINARY") }
  let(:null_pointer)   { FFI::Pointer.new(0) }

  let(:mock_offline_sync_status) do
    sync = Spotify::OfflineSyncStatus.new
    mock_offline_sync_status_hash.each_pair do |key, value|
      sync[key] = value
    end
    sync
  end

  let(:mock_offline_sync_status_hash) do
    {
      :queued_tracks => 1,
      :queued_bytes  => 2,
      :done_tracks   => 3,
      :done_bytes    => 4,
      :copied_tracks => 5,
      :copied_bytes  => 6,
      :error_tracks  => 8,
      :syncing       => false,
      :willnotcopy_tracks => 7
    }
  end

  let(:mock_session_object) do
    session = Hallon::Session.send(:allocate)
    sstatus = mock_offline_sync_status
    inbox   = mock_playlist
    session.instance_eval do
      @pointer = Spotify.mock_session(nil, :undefined, 60 * 60 * 24 * 30, sstatus, 7, 3, inbox)
    end
    session
  end

  let(:mock_image_link) do
    Spotify.link_create_from_string!("spotify:image:3ad93423add99766e02d563605c6e76ed2b0e450")
  end

  let(:mock_image_link_two) do
    Spotify.link_create_from_string!("spotify:image:ce9da340323614dc95ae96b68843b1c726dc5c8a")
  end
end

RSpec::Core::ExampleGroup.new.instance_eval do
  Spotify.registry_add "spotify:image:3ad93423add99766e02d563605c6e76ed2b0e450", mock_image
  Spotify.registry_add 'spotify:artist:3bftcFwl4vqRNNORRsqm1G', mock_artist
  Spotify.registry_add 'spotify:album:1xvnWMz2PNFf7mXOSRuLws', mock_album
  Spotify.registry_add 'spotify:track:7N2Vc8u56VGA4KUrGbikC2', mock_track
  Spotify.registry_add 'spotify:user:burgestrand', mock_user
  Spotify.registry_add 'spotify:user:burgestrand:playlist:07AX9IY9Hqmj1RqltcG0fi', mock_playlist
  Spotify.registry_add 'spotify:user:burgestrand:starred', mock_playlist
end
