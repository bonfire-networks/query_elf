defmodule QueryElf.Plugin do
  @moduledoc """
  A behaviour to be followed when creating plugins that extends the query builders functionality.
  """

  @doc """
  Takes the query, the builder, and the options given to the `build_query` function build the query
  as arguments. Should return the modified query.
  """
  @callback build_query(Ecto.Query.t(), module, QueryElf.options()) :: Ecto.Query.t()
end
