# frozen_string_literal: true

module Megatest
  class AssertionsTest < MegaTestCase
    class MyObject < ::BasicObject
      CONST = 1

      def title
        "MyObject"
      end
    end

    setup do
      @object = MyObject.new
    end

    test "stubs without a proc" do
      stub(@object, :title) do
        assert_nil @object.title(1, 2, a: 3, b: 4)
      end
      assert_equal "MyObject", @object.title

      stub(@object, :title)
      assert_nil @object.title(1, 2, a: 3, b: 4)
    end

    test "stubs for the duration of block" do
      assert_equal "MyObject", @object.title

      stub(@object, :title, -> { "Boooh!" }) do
        assert_equal "Boooh!", @object.title
      end

      assert_equal "MyObject", @object.title
    end

    test "nested stub blocks" do
      assert_equal "MyObject", @object.title

      stub(@object, :title, -> { "Boooh!" }) do
        assert_equal "Boooh!", @object.title

        stub(@object, :title, -> { "Woohoo!" }) do
          assert_equal "Woohoo!", @object.title
        end
        assert_equal "Boooh!", @object.title
      end
      assert_equal "MyObject", @object.title
    end

    test "stub for the duration of the test" do
      assert_equal "MyObject", @object.title

      stub(@object, :title, -> { "Boooh!" })
      assert_equal "Boooh!", @object.title

      stub(@object, :title, -> { "Woohoo!" })
      assert_equal "Woohoo!", @object.title

      @__m.teardown
      assert_equal "MyObject", @object.title
    end

    test "stub_any_instance_of without a proc" do
      stub_any_instance_of(MyObject, :title) do
        assert_nil @object.title(1, 2, a: 3, b: 4)
      end
      assert_equal "MyObject", @object.title

      stub_any_instance_of(MyObject, :title)
      assert_nil @object.title(1, 2, a: 3, b: 4)
    end

    test "stub_any_instance_of for the duration of block" do
      assert_equal "MyObject", @object.title

      stub_any_instance_of(MyObject, :title, -> { "Boooh!" }) do
        assert_equal "Boooh!", @object.title
      end

      assert_equal "MyObject", @object.title
    end

    test "nested stub_any_instance_of blocks" do
      assert_equal "MyObject", @object.title

      stub_any_instance_of(MyObject, :title, -> { "Boooh!" }) do
        assert_equal "Boooh!", @object.title

        stub_any_instance_of(MyObject, :title, -> { "Woohoo!" }) do
          assert_equal "Woohoo!", @object.title
        end
        assert_equal "Boooh!", @object.title
      end
      assert_equal "MyObject", @object.title
    end

    test "stub_any_instance_of for the duration of the test" do
      assert_equal "MyObject", @object.title

      stub_any_instance_of(MyObject, :title, -> { "Boooh!" })
      assert_equal "Boooh!", @object.title

      stub_any_instance_of(MyObject, :title, -> { "Woohoo!" })
      assert_equal "Woohoo!", @object.title

      @__m.teardown
      assert_equal "MyObject", @object.title
    end

    test "stub_const for the duration of block" do
      assert_equal 1, MyObject::CONST

      stub_const(MyObject, :CONST, 2) do
        assert_equal 2, MyObject::CONST
      end

      assert_equal 1, MyObject::CONST
    end

    test "stub_const for the duration of the test" do
      assert_equal 1, MyObject::CONST

      stub_const(MyObject, :CONST, 2)
      assert_equal 2, MyObject::CONST

      @__m.teardown
      assert_equal 1, MyObject::CONST
    end

    test "nested stub_const" do
      assert_equal 1, MyObject::CONST

      stub_const(MyObject, :CONST, 2) do
        assert_equal 2, MyObject::CONST

        stub_const(MyObject, :CONST, 3) do
          assert_equal 3, MyObject::CONST
        end

        assert_equal 2, MyObject::CONST
      end

      assert_equal 1, MyObject::CONST
    end

    test "repeated stub_const" do
      assert_equal 1, MyObject::CONST

      stub_const(MyObject, :CONST, 2)
      assert_equal 2, MyObject::CONST

      stub_const(MyObject, :CONST, 3)
      assert_equal 3, MyObject::CONST

      @__m.teardown
      assert_equal 1, MyObject::CONST
    end

    test "stub_const for non-existing constant" do
      assert_raises NameError do
        stub_const(MyObject, :DOES_NOT_EXIST, 3)
      end

      stub_const(MyObject, :DOES_NOT_EXIST, 3, exists: false) do
        assert_equal 3, MyObject::DOES_NOT_EXIST

        assert_raises NameError do
          stub_const(MyObject, :DOES_NOT_EXIST, 3, exists: false)
        end
      end

      refute MyObject.const_defined?(:DOES_NOT_EXIST)
    end
  end
end
