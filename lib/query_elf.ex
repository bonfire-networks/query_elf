defmodule QueryElf do
  @moduledoc """
  Defines an Ecto query builder.

  Here's a simple usage example:

      defmodule MyQueryBuilder do
        use QueryElf,
          schema: MySchema,
          searchable_fields: [:id, :name]

        def filter(:my_extra_filter, value, _query) do
          dynamic([s], s.some_field - ^value == 0)
        end
      end

      MyQueryBuilder.build_query(id__in: [1, 2, 3], my_extra_filter: 10)

  It accepts the following options:

    * `:schema` - the `Ecto.Schema` for which the queries will be built (required)
    * `:searchable_fields` - a list of fields to build default filters for (default: `[]`)
    * `:sortable_fields` - a list of fields to build default sorters for (default: `[]`)
    * `:plugins` - a list of plugins that can be used to increment the query builder's
      functionality. (default: `[]`)

  If used, the `:searchable_fields` option will define the following filters (according to the field
  type in the schema):

    * `id` or `binary_id`:
      * `:$FIELD` - checks if the field is equal to the given value
      * `:$FIELD__neq` - checks if the field is different from the given value
      * `:$FIELD__in` - checks if the field is contained in the given enumerable
    * `boolean`:
      * `:$FIELD` - checks if the field is equal to the given value
    * `integer`, `float` or `decimal`:
      * `:$FIELD` - checks if the field is equal to the given value
      * `:$FIELD__neq` - checks if the field is different from the given value
      * `:$FIELD__in` - checks if the field is contained in the given enumerable
      * `:$FIELD__gt` - checks if the field is greater than the given value
      * `:$FIELD__lt` - checks if the field is lower than the given value
      * `:$FIELD__gte` - checks if the field is greater than or equal to the given value
      * `:$FIELD__lte` - checks if the field is lower than or equal to the given value
    * `string`:
      * `:$FIELD` - checks if the field is equal to the given value
      * `:$FIELD__neq` - checks if the field is different from the given value
      * `:$FIELD__in` - checks if the field is contained in the given enumerable
      * `:$FIELD__contains` - checks if the field contains the given string
      * `:$FIELD__starts_with` - checks if the field starts with the given string
      * `:$FIELD__ends_with` - checks if the field ends with the given string
    * `date`, `time`, `naive_datetime`, `datetime`, `time_usec`, `naive_datetime_usec` or
      `datetime_usec`:
      * `:$FIELD` - checks if the field is equal to the given value
      * `:$FIELD__neq` - checks if the field is different from the given value
      * `:$FIELD__in` - checks if the field is contained in the given enumerable
      * `:$FIELD__after` - checks if the field occurs after the given value
      * `:$FIELD__before` - checks if the field occurs before the given value
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

  @optional_callbacks [sort: 4, base_query: 0]

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
  defmacro reusable_join(query, qual, bindings \\ [], expr, opts) do
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
    {schema, []} =
      opts
      |> Keyword.fetch!(:schema)
      |> Code.eval_quoted([], __CALLER__)

    {searchable_fields, []} =
      opts
      |> Keyword.get(:searchable_fields, [])
      |> Code.eval_quoted([], __CALLER__)

    {sortable_fields, []} =
      opts
      |> Keyword.get(:sortable_fields, [])
      |> Code.eval_quoted([], __CALLER__)

    plugins = Keyword.get(opts, :plugins, [])
    default_per_page = Keyword.get(opts, :default_per_page, 25)

    quote do
      import Ecto.Query
      import unquote(__MODULE__), only: [reusable_join: 4, reusable_join: 5]

      @schema unquote(schema)
      @query_builder_plugins unquote(plugins)
      @query_builder_default_per_page unquote(default_per_page)
      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @on_definition unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :query_builder_filters, accumulate: true)
      Module.register_attribute(__MODULE__, :query_builder_sorters, accumulate: true)

      def base_query do
        @schema
      end

      defoverridable base_query: 0

      unquote(
        for field <- searchable_fields,
            type = schema.__schema__(:type, field),
            do: define_filter_for_field(field, type)
      )

      unquote(
        for field <- sortable_fields,
            do: define_order_by_for_field(field)
      )
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

      def __query_builder__(:default_per_page) do
        @query_builder_default_per_page
      end
    end
  end

  @doc false
  def build_query(builder, query, filter, plugins, options) do
    query
    |> apply_filter(builder, filter)
    |> apply_pagination(builder, options[:page], options[:per_page])
    |> apply_ordering(builder, options[:order] || [])
    |> apply_plugins(builder, plugins, options)
  end

  defp apply_filter(query, builder, filter) do
    {query, [dynamic]} = filter({:_and, filter}, {query, []}, builder)

    where(query, ^dynamic)
  end

  defp apply_pagination(query, builder, page, per_page)

  defp apply_pagination(query, _builder, nil, _per_page), do: query

  defp apply_pagination(query, builder, page, nil),
    do: apply_pagination(query, builder, page, builder.__query_builder__(:default_per_page))

  defp apply_pagination(query, _builder, page, per_page) do
    offset = (page - 1) * per_page

    query
    |> limit(^per_page)
    |> offset(^offset)
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
    Enum.reduce(plugins, query, fn plugin, query ->
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

  defp define_filter_for_field(field, id_type) when id_type in ~w[id binary_id]a do
    equality_filter(field)
  end

  defp define_filter_for_field(field, :boolean) do
    quote do
      def filter(unquote(field), value, _query) do
        dynamic([s], field(s, unquote(field)) == ^value)
      end
    end
  end

  defp define_filter_for_field(field, number_type)
       when number_type in ~w[integer float decimal]a do
    quote do
      unquote(equality_filter(field))

      def filter(unquote(:"#{field}__gt"), value, _query) do
        dynamic([s], field(s, unquote(field)) > ^value)
      end

      def filter(unquote(:"#{field}__lt"), value, _query) do
        dynamic([s], field(s, unquote(field)) < ^value)
      end

      def filter(unquote(:"#{field}__gte"), value, _query) do
        dynamic([s], field(s, unquote(field)) >= ^value)
      end

      def filter(unquote(:"#{field}__lte"), value, _query) do
        dynamic([s], field(s, unquote(field)) <= ^value)
      end
    end
  end

  defp define_filter_for_field(field, date_type)
       when date_type in ~w[date time naive_datetime utc_datetime time_usec naive_datetime_usec utc_datetime_usec]a do
    quote do
      unquote(equality_filter(field))

      def filter(unquote(:"#{field}__after"), value, _query) do
        dynamic([s], field(s, unquote(field)) > ^value)
      end

      def filter(unquote(:"#{field}__before"), value, _query) do
        dynamic([s], field(s, unquote(field)) < ^value)
      end
    end
  end

  defp define_filter_for_field(field, :string) do
    quote do
      unquote(equality_filter(field))

      def filter(unquote(:"#{field}__contains"), value, _query) do
        dynamic([s], like(field(s, unquote(field)), ^"%#{value}%"))
      end

      def filter(unquote(:"#{field}__starts_with"), value, _query) do
        dynamic([s], like(field(s, unquote(field)), ^"#{value}%"))
      end

      def filter(unquote(:"#{field}__ends_with"), value, _query) do
        dynamic([s], like(field(s, unquote(field)), ^"%#{value}"))
      end
    end
  end

  defp define_filter_for_field(_field, {:array, _}) do
    []
  end

  defp define_order_by_for_field(field) do
    quote do
      def sort(unquote(field), direction, _args, query) do
        order_by(query, [s], [{^direction, field(s, unquote(field))}])
      end
    end
  end

  defp equality_filter(field) do
    quote do
      def filter(unquote(field), value, _query) do
        dynamic([s], field(s, unquote(field)) == ^value)
      end

      def filter(unquote(:"#{field}__neq"), value, _query) do
        dynamic([s], field(s, unquote(field)) != ^value)
      end

      def filter(unquote(:"#{field}__in"), value, _query) do
        dynamic([s], field(s, unquote(field)) in ^value)
      end

      def filter(unquote(:"#{field}__not_in"), value, _query) do
        dynamic([s], field(s, unquote(field)) not in ^value)
      end
    end
  end
end
