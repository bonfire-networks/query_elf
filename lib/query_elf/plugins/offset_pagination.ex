defmodule QueryElf.Plugins.OffsetPagination do
  @moduledoc """
  Plugin to enable limit-offset based pagination in any query builder.

  It accepts the following options:

    * `:default_per_page` - the default value of items per page (default: `25`)

  ### Example

      defmodule MySchemaQueryBuilder do
        use QueryElf,
          schema: MySchema,
          plugins: [QueryElf.Plugins.OffsetPagination]
      end

      MySchemaQueryBuilder.build_query([], page: 2, per_page: 25)
  """

  use QueryElf.Plugin

  @impl QueryElf.Plugin
  def using(opts) do
    default_per_page = Keyword.get(opts, :default_per_page, 25)

    quote do
      def __offset_pagination_default_per_page__ do
        unquote(default_per_page)
      end
    end
  end

  @impl QueryElf.Plugin
  def build_query(query, builder, options) do
    apply_pagination(query, builder, options[:page], options[:per_page])
  end

  defp apply_pagination(query, builder, page, per_page)

  defp apply_pagination(query, _builder, nil, _per_page), do: query

  defp apply_pagination(query, builder, page, nil),
    do:
      apply_pagination(
        query,
        builder,
        page,
        builder.__offset_pagination_default_per_page__()
      )

  defp apply_pagination(query, _builder, page, per_page) do
    import Ecto.Query

    offset = (page - 1) * per_page

    query
    |> limit(^per_page)
    |> offset(^offset)
  end
end
