defmodule QueryElf.Plugins.AutomaticSorters do
  @moduledoc """
  Plugin for automatically defining sorters for a set of fields.

  It accepts the following options:

    - `:fields` - the list of fields for which to define sorters. (required)

  ### Example

  This definition:

      defmodule MyQueryBuilder do
        use QueryElf,
          schema: MySchema,
          plugins: [
            {QueryElf.Plugins.AutomaticSorters, fields: ~w[inserted_at]a}
          ]
      end

  is equivalent to:

      defmodule MyQueryBuilder do
        use QueryElf,
          schema: MySchema

        def sort(:inserted_at, direction, _args, query) do
          case direction do
            :asc -> order_by(query, asc: :inserted_at)
            :desc -> order_by(query, desc: :inserted_at)
          end
        end
      end
  """

  use QueryElf.Plugin

  @impl QueryElf.Plugin
  def using(opts) do
    fields = Keyword.fetch!(opts, :fields)

    quote bind_quoted: [fields: fields] do
      require QueryElf.Plugins.AutomaticSorters

      fields
      |> Enum.map(fn field ->
        QueryElf.Plugins.AutomaticSorters.__define_sorter__(field)
      end)
      |> Code.eval_quoted([], __ENV__)
    end
  end

  @doc false
  @spec __define_sorter__(field :: atom) :: Macro.t()
  def __define_sorter__(field) do
    quote do
      def sort(unquote(field), direction, _args, query) do
        order_by(query, [{^direction, unquote(field)}])
      end
    end
  end
end
