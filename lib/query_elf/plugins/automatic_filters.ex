defmodule QueryElf.Plugins.AutomaticFilters do
  @moduledoc """
  Plugin for automatically defining filters for a set of fields.

  It accepts the following options:

    - `:fields` - the list of fields for which to define filters. (required)

  The defined filters will vary according to the field type in the schema:

    * `id` or `binary_id`:
      * `:$FIELD` - checks if the field is equal to the given value
      * `:$FIELD__neq` - checks if the field is different from the given value
      * `:$FIELD__in` - checks if the field is contained in the given enumerable
      * `:$FIELD__not_in` - checks if the field is not contained in the given enumerable
    * `boolean`:
      * `:$FIELD` - checks if the field is equal to the given value
    * `integer`, `float` or `decimal`:
      * `:$FIELD` - checks if the field is equal to the given value
      * `:$FIELD__neq` - checks if the field is different from the given value
      * `:$FIELD__in` - checks if the field is contained in the given enumerable
      * `:$FIELD__not_in` - checks if the field is not contained in the given enumerable
      * `:$FIELD__gt` - checks if the field is greater than the given value
      * `:$FIELD__lt` - checks if the field is lower than the given value
      * `:$FIELD__gte` - checks if the field is greater than or equal to the given value
      * `:$FIELD__lte` - checks if the field is lower than or equal to the given value
    * `string`:
      * `:$FIELD` - checks if the field is equal to the given value
      * `:$FIELD__neq` - checks if the field is different from the given value
      * `:$FIELD__in` - checks if the field is contained in the given enumerable
      * `:$FIELD__not_in` - checks if the field is not contained in the given enumerable
      * `:$FIELD__contains` - checks if the field contains the given string
      * `:$FIELD__starts_with` - checks if the field starts with the given string
      * `:$FIELD__ends_with` - checks if the field ends with the given string
    * `date`, `time`, `naive_datetime`, `datetime`, `time_usec`, `naive_datetime_usec` or
      `datetime_usec`:
      * `:$FIELD` - checks if the field is equal to the given value
      * `:$FIELD__neq` - checks if the field is different from the given value
      * `:$FIELD__in` - checks if the field is contained in the given enumerable
      * `:$FIELD__not_in` - checks if the field is not contained in the given enumerable
      * `:$FIELD__after` - checks if the field occurs after the given value
      * `:$FIELD__before` - checks if the field occurs before the given value

  Any other types are simply ignored.

  ### Example

      defmodule MyQueryBuilder do
        use QueryElf,
          schema: MySchema,
          plugins: [
            {QueryElf.Plugins.AutomaticFilters, fields: ~w[id name age is_active]a}
          ]
      end

      MyQueryBuilder.build_query(id__in: [1, 2, 3], name__starts_with: "John")
  """

  use QueryElf.Plugin

  @impl QueryElf.Plugin
  def using(opts) do
    fields = Keyword.fetch!(opts, :fields)

    quote bind_quoted: [fields: fields] do
      require QueryElf.Plugins.AutomaticFilters

      fields
      |> Enum.map(fn field ->
        type = @schema.__schema__(:type, field)
        # IO.inspect(field: field)
        # IO.inspect(type: type)

        QueryElf.Plugins.AutomaticFilters.__define_filters__(field, type)
      end)
      |> Code.eval_quoted([], __ENV__)
    end
  end

  @id_types Application.get_env(:query_elf, :id_types, [:id, :binary_id])

  @doc false
  @spec __define_filters__(field :: atom, type :: Ecto.Type.t()) :: Macro.t()
  def __define_filters__(field, id_type) when id_type in @id_types do
    equality_filter(field)
  end

  def __define_filters__(field, :boolean) do
    quote do
      def filter(unquote(field), value, _query) do
        dynamic([s], field(s, unquote(field)) == ^value)
      end
    end
  end

  def __define_filters__(field, number_type)
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

  def __define_filters__(field, date_type)
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

  def __define_filters__(field, :string) do
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

  def __define_filters__(_field, _type) do
    []
  end

  defp equality_filter(field) do
    # IO.inspect(equality_filter: field)
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
