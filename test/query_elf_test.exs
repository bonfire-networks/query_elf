defmodule QueryElfTest do
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
      searchable_fields: ~w[id my_int my_string my_bool my_date]a,
      sortable_fields: ~w[my_int my_bool]a
  end

  test "allows sorting" do
    target_query = TestSchema |> order_by(asc: :my_int) |> order_by(desc: :my_bool)

    assert_equal_queries(QB.build_query([], order: [asc: :my_int, desc: :my_bool]), target_query)

    assert_equal_queries(
      QB.build_query([], order: [asc: {:my_int, nil}, desc: {:my_bool, nil}]),
      target_query
    )

    assert_equal_queries(
      QB.build_query([],
        order: [%{field: :my_int, direction: :asc}, %{field: :my_bool, direction: :desc}]
      ),
      target_query
    )

    assert_equal_queries(
      QB.build_query([],
        order: [
          %{field: :my_int, direction: :asc, extra_argument: nil},
          %{field: :my_bool, direction: :desc, extra_argument: nil}
        ]
      ),
      target_query
    )
  end

  test "allows filtering" do
    assert_equal_queries(QB.build_query(id: 1), where(TestSchema, id: ^1))
    assert_equal_queries(QB.build_query(id__neq: 1), where(TestSchema, [s], s.id != ^1))
    assert_equal_queries(QB.build_query(id__in: [1, 2]), where(TestSchema, [s], s.id in ^[1, 2]))
  end

  test "allows for complex criteria composition" do
    assert_equal_queries(
      QB.build_query(
        _or: [
          my_bool: false,
          _and: [my_int: 1, id: "a"],
          _and: [my_int: 2, id: "b"]
        ]
      ),
      where(
        TestSchema,
        [s],
        s.my_bool == ^false or
          ((s.my_int == ^1 and s.id == ^"a") or (s.my_int == ^2 and s.id == ^"b"))
      )
    )
  end

  test "requires the fields in defined filters to be literal atoms" do
    assert_raise CompileError,
                 ~r/The first argument to filter\/3 must always be a literal atom/,
                 fn ->
                   defmodule QBFilterError do
                     use QueryElf,
                       schema: TestSchema

                     def filter(_my_field, _arg, _query) do
                     end
                   end
                 end
  end

  test "requires the fields in defined sorters to be literal atoms" do
    assert_raise CompileError,
                 ~r/The first argument to sort\/4 must always be a literal atom/,
                 fn ->
                   defmodule QBSortError do
                     use QueryElf,
                       schema: TestSchema

                     def sort(_my_field, _direction, _extra_arg, _query) do
                     end
                   end
                 end
  end

  describe "reusable_join/{4,5}" do
    test "works like a regular join when used once per alias" do
      import QueryElf, only: [reusable_join: 5]

      assert_equal_queries(
        reusable_join("table", :left, [t1], t2 in "other_table", on: t1.id == t2.id, as: :other),
        join("table", :left, [t1], t2 in "other_table", on: t1.id == t2.id, as: :other)
      )

      assert_equal_queries(
        "table"
        |> reusable_join(:left, [t1], t2 in "other_table", on: t1.id == t2.id, as: :other_a)
        |> reusable_join(:left, [t1], t2 in "other_table", on: t1.id == t2.id, as: :other_b),
        "table"
        |> join(:left, [t1], t2 in "other_table", on: t1.id == t2.id, as: :other_a)
        |> join(:left, [t1], t2 in "other_table", on: t1.id == t2.id, as: :other_b)
      )
    end

    test "does nothing if a join already exists with the same alias" do
      import QueryElf, only: [reusable_join: 5]

      query = join("table", :left, [t1], t2 in "other_table", on: t1.id == t2.id, as: :other)

      assert_equal_queries(
        reusable_join(query, :left, [t1], t2 in "other_table", on: t1.id == t2.id, as: :other),
        query
      )
    end
  end

  defp assert_equal_queries(q1, q2) do
    assert inspect(q1) == inspect(q2)
  end
end
