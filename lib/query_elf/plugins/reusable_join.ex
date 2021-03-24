defmodule QueryElf.Plugins.ReusableJoin do
  import Ecto.Query

  @doc """
  Similar to `Ecto.Query.join/{4,5}`, but can be called multiple times with the same alias.

  Note that only the first join operation is performed, the subsequent ones that use the same alias
  are just ignored. Also note that because of this behaviour, its mandatory to specify an alias when
  using this function.

  This is helpful when you need to perform a join while building queries one filter at a time,
  because the same filter could be used multiple times or you could have multiple filters that
  require the same join, which poses a problem with how the `filter/3` callback work, as you
  need to return a dynamic with the filtering, which means that the join must have an alias,
  and by default Ecto raises an error when you add multiple joins with the same alias.

  To solve this, it is recommended to use this macro instead of the default `Ecto.Query.join/{4,5}`,
  in which case there will be only one join in the query that can be reused by multiple filters.
  """
  defmacro reusable_join(query, qual, bindings, expr, opts) do
    IO.inspect(join_alias: Keyword.fetch!(opts, :as))
    quote do
      query = Ecto.Queryable.to_query(unquote(query))
      join_alias = unquote(Keyword.fetch!(opts, :as))

      if Enum.any?(query.joins, &(&1.as == join_alias)) do
        query
      else
        query
        |> join(unquote(qual), unquote(bindings), unquote(expr), unquote(opts))
      end
    end
  end
end
