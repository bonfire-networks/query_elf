defmodule QueryElf.Plugins.AutomaticFiltersTest do
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
        {QueryElf.Plugins.AutomaticFilters, fields: ~w[id my_int my_string my_bool my_date]a}
      ]
  end

  test "defines automatic filters for id fields" do
    assert_equal_queries(QB.build_query(id: 1), where(TestSchema, id: ^1))
    assert_equal_queries(QB.build_query(id__neq: 1), where(TestSchema, [s], s.id != ^1))
    assert_equal_queries(QB.build_query(id__in: [1, 2]), where(TestSchema, [s], s.id in ^[1, 2]))
  end

  test "defines automatic filters for numeric fields" do
    assert_equal_queries(QB.build_query(my_int: 1), where(TestSchema, my_int: ^1))
    assert_equal_queries(QB.build_query(my_int__neq: 1), where(TestSchema, [s], s.my_int != ^1))

    assert_equal_queries(QB.build_query(my_int__gt: 1), where(TestSchema, [s], s.my_int > ^1))
    assert_equal_queries(QB.build_query(my_int__lt: 1), where(TestSchema, [s], s.my_int < ^1))
    assert_equal_queries(QB.build_query(my_int__gte: 1), where(TestSchema, [s], s.my_int >= ^1))
    assert_equal_queries(QB.build_query(my_int__lte: 1), where(TestSchema, [s], s.my_int <= ^1))

    assert_equal_queries(
      QB.build_query(my_int__in: [1, 2]),
      where(TestSchema, [s], s.my_int in ^[1, 2])
    )
  end

  test "defines automatic filters for string fields" do
    assert_equal_queries(QB.build_query(my_string: "a"), where(TestSchema, my_string: ^"a"))

    assert_equal_queries(
      QB.build_query(my_string__neq: "a"),
      where(TestSchema, [s], s.my_string != ^"a")
    )

    assert_equal_queries(
      QB.build_query(my_string__contains: "a"),
      where(TestSchema, [s], like(s.my_string, ^"%a%"))
    )

    assert_equal_queries(
      QB.build_query(my_string__starts_with: "a"),
      where(TestSchema, [s], like(s.my_string, ^"a%"))
    )

    assert_equal_queries(
      QB.build_query(my_string__ends_with: "a"),
      where(TestSchema, [s], like(s.my_string, ^"%a"))
    )

    assert_equal_queries(
      QB.build_query(my_string__in: ["a", "b"]),
      where(TestSchema, [s], s.my_string in ^["a", "b"])
    )
  end

  test "defines automatic filters for boolean fields" do
    assert_equal_queries(QB.build_query(my_bool: true), where(TestSchema, my_bool: ^true))
  end

  test "defines automatic filters for date fields" do
    assert_equal_queries(
      QB.build_query(my_date: ~D[2019-01-01]),
      where(TestSchema, my_date: ^~D[2019-01-01])
    )

    assert_equal_queries(
      QB.build_query(my_date__neq: ~D[2019-01-01]),
      where(TestSchema, [s], s.my_date != ^~D[2019-01-01])
    )

    assert_equal_queries(
      QB.build_query(my_date__after: ~D[2019-01-01]),
      where(TestSchema, [s], s.my_date > ^~D[2019-01-01])
    )

    assert_equal_queries(
      QB.build_query(my_date__before: ~D[2019-01-01]),
      where(TestSchema, [s], s.my_date < ^~D[2019-01-01])
    )

    assert_equal_queries(
      QB.build_query(my_date__in: [~D[2019-01-01], ~D[2019-01-04]]),
      where(TestSchema, [s], s.my_date in ^[~D[2019-01-01], ~D[2019-01-04]])
    )
  end

  defp assert_equal_queries(q1, q2) do
    assert inspect(q1) == inspect(q2)
  end
end
