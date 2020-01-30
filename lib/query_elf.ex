defmodule QueryElf do
  @moduledoc """
  This is a behaviour that describes something that knows how to build a query. You can implement
  this behaviour manually, but it's encouraged to use it with an adapter:

      defmodule MyQueryBuilder do
        use QueryElf, adapter: QueryElf.MyAdapter
      end

  For now, the only available adapter is `QueryElf.Ecto`. Please look at its
  documentation for more details on how to use it.
  """

  @type query :: term

  @type filter :: keyword | map

  @type options :: keyword

  @type metadata_type :: :filters

  @doc """
  Should return the query builder metadata requested.
  """
  @callback __query_builder__(metadata_type) :: term

  @doc """
  Should return a query that when applied, returns nothing.
  """
  @callback empty_query :: query

  @doc """
  Should receive a a keyword list or a map containing parameters and use it to build a query.
  """
  @callback build_query(filter) :: query

  @doc """
  Same thing as `build_query/1`, but also receives some options for things like pagination and
  ordering.
  """
  @callback build_query(filter, options) :: query

  @doc """
  The same thing as `build_query/2`, but instead of building a new query it receives and extends
  an existing one.
  """
  @callback build_query(query, filter, options) :: query

  defmacro __using__(opts) do
    {adapter, adapter_opts} = Keyword.pop(opts, :adapter)

    quote do
      use unquote(adapter), unquote(adapter_opts)

      @behaviour unquote(__MODULE__)
    end
  end
end
