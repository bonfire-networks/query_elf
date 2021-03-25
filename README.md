# QueryElf (with extra wings)

> A helper to build the most common database queries for [Ecto](https://hexdocs.pm/ecto/Ecto.html).

This QueryElf library was originally forked from [UpLearn](https://gitlab.com/up-learn-uk/query-elf)

Some changes were made as needed for usage in [Bonfire](http://bonfire.cafe) and it bundles the following plugins:
- [`Preloader`](#preloader-documentation)
- [`ReusableJoin`](#reusablejoin-documentation)


## QueryElf Usage

QueryElf helps to build and extend the common database queries for Ecto. It provides an elegant way of building complex Ecto queries using query composition. While it supports search, sort and paginate operations, it also allows extending the query builder using custom plugins. 

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

MyQueryBuilder.build_query(id: [1, 2, 3], my_extra_filter: 10)
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

  QB.build_query(id__eq: 1)
  QB.build_query(id: 1) # shorthand

  QB.build_query(id__neq: 1)

  QB.build_query(id__in: [1, 2])
  QB.build_query(id: [1, 2]) # shorthand

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

```

API documentation for the upstream QueryElf is available at [HexDocs](https://hexdocs.pm/query_elf/api-reference.html)



## Preloader Documentation

The `join_preload` macro tells Ecto to perform a join and preload of (up to three nested levels of) associations.

So instead of having to write: 
```elixir
    query
    |> join(:left, [o, activity: activity], assoc(:my_like), as: :my_like)
    |> preload([l, activity: activity, my_like: my_like], activity: {activity, [my_like: my_like]})
```

One can simply write:
```elixir
    query
    |> join_preload([:activity, :my_like]
```

`join_preload` automatically makes use of `reusable_join` so calling it multiple times for the same association has no ill effects.


## ReusableJoin Documentation

The `reusable_join` macro is similar to `Ecto.Query.join/{4,5}`, but can be called multiple times 
with the same alias.

Note that only the first join operation is performed, the subsequent ones that use the same alias
are just ignored. Also note that because of this behaviour, its mandatory to specify an alias when
using this function.

This is helpful when you need to perform a join while building queries one filter at a time,
because the same filter could be used multiple times or you could have multiple filters that
require the same join, which poses a problem with how the `filter/3` callback work, as you
need to return a dynamic with the filtering, which means that the join must have an alias,
and by default Ecto raises an error when you add multiple joins with the same alias.

To solve this, it is recommended to use this macro instead of the default `Ecto.Query.join/{4,5}`,
in which case there will be only one join in the query that can be reused by multiple filters.

### Creating reusable joins
```elixir
query
|> reusable_join(:left, [t1], t2 in "other_table", on: t1.id == t2.id, as: :other_a)
|> reusable_join(:left, [t1], t2 in "other_table", on: t1.id == t2.id, as: :other_b)
```


## Running tests

Clone the repo and fetch its dependencies:

```bash
mix deps.get
mix test
```

## Contributing

We appreciate any contribution directly or to the upstream QueryElf. Check their [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), [CONTRIBUTING.md](CONTRIBUTING.md) guides, and [issue tracker](https://gitlab.com/up-learn-uk/query-elf/issues).

## Copyright and License

Copyright (c) 2020 Up Learn
Copyright (c) 2021 Bonfire

Query Elf source code is released under Apache License 2.0.

Check [LICENSE](LICENSE) file for more information.
