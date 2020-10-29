defmodule QueryElf.Plugin do
  @moduledoc """
  A behaviour to be followed when creating plugins that extends the query builders functionality.
  """

  @doc """
  Called when QueryElf is used with the plugin.

  Should be used to inject required code in the builder module.
  """
  @callback using(options :: keyword) :: Macro.t()

  @doc """
  Takes the query, the builder, and the options given to the `build_query` function build the query
  as arguments. Should return the modified query.
  """
  @callback build_query(query :: Ecto.Query.t(), builder :: module, options :: QueryElf.options()) ::
              Ecto.Query.t()

  @optional_callbacks using: 1, build_query: 3

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def using(_opts) do
        []
      end

      @impl unquote(__MODULE__)
      def build_query(query, _builder, _opts) do
        query
      end

      defoverridable using: 1, build_query: 3
    end
  end
end
