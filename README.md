# QueryElf

> A helper to build the most common database queries for [Ecto](https://hexdocs.pm/ecto/Ecto.html).

## Installation

Install from [Hex.pm](https://hex.pm/packages/query_elf):

```elixir
def deps do
  [{:query_elf, "~> 0.2.0"}]
end
```

## Documentation

API documentation is available at [https://hexdocs.pm/query_elf](https://hexdocs.pm/query_elf/api-reference.html)

## Usage

QueryElf helps to build and extend the common database queries for Ecto. It provides an elegant way of building complex Ecto queries using query composition. While it supports search, sort and paginate operations, it also allows extending the query builder using custom plugins. Production systems at Up Learn are powered by QueryElf.

Here's a simple example:

```elixir
defmodule MyQueryBuilder do
  use QueryElf,
    schema: MySchema,
    searchable_fields: [:id, :name],
    sortable_fields: [:id :name]

  def filter(:my_extra_filter, value, _query) do
    dynamic([s], s.some_field - ^value == 0)
  end
end

MyQueryBuilder.build_query(id__in: [1, 2, 3], my_extra_filter: 10)
```

More examples:

```elixir
  defmodule TestSchema do
    use Ecto.Schema

    embedded_schema do
      field :my_int, :integer
      field :my_string, :string
      field :my_bool, :boolean
      field :my_date, :date
    end
  end

  defmodule QB do
    use QueryElf,
      schema: TestSchema,
      searchable_fields: ~w[id my_int my_string my_bool my_date]a,
      sortable_fields: ~w[my_int my_bool]a
  end

  # Ordering on fields
  QB.build_query([],
    order: [%{field: :my_int, direction: :asc}, %{field: :my_bool, direction: :desc}]
  )

  # Shorthand expression for ordering example mentioned above
  QB.build_query([],
    order: [asc: :my_int, desc: :my_bool]
  )

  # Filtering on ID field
  QB.build_query(id__neq: 1)
  QB.build_query(id__in: [1, 2])

  # Filtering on integer field
  QB.build_query(my_int__gt: 1)
  QB.build_query(my_int__lte: 1)

  # Filtering on string field
  QB.build_query(my_string__starts_with: "a")
  QB.build_query(my_string__contains: "a")

  # Creating complex query using composition
  QB.build_query(
    _or: [
      my_bool: false,
      _and: [my_int: 1, id: "a"],
      _and: [my_int: 2, id: "b"]
    ]
  )

  # Creating reusable joins
  "table"
  |> reusable_join(:left, [t1], t2 in "other_table", on: t1.id == t2.id, as: :other_a)
  |> reusable_join(:left, [t1], t2 in "other_table", on: t1.id == t2.id, as: :other_b)
```

## Running tests

Clone the repo and fetch its dependencies:

    $ git clone https://gitlab.com/up-learn-uk/query-elf.git
    $ cd query-elf
    $ mix deps.get
    $ mix test

## Contributing

We appreciate any contribution to QueryElf. Check our [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [CONTRIBUTING.md](CONTRIBUTING.md) guides for more information. We usually keep a list of features and bugs [in the issue tracker](https://gitlab.com/up-learn-uk/query-elf/issues).

## Copyright and License

Copyright (c) 2020 Up Learn.

Query Elf source code is released under Apache License 2.0.

Check [LICENSE](LICENSE) file for more information.
