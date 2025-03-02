require "./spec_helper"

describe "Regex" do
  it "compare to other instances" do
    Regex.new("foo").should eq(Regex.new("foo"))
    Regex.new("foo").should_not eq(Regex.new("bar"))
  end

  it "does =~" do
    (/foo/ =~ "bar foo baz").should eq(4)
    $~.group_size.should eq(0)
  end

  it "does inspect" do
    /foo/.inspect.should eq("/foo/")
    /foo/.inspect.should eq("/foo/")
    /foo/imx.inspect.should eq("/foo/imx")
  end

  it "does to_s" do
    /foo/.to_s.should eq("(?-imsx:foo)")
    /foo/im.to_s.should eq("(?ims-x:foo)")
    /foo/imx.to_s.should eq("(?imsx-:foo)")

    "Crystal".match(/(?<bar>C)#{/(?<foo>R)/i}/).should be_truthy
    "Crystal".match(/(?<bar>C)#{/(?<foo>R)/}/i).should be_falsey

    md = "Crystal".match(/(?<bar>.)#{/(?<foo>.)/}/).not_nil!
    md[0].should eq("Cr")
    md["bar"].should eq("C")
    md["foo"].should eq("r")
  end

  it "does inspect with slash" do
    %r(/).inspect.should eq("/\\//")
    %r(\/).inspect.should eq("/\\//")
  end

  it "does to_s with slash" do
    %r(/).to_s.should eq("(?-imsx:\\/)")
    %r(\/).to_s.should eq("(?-imsx:\\/)")
  end

  it "doesn't crash when PCRE tries to free some memory (#771)" do
    expect_raises(ArgumentError) { Regex.new("foo)") }
  end

  it "checks if Char need to be escaped" do
    Regex.needs_escape?('*').should be_true
    Regex.needs_escape?('|').should be_true
    Regex.needs_escape?('@').should be_false
  end

  it "checks if String need to be escaped" do
    Regex.needs_escape?("10$").should be_true
    Regex.needs_escape?("foo").should be_false
  end

  it "escapes" do
    Regex.escape(" .\\+*?[^]$(){}=!<>|:-hello").should eq("\\ \\.\\\\\\+\\*\\?\\[\\^\\]\\$\\(\\)\\{\\}\\=\\!\\<\\>\\|\\:\\-hello")
  end

  it "matches ignore case" do
    ("HeLlO" =~ /hello/).should be_nil
    ("HeLlO" =~ /hello/i).should eq(0)
  end

  it "matches lines beginnings on ^ in multiline mode" do
    ("foo\nbar" =~ /^bar/).should be_nil
    ("foo\nbar" =~ /^bar/m).should eq(4)
  end

  it "matches multiline" do
    ("foo\n<bar\n>baz" =~ /<bar.*?>/).should be_nil
    ("foo\n<bar\n>baz" =~ /<bar.*?>/m).should eq(4)
  end

  it "matches unicode char against [[:print:]] (#11262)" do
    ("\n☃" =~ /[[:print:]]/).should eq(1)
  end

  it "matches unicode char against [[:alnum:]] (#4704)" do
    /[[:alnum:]]/x.match("à").should_not be_nil
  end

  it "matches with =~ and captures" do
    ("fooba" =~ /f(o+)(bar?)/).should eq(0)
    $~.group_size.should eq(2)
    $1.should eq("oo")
    $2.should eq("ba")
  end

  it "matches with =~ and gets utf-8 codepoint index" do
    index = "こんに" =~ /ん/
    index.should eq(1)
  end

  it "matches with === and captures" do
    "foo" =~ /foo/
    (/f(o+)(bar?)/ === "fooba").should be_true
    $~.group_size.should eq(2)
    $1.should eq("oo")
    $2.should eq("ba")
  end

  describe "#matches?" do
    it "matches but create no MatchData" do
      /f(o+)(bar?)/.matches?("fooba").should be_true
      /f(o+)(bar?)/.matches?("barfo").should be_false
    end

    it "can specify initial position of matching" do
      /f(o+)(bar?)/.matches?("fooba", 1).should be_false
    end

    it "matches a large single line string" do
      str = File.read(datapath("large_single_line_string.txt"))
      str.matches?(/^(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?$/).should be_false
    end
  end

  describe "name_table" do
    it "is a map of capture group number to name" do
      table = (/(?<date> (?<year>(\d\d)?\d\d) - (?<month>\d\d) - (?<day>\d\d) )/x).name_table
      table[1].should eq("date")
      table[2].should eq("year")
      table[3]?.should be_nil
      table[4].should eq("month")
      table[5].should eq("day")
    end
  end

  describe "capture_count" do
    it "returns the number of (named & non-named) capture groups" do
      /(?:.)/x.capture_count.should eq(0)
      /(?<foo>.+)/.capture_count.should eq(1)
      /(.)?/x.capture_count.should eq(1)
      /(.)|(.)/x.capture_count.should eq(2)
    end
  end

  it "raises exception with invalid regex" do
    expect_raises(ArgumentError) { Regex.new("+") }
  end

  it "raises if outside match range with []" do
    "foo" =~ /foo/
    expect_raises(IndexError) { $1 }
  end

  describe ".union" do
    it "constructs a Regex that matches things any of its arguments match" do
      re = Regex.union(/skiing/i, "sledding")
      re.match("Skiing").not_nil![0].should eq "Skiing"
      re.match("sledding").not_nil![0].should eq "sledding"
    end

    it "returns a regular expression that will match passed arguments" do
      Regex.union("penzance").should eq /penzance/
      Regex.union("skiing", "sledding").should eq /skiing|sledding/
      Regex.union(/dogs/, /cats/i).should eq /(?-imsx:dogs)|(?i-msx:cats)/
    end

    it "quotes any string arguments" do
      Regex.union("n", ".").should eq /n|\./
    end

    it "returns a Regex with an Array(String) with special characters" do
      Regex.union(["+", "-"]).should eq /\+|\-/
    end

    it "accepts a single Array(String | Regex) argument" do
      Regex.union(["skiing", "sledding"]).should eq /skiing|sledding/
      Regex.union([/dogs/, /cats/i]).should eq /(?-imsx:dogs)|(?i-msx:cats)/
      (/dogs/ + /cats/i).should eq /(?-imsx:dogs)|(?i-msx:cats)/
    end

    it "accepts a single Tuple(String | Regex) argument" do
      Regex.union({"skiing", "sledding"}).should eq /skiing|sledding/
      Regex.union({/dogs/, /cats/i}).should eq /(?-imsx:dogs)|(?i-msx:cats)/
      (/dogs/ + /cats/i).should eq /(?-imsx:dogs)|(?i-msx:cats)/
    end

    it "combines Regex objects in the same way as Regex#+" do
      Regex.union(/skiing/i, /sledding/).should eq(/skiing/i + /sledding/)
    end
  end

  it "dups" do
    regex = /foo/
    regex.dup.should be(regex)
  end

  it "clones" do
    regex = /foo/
    regex.clone.should be(regex)
  end

  it "checks equality by ==" do
    regex = Regex.new("foo", Regex::Options::IGNORE_CASE)
    (regex == Regex.new("foo", Regex::Options::IGNORE_CASE)).should be_true
    (regex == Regex.new("foo")).should be_false
    (regex == Regex.new("bar", Regex::Options::IGNORE_CASE)).should be_false
    (regex == Regex.new("bar")).should be_false
  end

  it "hashes" do
    hash = Regex.new("foo", Regex::Options::IGNORE_CASE).hash
    hash.should eq(Regex.new("foo", Regex::Options::IGNORE_CASE).hash)
    hash.should_not eq(Regex.new("foo").hash)
    hash.should_not eq(Regex.new("bar", Regex::Options::IGNORE_CASE).hash)
    hash.should_not eq(Regex.new("bar").hash)
  end
end
