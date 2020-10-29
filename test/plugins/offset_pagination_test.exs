defmodule QueryElf.Plugins.OffsetPaginationTest do
  use ExUnit.Case, async: true

  import Ecto.Query

  defmodule TestSchema do
    use Ecto.Schema

    embedded_schema do
    end
  end

  test "allows for limit-offset pagination" do
    defmodule QBSimple do
      use QueryElf,
        schema: TestSchema,
        plugins: [QueryElf.Plugins.OffsetPagination]
    end

    assert_equal_queries(
      QBSimple.build_query([]),
      TestSchema
    )

    assert_equal_queries(
      QBSimple.build_query([], page: 1),
      TestSchema |> limit(^25) |> offset(^0)
    )

    assert_equal_queries(
      QBSimple.build_query([], page: 2),
      TestSchema |> limit(^25) |> offset(^25)
    )

    assert_equal_queries(
      QBSimple.build_query([], page: 3, per_page: 10),
      TestSchema |> limit(^10) |> offset(^20)
    )
  end

  test "allows for customization of the default page size" do
    defmodule QBDefaultPageSize do
      use QueryElf,
        schema: TestSchema,
        plugins: [{QueryElf.Plugins.OffsetPagination, default_per_page: 15}]
    end

    assert_equal_queries(
      QBDefaultPageSize.build_query([], page: 1),
      TestSchema |> limit(^15) |> offset(^0)
    )

    assert_equal_queries(
      QBDefaultPageSize.build_query([], page: 2),
      TestSchema |> limit(^15) |> offset(^15)
    )

    assert_equal_queries(
      QBDefaultPageSize.build_query([], page: 3, per_page: 10),
      TestSchema |> limit(^10) |> offset(^20)
    )
  end

  defp assert_equal_queries(q1, q2) do
    assert inspect(q1) == inspect(q2)
  end
end
