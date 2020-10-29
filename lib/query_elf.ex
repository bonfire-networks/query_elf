defmodule QueryElf do
  @moduledoc """
  Defines an Ecto query builder.

  It accepts the following options:

    * `:schema` - the `Ecto.Schema` for which the queries will be built (required)
    * `:searchable_fields` - a list of fields to build default filters for. This option is simply a
      shorthand syntax for using the `QueryElf.Plugins.AutomaticFilters` plugin with the given list
      as the `fields` option. You should check the plugin's documentation for more details.
      (default: `[]`)
    * `:sortable_fields` - a list of fields to build default sorters for. This option is simply a
      shorthand syntax for using the `QueryElf.Plugins.AutomaticSorters` plugin with the given list
      as the `fields` option. You should check the plugin's documentation for more details.
      (default: `[]`)
    * `:plugins` - a list of plugins that can be used to increment the query builder's
      functionality. See `QueryElf.Plugin` for more details. (default: `[]`)

  ### Example

      defmodule MyQueryBuilder do
        use QueryElf,
          schema: MySchema,
          searchable_fields: [:id, :name],
          plugins: [
            {QueryElf.Plugins.OffsetPagination, default_per_page: 10},
            MyCustomPlugin
          ]

        def filter(:my_filter, value, _query) do
          dynamic([s], s.some_field - ^value == 0)
        end
      end

      MyQueryBuilder.build_query(id__in: [1, 2, 3], my_filter: 10)

  ### Sharing plugins and configuration accross query builders

  Sometimes you have certain plugins that you wish to always use, while allowing some degree of
  fexibility to each individual query builder definition. For those scenarios, you can use something
  like the following:

      defmodule MyQueryElf do
        defmacro __using__(opts) do
          # Always define filters for the `id` field
          searchable_fields = (opts[:searchable_fields] || []) ++ [:id]

          # Always define a sorter for the `id` field
          sortable_fields = (opts[:sortable_fields] || []) ++ [:id]

          # Use a default per page of `20`, but allow the user to change this value
          default_per_page = opts[:default_per_page] || 20

          # Allow the user to include extra plugins
          extra_plugins = opts[:plugins] || []

          quote do
            use QueryElf,
              schema: unquote(opts[:schema]),
              plugins: [
                {QueryElf.Plugins.AutomaticFilters, fields: unquote(searchable_fields)},
                {QueryElf.Plugins.AutomaticSorters, fields: unquote(sortable_fields)},
                {QueryElf.Plugins.OffsetPagination, default_per_page: unquote(default_per_page)},
                # put any other plugins here
              ] ++ unquote(extra_plugins)
          end
        end
      end

      defmodule MyQueryBuilder do
        use MyQueryElf,
          schema: MySchema,
          searchable_fields: ~w[id name age is_active roles]a
      end

  Using this strategy you can create a re-usable set of default plugins (and plugin configurations)
  that best suits your application needs, while allowing you to use `QueryElf` without these
  defaults if you ever need to.
  """

  @type sort_direction :: :asc | :desc

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
  @callback empty_query :: Ecto.Query.t()

  @doc """
  Should receive a a keyword list or a map containing parameters and use it to build a query.
  """
  @callback build_query(filter) :: Ecto.Query.t()

  @doc """
  Same thing as `build_query/1`, but also receives some options for things like pagination and
  ordering.
  """
  @callback build_query(filter, options) :: Ecto.Query.t()

  @doc """
  The same thing as `build_query/2`, but instead of building a new query it receives and extends
  an existing one.
  """
  @callback build_query(Ecto.Query.t(), filter, options) :: Ecto.Query.t()

  @doc """
  Receives an atom representing a filter, the parameter for the aforementioned filter and an Ecto
  query. Should return an Ecto dynamic or a tuple containing an Ecto query and an Ecto dynamic.

  Most of the filtering should happen in the returned dynamic, and returning a query should only
  be used when the query needs to be extended for the dynamic to make sense. Example:

      # this is a simple comparison, so just returning a dynamic will suffice
      def filter(:my_filter, value, _query) do
        dynamic([s], s.some_field == ^value)
      end

      # this relies on a join, so the query must be extended accordingly
      def filter(:my_other_filter, value, query) do
        {
          join(query, :left, [s], assoc(s, :some_relationship), as: :related),
          dynamic([related: r], r.some_field == ^value)
        }
      end
  """
  @callback filter(atom, term, Ecto.Query.t()) ::
              Ecto.Query.dynamic() | {Ecto.Query.t(), Ecto.Query.dynamic()}

  @doc """
  Receives an atom representing a field to order by, the order direction, an extra argument to
  perform the ordering, and an Ecto query. Should return the Ecto query with the appropriate sorting
  options applied.

  Example:

        def sort(:name, direction, _arg, query) do
          sort(query, [s], [{^direction, s.name}])
        end
  """
  @callback sort(atom, sort_direction, term, Ecto.Query.t()) :: Ecto.Query.t()

  @doc """
  Should return the base query in this query builder. This base query will be used when defining the
  `empty_query/0` and `build_query/1` callbacks. If not defined, defaults to the supplied schema.

  This is useful when dealing with logical deletion or other business rules that need to be followed
  every time the query builder is used. Example:

      defmodule UsersQueryBuilder do
        use QueryElf,
          schema: User,
          searchable_fields: [:id, :name]

        def base_query do
          from u in User, where: is_nil(u.deleted_at)
        end
      end

  """
  @callback base_query :: Ecto.Query.t()

  @optional_callbacks [filter: 3, sort: 4, base_query: 0]

  import Ecto.Query

  @doc """
  Similar to `Ecto.Query.join/{4,5}`, but can be called multiple times with the same alias.

  Note that only the first join operation is performed, the subsequent ones that use the same alias
  are just ignored. Also note that because of this behaviour, its mandatory to specify an alias when
  using this function.

  This is helpful when you need to perform a join while building queries one filter at a time,
  because the same filter could be used multiple times or you could have multiple filters that
  require the same join.

  This scenario poses a problem with how the `filter/3` callback work, as you need to return a
  dynamic with the filtering, which means that the join must have an alias, and by default Ecto
  raises an error when you add multiple joins with the same alias.

  To solve this, it is recommended to use this macro instead of the default `Ecto.Query.join/{4,5}`.
  As an added bonus, there will be only one join in the query that can be reused by multiple
  filters.
  """
  defmacro reusable_join(query, qual, bindings, expr, opts) do
    quote do
      query = Ecto.Queryable.to_query(unquote(query))
      join_alias = unquote(Keyword.fetch!(opts, :as))

      if Enum.any?(query.joins, &(&1.as == join_alias)) do
        query
      else
        join(query, unquote(qual), unquote(bindings), unquote(expr), unquote(opts))
      end
    end
  end

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import Ecto.Query
      import QueryElf, only: [reusable_join: 5]

      schema = Keyword.fetch!(opts, :schema)

      plugins =
        opts
        |> Keyword.get(:plugins, [])
        |> Enum.map(fn
          plugin when is_atom(plugin) -> {plugin, []}
          {plugin, opts} when is_atom(plugin) -> {plugin, opts}
        end)

      plugins =
        case Keyword.fetch(opts, :searchable_fields) do
          {:ok, fields} -> [{QueryElf.Plugins.AutomaticFilters, fields: fields} | plugins]
          :error -> plugins
        end

      plugins =
        case Keyword.fetch(opts, :sortable_fields) do
          {:ok, fields} -> [{QueryElf.Plugins.AutomaticSorters, fields: fields} | plugins]
          :error -> plugins
        end

      @schema schema
      @query_builder_plugins plugins
      @behaviour QueryElf
      @before_compile QueryElf
      @on_definition QueryElf

      Module.register_attribute(__MODULE__, :query_builder_filters, accumulate: true)
      Module.register_attribute(__MODULE__, :query_builder_sorters, accumulate: true)

      def base_query do
        @schema
      end

      defoverridable base_query: 0

      plugins
      |> Enum.map(fn {plugin, opts} -> plugin.using(opts) end)
      |> Code.eval_quoted([], __ENV__)
    end
  end

  def __on_definition__(env, :def, :filter, [filter_name, _value, _query], _guards, _body)
      when is_atom(filter_name) do
    Module.put_attribute(env.module, :query_builder_filters, filter_name)
    :ok
  end

  def __on_definition__(env, :def, :filter, [filter_name, _value, _query], _guards, _body) do
    raise CompileError,
      description: """
      Illegal filter/3 function defined in #{inspect(env.module)}.

      The first argument to filter/3 must always be a literal atom. You provided: `#{
        Macro.to_string(filter_name)
      }`.
      """
  end

  def __on_definition__(env, :def, :sort, [order_field, _, _, _], _guards, _body)
      when is_atom(order_field) do
    Module.put_attribute(env.module, :query_builder_sorters, order_field)
    :ok
  end

  def __on_definition__(env, :def, :sort, [order_field, _, _, _], _guards, _body) do
    raise CompileError,
      description: """
      Illegal sort/4 function defined in #{inspect(env.module)}.

      The first argument to sort/4 must always be a literal atom. You provided: `#{
        Macro.to_string(order_field)
      }`.
      """
  end

  def __on_definition__(_, _, _, _, _, _) do
    :ok
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      def empty_query do
        from(base_query(), where: false)
      end

      def build_query(filter) do
        build_query(base_query(), filter, [])
      end

      def build_query(filter, options) do
        build_query(base_query(), filter, options)
      end

      def build_query(query, filter, options) do
        unquote(__MODULE__).build_query(
          __MODULE__,
          query,
          filter,
          @query_builder_plugins,
          options
        )
      end

      def __query_builder__(:filters) do
        Enum.sort([:_or, :_and | @query_builder_filters])
      end

      def __query_builder__(:sorters) do
        Enum.sort(@query_builder_sorters)
      end
    end
  end

  @doc false
  def build_query(builder, query, filter, plugins, options) do
    query
    |> apply_filter(builder, filter)
    |> apply_ordering(builder, options[:order] || [])
    |> apply_plugins(builder, plugins, options)
  end

  defp apply_filter(query, builder, filter) do
    {query, [dynamic]} = filter({:_and, filter}, {query, []}, builder)

    where(query, ^dynamic)
  end

  defp apply_ordering(query, builder, order_instructions) do
    order_instructions
    |> Enum.map(fn
      {direction, {field, arg}} -> {direction, field, arg}
      {direction, field} -> {direction, field, nil}
      %{direction: direction, field: field, extra_argument: arg} -> {direction, field, arg}
      %{direction: direction, field: field} -> {direction, field, nil}
    end)
    |> Enum.reduce(query, fn {direction, field, arg}, query ->
      builder.sort(field, direction, arg, query)
    end)
  end

  defp apply_plugins(query, builder, plugins, options) do
    Enum.reduce(plugins, query, fn {plugin, _plugin_options}, query ->
      plugin.build_query(query, builder, options)
    end)
  end

  defp filter({condition, filter}, {query, dynamics}, _builder)
       when condition in [:_or, :_and] and filter in [%{}, []] do
    {query, [true | dynamics]}
  end

  defp filter({:_or, filter}, {query, dynamics}, builder) do
    {query, inner_dynamics} = Enum.reduce(filter, {query, []}, &filter(&1, &2, builder))

    dynamic = Enum.reduce(inner_dynamics, &dynamic(^&1 or ^&2))

    {query, [dynamic | dynamics]}
  end

  defp filter({:_and, filter}, {query, dynamics}, builder) do
    {query, inner_dynamics} = Enum.reduce(filter, {query, []}, &filter(&1, &2, builder))

    dynamic = Enum.reduce(inner_dynamics, &dynamic(^&1 and ^&2))

    {query, [dynamic | dynamics]}
  end

  defp filter({filter, value}, {query, dynamics}, builder) do
    case builder.filter(filter, value, query) do
      {query, dynamic} -> {query, [dynamic | dynamics]}
      dynamic -> {query, [dynamic | dynamics]}
    end
  end
end
