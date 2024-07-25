# frozen_string_literal: true

module Megatest
  class PrettyPrintTest < MegaTestCase
    setup do
      @config = Config.new({})
      @pp = PrettyPrint.new(@config)
    end

    test "BasicObject" do
      assert_pp "#<BasicObject:0x00000000decafbad>", BasicObject.new
    end

    test "Object" do
      object = Object.new
      object.instance_variable_set(:@foo, 12)
      object.instance_variable_set(:@bar, [1, 2, 3])
      assert_pp "#<Object:0x00000000decafbad @bar=[1, 2, 3], @foo=12>", object
    end

    test "cyclic" do
      object = Object.new
      object.instance_variable_set(:@foo, 12)
      object.instance_variable_set(:@bar, [1, 2, 3])
      object.instance_variable_set(:@self, object)
      case RUBY_ENGINE
      when "truffleruby", "jruby"
        assert_pp <<~TEXT.strip, object
          #<Object:0x00000000decafbad @bar=[1, 2, 3], @foo=12, @self=#<Object:0x00000000decafbad ...>>
        TEXT
      else
        assert_pp <<~TEXT.strip, object
          #<Object:0x00000000decafbad
           @bar=[1, 2, 3],
           @foo=12,
           @self=#<Object:0x00000000decafbad ...>>
        TEXT
      end
    end

    test "Hash" do
      object = {
        foo: 12,
        "bar" => [1, 2, 3],
      }
      assert_pp '{:foo=>12, "bar"=>[1, 2, 3]}', object
    end

    private

    def assert_pp(match, object)
      inspect = normalize(pp(object))
      if match.is_a?(Regexp)
        assert_match(match, inspect)
      else
        assert_equal(match, inspect)
      end
    end

    def normalize(text)
      text.gsub(/(?<=:0x)([\da-f]{4,16})/, "00000000decafbad")
    end

    def pp(object)
      @pp.pretty_print(object)
    end
  end
end
