defmodule BehaviorTreeTest do
  use ExUnit.Case
  alias BehaviorTree, as: BT
  alias BehaviorTree.Node

  doctest BehaviorTree
  doctest Node
  doctest BehaviorTree.Display
  doctest BehaviorTree.Serializer

  setup do
    tree =
      Node.sequence([
        Node.sequence([:a, :b, :c]),
        Node.select([:x, :y, Node.select([:z])]),
        :done
      ])

    bt = BT.start(tree)

    {:ok, %{bt: bt}}
  end

  describe "nodes" do
    test "don't take empty lists" do
      assert catch_error(Node.sequence([]))
      assert catch_error(Node.select([]))
    end
  end

  describe "starts over when reaching the end" do
    test "from succeed" do
      tree = Node.select([:a, :b])
      tree = tree |> BT.start() |> BT.succeed() |> BT.succeed()
      assert BT.value(tree) == :a
    end

    test "from fail" do
      tree = Node.sequence([:a, :b])
      tree = tree |> BT.start() |> BT.fail() |> BT.fail()
      assert BT.value(tree) == :a
    end
  end

  test "deep tree example", context do
    assert BT.value(context.bt) == :a

    bt =
      context.bt
      |> BT.succeed()
      |> BT.succeed()
      |> BT.succeed()
      |> BT.fail()
      |> BT.fail()
      |> BT.succeed()

    assert BT.value(bt) == :done
  end

  test "repeat_n for success branch (not done in doctests)" do
    tree =
      Node.sequence([
        Node.repeat_n(2, :a),
        :b
      ])

    assert tree |> BehaviorTree.start() |> BehaviorTree.value() == :a
    assert tree |> BehaviorTree.start() |> BehaviorTree.succeed() |> BehaviorTree.value() == :a

    assert tree |> BehaviorTree.start() |> BehaviorTree.succeed() |> BehaviorTree.succeed()
           |> BehaviorTree.value() == :b
  end

  test "nesting repeat_n (resets internal state)" do
    nested =
      Node.sequence([
        Node.repeat_n(2, Node.repeat_n(2, :a)),
        :b
      ])

    assert nested
    |> BehaviorTree.start()
    |> BehaviorTree.succeed()
    |> BehaviorTree.succeed()
    |> BehaviorTree.succeed()
    |> BehaviorTree.value()
    == :a
  end

  describe "parallel" do
    test "visits all children and succeeds when all succeed" do
      tree = Node.parallel([:a, :b, :c])
      bt = BT.start(tree)
      assert BT.value(bt) == :a

      bt = BT.succeed(bt)
      assert BT.value(bt) == :b

      bt = BT.succeed(bt)
      assert BT.value(bt) == :c

      # all 3 succeeded, parallel succeeds -> tree restarts
      bt = BT.succeed(bt)
      assert BT.value(bt) == :a
    end

    test "fails when not enough children succeed (default threshold = all)" do
      tree = Node.sequence([Node.parallel([:a, :b, :c]), :done])
      bt = BT.start(tree)

      bt = bt |> BT.succeed() |> BT.fail() |> BT.succeed()
      # 2 out of 3 succeeded, threshold is 3 -> parallel fails -> sequence fails -> restart
      assert BT.value(bt) == :a
    end

    test "succeeds with custom threshold" do
      tree = Node.sequence([Node.parallel([:a, :b, :c], 2), :done])
      bt = BT.start(tree)

      # succeed, fail, succeed -> 2 successes >= threshold of 2
      bt = bt |> BT.succeed() |> BT.fail() |> BT.succeed()
      assert BT.value(bt) == :done
    end

    test "fails with custom threshold not met" do
      tree = Node.sequence([Node.parallel([:a, :b, :c], 2), :done])
      bt = BT.start(tree)

      # succeed, fail, fail -> 1 success < threshold of 2
      bt = bt |> BT.succeed() |> BT.fail() |> BT.fail()
      assert BT.value(bt) == :a
    end

    test "works nested inside other nodes" do
      tree =
        Node.select([
          Node.parallel([:a, :b], 2),
          :fallback
        ])

      bt = BT.start(tree)
      assert BT.value(bt) == :a

      # both fail -> parallel fails -> select moves to fallback
      bt = bt |> BT.fail() |> BT.fail()
      assert BT.value(bt) == :fallback
    end
  end

  describe "display" do
    test "shows tree structure for started tree" do
      tree = Node.sequence([:a, :b])
      bt = BT.start(tree)
      result = BT.display(bt)

      assert result =~ "sequence"
      assert result =~ ":a"
      assert result =~ ":b"
      assert result =~ "◀"
    end

    test "shows tree structure for raw node" do
      tree = Node.sequence([Node.select([:a, :b]), :c])
      result = BT.display(tree)

      assert result =~ "sequence"
      assert result =~ "select"
      assert result =~ ":a"
      assert result =~ ":c"
      refute result =~ "◀"
    end
  end

  describe "update" do
    test "swaps the tree definition and restarts" do
      tree = Node.sequence([:a, :b]) |> BT.start()
      assert BT.value(tree) == :a

      tree = BT.update(tree, fn _root -> Node.sequence([:x, :y]) end)
      assert BT.value(tree) == :x
    end

    test "can modify the existing tree" do
      tree = Node.sequence([:a, :b]) |> BT.start()
      tree = BT.update(tree, fn %{children: children} ->
        Node.sequence(children ++ [:c])
      end)
      assert BT.value(tree) == :a

      tree = tree |> BT.succeed() |> BT.succeed()
      assert BT.value(tree) == :c
    end
  end

  describe "DSL" do
    import BehaviorTree.DSL

    test "builds trees with block syntax" do
      tree = sequence do
        :a
        :b
        :c
      end

      assert tree == Node.sequence([:a, :b, :c])
    end

    test "supports nesting" do
      tree = sequence do
        select do
          :a
          :b
        end
        :c
      end

      assert tree == Node.sequence([Node.select([:a, :b]), :c])
    end

    test "supports decorators" do
      tree = repeat_n 3 do
        :a
      end

      assert tree == Node.repeat_n(3, :a)
    end

    test "supports parallel" do
      tree = parallel 2 do
        :a
        :b
        :c
      end

      assert tree == Node.parallel([:a, :b, :c], 2)
    end
  end

  describe "serializer" do
    alias BehaviorTree.Serializer

    test "round-trips a simple tree" do
      tree = Node.sequence([:a, :b, :c])
      assert tree == tree |> Serializer.to_map() |> Serializer.from_map()
    end

    test "round-trips nested trees" do
      tree = Node.sequence([
        Node.select([:a, :b]),
        Node.always_succeed(:c),
        :d
      ])
      assert tree == tree |> Serializer.to_map() |> Serializer.from_map()
    end

    test "round-trips repeat_n" do
      tree = Node.repeat_n(5, :a)
      assert tree == tree |> Serializer.to_map() |> Serializer.from_map()
    end

    test "round-trips parallel with threshold" do
      tree = Node.parallel([:a, :b, :c], 2)
      assert tree == tree |> Serializer.to_map() |> Serializer.from_map()
    end

    test "produces JSON-friendly maps" do
      map = Serializer.to_map(Node.sequence([:a, :b]))
      assert map == %{
        "type" => "sequence",
        "children" => [%{"leaf" => "a"}, %{"leaf" => "b"}]
      }
    end
  end

  test "random_weighted" do
    # This attempts to test results form :rand.uniform/2, which means it will
    # either be flaky or an approximation, but still useful
    #
    ratio =
      Enum.reduce(1..300, {0, 0, 0}, fn _, {a, b, c} ->
        value =
          [{:a, 3}, {:b, 2}, {:c, 1}]
          |> Node.random_weighted()
          |> BehaviorTree.start()
          |> BehaviorTree.value()

        case value do
          :a ->
            {a + 1, b, c}

          :b ->
            {a, b + 1, c}

          :c ->
            {a, b, c + 1}
        end
      end)

    {a, b, c} = ratio
    # The flaky part (increasing the range would help, but would be slower):
    # assert {round(a / c), round(b / c), 1} == {3, 2, 1}
    # Less flaky, but less informative
    assert a > b > c
  end
end
