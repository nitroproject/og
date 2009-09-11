require File.join(File.dirname(__FILE__), 'helper.rb')

module OgDeleteAll
  
describe "Og delete_all" do
  
  setup do
    class Playlist
      attr_accessor :name, String
      has_many :tracks
    end

    class Track
      attr_accessor :name, String
      belongs_to Playlist

      def initialize(playlist)
        self.playlist = playlist
      end
    end
    
    @store = quick_setup(Playlist, Track)
  end

  def pop
    @pl = Playlist.create
    5.times do |i|
      Track.create(@pl)
    end
  end
  
  it "should delete all objects from db" do
    pop
    @pl.tracks.delete_all
    Track.all.empty?.should == true

    pop
    @pl.tracks.each { |obj| obj.delete }
    Track.all.empty?.should == true
  end
end

end
