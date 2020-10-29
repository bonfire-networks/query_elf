# Basic Usage

Suppose you have a `users` schema that is defined as below:

```elixir
defmodule Accounts.User do
  schema "users" do
    field :email, :string
    field :password_hash, :string

    field :name, :string
    field :is_active, :boolean

    field :signed_up_at, :naive_datetime
  end
end
```

## Basic filtering

Suppose you wish to enable filtering by `email`, `name`, `is_active`, and `signed_up_at`. Then you can define a `QueryBuilder` module as below:

```elixir
defmodule Accounts.User.QueryBuilder do
  use QueryElf,
    schema: Accounts.User,
    searchable_fields: [:email, :name, :is_active, :signed_up_at]
end
```

The `schema` specifies the ecto schema for which the query builder is being created. The `searchable_fields` specifies fields that can be filtered on. With the above definition, you can now use the query builder's capabailities as below:

```elixir
User.QueryBuilder.build_query(email: "a@b.com")
|> Repo.one

User.QueryBuilder.build_query(name__in: ["Raphael Costa", "Jose Valim"])
|> Repo.all()

User.QueryBuilder.build_query(is_active: true)
|> Repo.all()

User.QueryBuilder.build_query(signed_up_at__before: ~N[2000-01-01 23:00:07])
|> Repo.all()
```

You can also combine multiple conditions/filters together:

```elixir
# Conditions are `anded` by default
User.QueryBuilder.build_query(name__in: ["Raphael Costa", "Jose Valim"], is_active: true)
|> Repo.all()

# But you can change to using `or`
User.QueryBuilder.build_query(_or: [name: "Mr A", email: "a@b.com"])
|> Repo.all()

# Or combine them together to create a complex query
User.QueryBuilder.build_query(
  _or: [
    name: "Mr A",
    _and: [
      email__in: ["a@b.com", "a@c.com"],
      is_active: true
    ]
  ]
)
|> Repo.all()
```

For more information about what filters (`__in`, `__before`, etc) are defined for each field type, check the documentation for the `searchable_fields` option [here](`QueryElf`).

## Basic ordering/sorting

Assuming you have the same user schema defined above, suppose you wish to allow sorting users by `name`, `email`, and `signed_up_at`. QueryElf can be used to achieve this as below:

```elixir
defmodule Accounts.User.QueryBuilder do
  use QueryElf,
    schema: Accounts.User,
    searchable_fields: ~w[email name is_active signed_up_at]a,
    sortable_fields: ~w[email name signed_up_at]a
end
```

Then sorting capabilities can be included in `build_query` as below:

```elixir
Accounts.User.QueryBuilder.build_query([],
  order: [%{field: :name, direction: :asc}, %{field: :signed_up_at, direction: :desc}]
)
|> Repo.all()


# Shorthand expression for ordering example above
Accounts.User.QueryBuilder.build_query([],
  order: [asc: :my_int, desc: :my_bool]
)
|> Repo.all()
```
