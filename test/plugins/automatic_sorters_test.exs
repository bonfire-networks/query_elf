defmodule QueryElf.Plugins.AutomaticSortersTest do
  use ExUnit.Case, async: true

  import Ecto.Query

  defmodule TestSchema do
    use Ecto.Schema

    embedded_schema do
      field(:my_int, :integer)
      field(:my_string, :string)
      field(:my_bool, :boolean)
      field(:my_date, :date)
    end
  end

  defmodule QB do
    use QueryElf,
      schema: TestSchema,
      plugins: [
        {QueryElf.Plugins.AutomaticSorters, fields: ~w[id]a}
      ]
  end

  test "defines automatic sorters for the given fields" do
    assert_equal_queries(order_by(TestSchema, asc: :id), QB.build_query([], order: [asc: :id]))
  end

  defp assert_equal_queries(q1, q2) do
    assert inspect(q1) == inspect(q2)
  end
end
