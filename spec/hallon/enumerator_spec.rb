describe Hallon::Enumerator do
  let(:item) do
    mock.tap { |x| x.stub(:get).and_return(&alphabet) }
  end

  let(:enum) do
    Hallon::Enumerator.new(5) { |i| item.get(i) }
  end

  let(:alphabet) do
    proc { |x| %w[a b c d e][x] }
  end


  it "should be an enumerable" do
    enum.should respond_to :each
    enum.should be_an Enumerable
  end

  describe "#each" do
    it "should call the containing block" do
      enum = Hallon::Enumerator.new(4) { |i| item.get(i) }
      enum.each_with_index { |x, i| x.should eq alphabet[i] }
    end
  end

  describe "#size" do
    it "should return the given size" do
      Hallon::Enumerator.new(4).size.should eq 4
    end
  end

  describe "#[]" do
    it "should support #[x] within range" do
      item.should_receive(:get).with(1).and_return(&alphabet)

      enum[1].should eq "b"
    end

    it "should support negative #[x] within range" do
      item.should_receive(:get).with(4).and_return(&alphabet)

      enum[-1].should eq "e"
    end

    it "should return nil for #[x] outside range" do
      item.should_not_receive(:get)

      enum[6].should be_nil
    end

    it "should return nil for #[-x] outside range" do
      item.should_not_receive(:get)

      enum[-6].should be_nil
    end

    it "should return a slice of elements for #[x, y]" do
      item.should_receive(:get).with(1).and_return(&alphabet)
      item.should_receive(:get).with(2).and_return(&alphabet)

      enum[1, 2].should eq %w[b c]
    end

    it "should return elements for an inclusive range of #[x..y]" do
      item.should_receive(:get).with(1).and_return(&alphabet)
      item.should_receive(:get).with(2).and_return(&alphabet)
      item.should_receive(:get).with(3).and_return(&alphabet)

      enum[1..3].should eq %w[b c d]
    end

    it "should return return only existing elements for partly inclusive range of #[x..y]" do
      item.should_receive(:get).with(4).and_return(&alphabet)

      enum[4..7].should eq %w[e]
    end

    it "should return nil for a completely outside range of #[x..y]" do
      item.should_not_receive(:get)

      enum[6..10].should eq nil
    end

    it "should return the items for #[-x, y]" do
      item.should_receive(:get).with(2).and_return(&alphabet)
      item.should_receive(:get).with(3).and_return(&alphabet)
      item.should_receive(:get).with(4).and_return(&alphabet)

      enum[-3, 3].should eq %w[c d e]
    end

    it "should slice between items by #[x, y]" do
      item.should_not_receive(:get)

      enum[5, 1].should eq []
    end

    it "should slice between items by #[x..y]" do
      item.should_not_receive(:get)

      enum[5..10].should eq []
    end
  end
end
