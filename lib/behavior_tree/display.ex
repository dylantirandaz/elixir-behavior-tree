defmodule BehaviorTree.Display do
  @moduledoc """
  Pretty-prints behavior trees with tree-drawing characters.

  Works with both raw tree definitions and started trees.
  For started trees, the current leaf is marked with ◀.
  """

  alias BehaviorTree.Node
  alias ExZipper.Zipper

  @doc """
  Renders the tree as a readable string.

  ## Example

      iex> BehaviorTree.Node.sequence([:a, :b, :c]) |> BehaviorTree.Display.format()
      "sequence\\n├── :a\\n├── :b\\n└── :c\\n"

      iex> tree = BehaviorTree.Node.sequence([:a, :b]) |> BehaviorTree.start()
      iex> BehaviorTree.Display.format(tree)
      "sequence\\n├── :a  ◀\\n└── :b\\n"
  """
  @spec format(BehaviorTree.t() | Node.t() | any()) :: String.t()
  def format(%BehaviorTree{zipper: zipper}) do
    root = Zipper.node(Zipper.root(zipper))
    path = get_path(zipper)
    render_root(root, path)
  end

  def format(%Node{} = node) do
    render_root(node, nil)
  end

  def format(leaf) do
    inspect(leaf) <> "\n"
  end

  # Walks up the zipper to build a list of child indices from root to current.
  defp get_path(zipper, path \\ []) do
    case Zipper.up(zipper) do
      {:error, _} ->
        path

      parent ->
        index = zipper |> Zipper.lefts() |> length()
        get_path(parent, [index | path])
    end
  end

  defp render_root(%Node{} = node, path) do
    label = node_label(node)

    children_str =
      node.children
      |> Enum.with_index()
      |> Enum.map(fn {child, i} ->
        last? = i == length(node.children) - 1
        render(child, "", last?, path, [i])
      end)
      |> Enum.join()

    label <> "\n" <> children_str
  end

  defp render_root(leaf, path) do
    marker = if path == [], do: "  ◀", else: ""
    inspect(leaf) <> marker <> "\n"
  end

  defp render(%Node{} = node, prefix, last?, path, indices) do
    connector = if last?, do: "└── ", else: "├── "
    label = node_label(node)
    line = prefix <> connector <> label <> "\n"

    child_prefix = prefix <> if(last?, do: "    ", else: "│   ")

    children_str =
      node.children
      |> Enum.with_index()
      |> Enum.map(fn {child, i} ->
        child_last? = i == length(node.children) - 1
        render(child, child_prefix, child_last?, path, indices ++ [i])
      end)
      |> Enum.join()

    line <> children_str
  end

  defp render(leaf, prefix, last?, path, indices) do
    connector = if last?, do: "└── ", else: "├── "
    marker = if path != nil and path == indices, do: "  ◀", else: ""
    prefix <> connector <> inspect(leaf) <> marker <> "\n"
  end

  defp node_label(%Node{type: :repeat_n} = node), do: "repeat_n(#{node.repeat_total})"
  defp node_label(%Node{type: :parallel} = node), do: "parallel(#{node.success_threshold})"
  defp node_label(%Node{type: :guard}), do: "guard"
  defp node_label(%Node{type: :weighted_select}), do: "weighted_select"
  defp node_label(%Node{type: type}), do: Atom.to_string(type)
end
