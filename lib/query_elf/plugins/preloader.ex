defmodule QueryElf.Plugins.Preloader do
  @moduledoc """
  A module for preloading associations using joins.

  Based on https://hexdocs.pm/ecto_preloader (licensed under WTFPL)

  By default, Ecto preloads associations using a separate query for each association, which can degrade performance.

  You could make it run faster by using a combination of join/preload, but that requires a bit of boilerplate (see example below).

  With `Ecto.Preloader`, you can accomplish this with just one line of code.

  ## Example using just Ecto

  It requires calling `Query.join/4`, `Query.assoc/3` and `Query.preload/2`

  ```
  import Ecto.Query

  Invoice
  |> join(:left, [i], assoc(i, :customer), as: :customer)
  |> join(:left, [i], assoc(i, :lines), as: :lines)
  |> preload([lines: v, customers: c], lines: v, customer: c)
  |> Repo.all()
  ```

  ## Example using Ecto.Preloader

  Just one method call:

  ```
  import Ecto.Query
  import Ecto.Preloader

  Invoice
  |> preload_join(:customer)
  |> preload_join(:lines)
  |> Repo.all()
  ```

  """

  import Ecto, only: [assoc: 2]
  require QueryElf.Plugins.ReusableJoin

  alias Ecto.Query.Builder.{Join, Preload}


  # defp do_preload_join(query, association, bindings, expr, preload_bindings, preload_expr, caller) do
  #   IO.inspect(query: query)
  #   # IO.inspect(queryable: Ecto.Queryable.to_query(query))
  #   # IO.inspect(binding: bindings)
  #   # IO.inspect(expr: expr)
  #   # IO.inspect(association: association)
  #   # IO.inspect(preload_bindings: preload_bindings)
  #   # IO.inspect(preload_expr: preload_expr)

  #     query
  #     |> Join.build(:left, bindings, expr, nil, nil, association, nil, nil, caller)
  #     # |> reusable_join(:left, (bindings), (expr), as: association)
  #     |> elem(0)
  #     # |> IO.inspect
  #     |> Preload.build(preload_bindings, preload_expr, caller)
  # end

  defmacro do_preload_join(query, association, bindings, expr, preload_bindings, preload_expr, _) do
    # IO.inspect(query: query)
    # IO.inspect(queryable: Ecto.Queryable.to_query(query))
    # IO.inspect(bindings: bindings)
    # IO.inspect(expr: expr)
    # IO.inspect(association: association)

    opts = quote do: [as: unquote(association)]
    # IO.inspect(opts: opts)

    # IO.inspect(preload_bindings: preload_bindings)
    # IO.inspect(preload_expr: preload_expr)

    quote do

      unquote(query)
      |> QueryElf.Plugins.ReusableJoin.reusable_join(:left, unquote(bindings), unquote(expr), unquote(opts))
      |> preload(unquote(preload_bindings), unquote(preload_expr))
      # |> IO.inspect
    end
  end

  @doc "Join + Preload an association"
  defmacro preload_join(query, association) do

    # association = quote do: unquote(association)
    bindings = quote do: [root]
    expr = quote do: assoc(root, unquote(association))

    preload_bindings = quote do: [{unquote(association), ass}]
    preload_expr = quote do: [{unquote(association), ass}]

    quote do: do_preload_join(unquote(query), unquote(association), unquote(bindings), unquote(expr), unquote(preload_bindings), unquote(preload_expr), nil)
  end

  @doc "Join + Preload a nested association"
  defmacro preload_join(query, via_association, association) do

    query = quote do: preload_join(unquote(query), unquote(via_association))

    # association = quote do: unquote(association)
    # via_association_pos = quote do: named_binding_position(unquote(query), unquote(via_association))
    # IO.inspect(via_association_pos: via_association_pos)
    bindings = quote do: [root, {unquote(via_association), via}]
    expr = quote do: assoc(via, unquote(association))

    preload_bindings = quote do: [root, {unquote(association), ass}, {unquote(via_association), via}]
    preload_expr = quote do: [{unquote(via_association), unquote(association)}]
    # preload_expr = quote do: [{unquote(via_association), {via, {unquote(association), via}}}]

    quote do: do_preload_join(unquote(query), unquote(association), unquote(bindings), unquote(expr), unquote(preload_bindings), unquote(preload_expr), nil)
  end

  @doc "Join + Preload two nested associations"
  defmacro preload_join(query, via_association_a, via_association_b, association) do

    query = quote do: preload_join(unquote(query), unquote(via_association_a), unquote(via_association_b))

    # association = quote do: unquote(association)
    # via_association_a_pos = named_binding_position(query, via_association_a)
    # IO.inspect(via_association_a_pos: via_association_a_pos)
    bindings = quote do: [root, {via_b, unquote(via_association_b)}]
    expr = quote do: assoc(via_b, unquote(association))

    preload_bindings = quote do: [root, a, b, x]
    # TODO: construct proper preload expr with vars to avoid extra queries
    preload_expr = quote do: [{unquote(via_association_a), [{unquote(via_association_b), [unquote(association)]}]}]

    quote do: do_preload_join(unquote(query), unquote(association), unquote(bindings), unquote(expr), unquote(preload_bindings), unquote(preload_expr), nil)
  end

  defp named_binding_position(query, binding) do
    Map.get(query.aliases, binding)
  end

end
