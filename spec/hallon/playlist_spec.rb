require 'time'

describe Hallon::Playlist do
  it_should_behave_like "a Linkable object" do
    let(:spotify_uri) { "spotify:user:burgestrand:playlist:07AX9IY9Hqmj1RqltcG0fi" }
    let(:described_class) do
      real_session = session
      Hallon::Playlist.dup.tap do |klass|
        klass.class_eval do
          define_method(:session) { real_session }
        end
      end
    end
  end

  let(:playlist) { Hallon::Playlist.new(mock_playlist) }
  subject { playlist }

  it { should be_loaded }
  it { should be_collaborative }
  it { should_not be_pending }
  it { mock_session { should be_in_ram } }
  it { mock_session { should_not be_available_offline } }

  its(:name)  { should eq "Megaplaylist" }
  its(:owner) { should eq Hallon::User.new(mock_user) }
  its(:description) { should eq "Playlist description...?" }
  its(:image) { mock_session { should eq Hallon::Image.new(mock_image_id) } }
  its(:subscribers) { should eq %w[Kim Elin Ylva] }
  its(:total_subscribers) { should eq 1000 }
  its(:sync_progress) { mock_session { should eq 67 } }
  its(:size) { should eq 4 }

  its('tracks.size') { should eq 4 }
  its('tracks.to_a') { should eq instantiate(Hallon::Playlist::Track, [mock_playlist, 0], [mock_playlist, 1], [mock_playlist, 2], [mock_playlist, 3]) }
  describe "tracks#[]" do
    subject { playlist.tracks[0] }

    it { should be_seen }
    its(:create_time) { should eq Time.parse("2009-11-04") }
    its(:creator)     { should eq Hallon::User.new(mock_user) }
    its(:message)     { should eq "message this, YO!" }

    describe "seen" do
      it "should be settable" do
        track = playlist.tracks[0]
        track.should be_seen
        track.seen = false
        track.should_not be_seen
      end
    end
  end

  describe "#insert" do
    let(:tracks) { instantiate(Hallon::Track, mock_track, mock_track_two) }

    it "should add the given tracks to the playlist at correct index" do
      old_tracks = playlist.tracks.to_a
      new_tracks = old_tracks.insert(1, *tracks)
      mock_session { playlist.insert(1, tracks) }

      playlist.tracks.to_a.should eq new_tracks
    end

    it "should default to adding tracks at the end" do
      mock_session { playlist.insert(tracks) }
      playlist.tracks[2, 2].should eq tracks
    end

    it "should raise an error if the operation cannot be completed" do
      expect { mock_session { playlist.insert(-1, nil) } }.to raise_error(Hallon::Error)
    end
  end

  describe "#remove" do
    it "should remove the tracks at the given indices" do
      old_tracks = playlist.tracks.to_a
      new_tracks = [old_tracks[0], old_tracks[2]]

      playlist.remove(1, 3)
      playlist.tracks.to_a.should eq new_tracks
    end

    it "should raise an error if the operation cannot be completed" do
      expect { playlist.remove(-1) }.to raise_error(Hallon::Error)
    end
  end

  describe "#move" do
    it "should move the tracks at the given indices to their new location" do
      old_tracks = playlist.tracks.to_a
      new_tracks = [old_tracks[1], old_tracks[0], old_tracks[3], old_tracks[2]]

      playlist.move(2, [0, 3])
      playlist.tracks.to_a.should eq new_tracks
    end

    it "should raise an error if the operation cannot be completed" do
      expect { playlist.move(-1, [-1]) }.to raise_error(Hallon::Error)
    end
  end

  describe "#name=" do
    it "should set the new playlist name" do
      playlist.name.should eq "Megaplaylist"
      playlist.name = "Monoplaylist"
      playlist.name.should eq "Monoplaylist"
    end

    it "should not fail given an empty name", :pending => "not sure" do
      expect { playlist.name = "" }.to_not raise_error
    end

    it "should fail given a name of only spaces" do
      expect { playlist.name = " " * 255 }.to raise_error(ArgumentError)
    end

    it "should fail given a too long name" do
      expect { playlist.name = "a" * 256 }.to raise_error(ArgumentError)
    end
  end

  describe "#collaborative=" do
    it "should set the collaborative status" do
      playlist.should be_collaborative
      playlist.collaborative = false
      playlist.should_not be_collaborative
    end
  end

  describe "#autolink_tracks=" do
    it "should set autolink status" do
      Spotify.mocksp_playlist_get_autolink_tracks(playlist.pointer).should be_false
      playlist.autolink_tracks = true
      Spotify.mocksp_playlist_get_autolink_tracks(playlist.pointer).should be_true
    end
  end

  describe "#in_ram=" do
    it "should set in_ram status" do
      mock_session do
        playlist.should be_in_ram
        playlist.in_ram = false
        playlist.should_not be_in_ram
      end
    end
  end

  describe "#offline_mode=" do
    it "should set offline mode" do
      mock_session do
        playlist.should_not be_available_offline
        playlist.offline_mode = true
        playlist.should be_available_offline
      end
    end
  end

  describe "#update_subscribers" do
    it "should ask libspotify to update the subscribers" do
      expect { mock_session { playlist.update_subscribers } }.to_not raise_error
    end
  end

  describe "offline status methods" do
    def symbol_for(number)
      Spotify.enum_type(:playlist_offline_status)[number]
    end

    specify "#available_offline?" do
      mock_session do
        Spotify.should_receive(:playlist_get_offline_status).and_return symbol_for(1)
        should be_available_offline
      end
    end

    specify "#syncing?" do
      mock_session do
        Spotify.should_receive(:playlist_get_offline_status).and_return symbol_for(2)
        should be_syncing
      end
    end

    specify "#waiting?" do
      mock_session do
        Spotify.should_receive(:playlist_get_offline_status).and_return symbol_for(3)
        should be_waiting
      end
    end

    specify "#offline_mode?" do
      mock_session do
        Spotify.should_receive(:playlist_get_offline_status).and_return symbol_for(0)
        should_not be_offline_mode
      end
    end
  end
end
