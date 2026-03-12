defmodule BehaviorTree.DSL do
  @moduledoc """
  A macro-based DSL for building behavior trees with a cleaner syntax.

  Instead of nested function calls, you can write trees as indented blocks.

  ## Example

      import BehaviorTree.DSL

      tree = sequence do
        select do
          :a
          :b
        end
        :c
      end

      # Equivalent to:
      # Node.sequence([Node.select([:a, :b]), :c])

  Decorator nodes take a single child:

      tree = repeat_n 3 do
        sequence do
          :aim
          :fire
        end
      end
  """

  @doc "Builds a select node from its block children."
  defmacro select(do: block) do
    children = extract_children(block)
    quote do: BehaviorTree.Node.select(unquote(children))
  end

  @doc "Builds a sequence node from its block children."
  defmacro sequence(do: block) do
    children = extract_children(block)
    quote do: BehaviorTree.Node.sequence(unquote(children))
  end

  @doc "Builds a parallel node. All children must succeed."
  defmacro parallel(do: block) do
    children = extract_children(block)
    quote do: BehaviorTree.Node.parallel(unquote(children))
  end

  @doc "Builds a parallel node with a success threshold."
  defmacro parallel(threshold, do: block) do
    children = extract_children(block)
    quote do: BehaviorTree.Node.parallel(unquote(children), unquote(threshold))
  end

  @doc "Builds a random node from its block children."
  defmacro random(do: block) do
    children = extract_children(block)
    quote do: BehaviorTree.Node.random(unquote(children))
  end

  @doc "Builds a random_weighted node. Children should be `{value, weight}` tuples."
  defmacro random_weighted(do: block) do
    children = extract_children(block)
    quote do: BehaviorTree.Node.random_weighted(unquote(children))
  end

  @doc "Builds a repeat_until_fail decorator."
  defmacro repeat_until_fail(do: block) do
    child = extract_single_child(block)
    quote do: BehaviorTree.Node.repeat_until_fail(unquote(child))
  end

  @doc "Builds a repeat_until_succeed decorator."
  defmacro repeat_until_succeed(do: block) do
    child = extract_single_child(block)
    quote do: BehaviorTree.Node.repeat_until_succeed(unquote(child))
  end

  @doc "Builds a repeat_n decorator."
  defmacro repeat_n(n, do: block) do
    child = extract_single_child(block)
    quote do: BehaviorTree.Node.repeat_n(unquote(n), unquote(child))
  end

  @doc "Builds an always_succeed decorator."
  defmacro always_succeed(do: block) do
    child = extract_single_child(block)
    quote do: BehaviorTree.Node.always_succeed(unquote(child))
  end

  @doc "Builds an always_fail decorator."
  defmacro always_fail(do: block) do
    child = extract_single_child(block)
    quote do: BehaviorTree.Node.always_fail(unquote(child))
  end

  @doc "Builds a negate decorator."
  defmacro negate(do: block) do
    child = extract_single_child(block)
    quote do: BehaviorTree.Node.negate(unquote(child))
  end

  defp extract_children({:__block__, _, children}), do: children
  defp extract_children(single), do: [single]

  defp extract_single_child({:__block__, _, [child]}), do: child
  defp extract_single_child(child), do: child
end
