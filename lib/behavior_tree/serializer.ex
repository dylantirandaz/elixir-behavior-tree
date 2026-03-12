defmodule BehaviorTree.Serializer do
  @moduledoc """
  Converts behavior trees to and from plain maps.

  Useful for saving trees to files, databases, or sending over the wire.
  The output is JSON-friendly (string keys, no structs).

  ## Example

      tree = Node.sequence([Node.select([:a, :b]), :c])

      map = BehaviorTree.Serializer.to_map(tree)
      # %{"type" => "sequence", "children" => [
      #   %{"type" => "select", "children" => [
      #     %{"leaf" => "a"}, %{"leaf" => "b"}
      #   ]},
      #   %{"leaf" => "c"}
      # ]}

      tree = BehaviorTree.Serializer.from_map(map)
      # Same as the original tree
  """

  alias BehaviorTree.Node

  @doc """
  Converts a tree definition to a plain map.

  Node types become string keys. Atom leaves are stored as strings.
  Extra fields like `n`, `weights`, and `threshold` are included where needed.

  ## Example

      iex> BehaviorTree.Serializer.to_map(BehaviorTree.Node.sequence([:a, :b]))
      %{"type" => "sequence", "children" => [%{"leaf" => "a"}, %{"leaf" => "b"}]}

      iex> BehaviorTree.Serializer.to_map(BehaviorTree.Node.repeat_n(3, :a))
      %{"type" => "repeat_n", "children" => [%{"leaf" => "a"}], "n" => 3}
  """
  @spec to_map(Node.t() | any()) :: map()
  def to_map(%Node{type: type, children: children} = node) do
    base = %{
      "type" => Atom.to_string(type),
      "children" => Enum.map(children, &to_map/1)
    }

    case type do
      :repeat_n -> Map.put(base, "n", node.repeat_total)
      :random_weighted -> Map.put(base, "weights", node.weights)
      :parallel -> Map.put(base, "threshold", node.success_threshold)
      _ -> base
    end
  end

  def to_map(leaf) when is_atom(leaf), do: %{"leaf" => Atom.to_string(leaf)}
  def to_map(leaf) when is_binary(leaf), do: %{"leaf" => leaf, "string" => true}
  def to_map(leaf) when is_number(leaf), do: %{"leaf" => leaf}

  @doc """
  Rebuilds a tree definition from a plain map.

  Atom leaves are restored using `String.to_existing_atom/1`, so the atom
  must already exist in the system. If it doesn't, the value stays as a string.

  ## Example

      iex> map = %{"type" => "sequence", "children" => [%{"leaf" => "a"}, %{"leaf" => "b"}]}
      iex> BehaviorTree.Serializer.from_map(map)
      BehaviorTree.Node.sequence([:a, :b])

      iex> map = %{"type" => "repeat_n", "children" => [%{"leaf" => "a"}], "n" => 3}
      iex> BehaviorTree.Serializer.from_map(map)
      BehaviorTree.Node.repeat_n(3, :a)
  """
  @spec from_map(map()) :: Node.t() | any()
  def from_map(%{"type" => type, "children" => children_maps} = map) do
    type_atom = String.to_existing_atom(type)
    children = Enum.map(children_maps, &from_map/1)

    case type_atom do
      :select -> Node.select(children)
      :sequence -> Node.sequence(children)
      :parallel -> Node.parallel(children, Map.get(map, "threshold", length(children)))
      :repeat_n -> Node.repeat_n(map["n"], hd(children))
      :repeat_until_fail -> Node.repeat_until_fail(hd(children))
      :repeat_until_succeed -> Node.repeat_until_succeed(hd(children))
      :random -> Node.random(children)
      :random_weighted -> Node.random_weighted(Enum.zip(children, map["weights"]))
      :always_succeed -> Node.always_succeed(hd(children))
      :always_fail -> Node.always_fail(hd(children))
      :negate -> Node.negate(hd(children))
    end
  end

  def from_map(%{"leaf" => value, "string" => true}), do: value

  def from_map(%{"leaf" => value}) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> value
  end

  def from_map(%{"leaf" => value}), do: value
end
