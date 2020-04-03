# Advanced Usage

Suppose you have a `users` schema that is defined as below:

```elixir
defmodule Accounts.User do
  schema "users" do
    field :email, :string
    field :password_hash, :string

    field :name, :string
    field :is_active, :boolean

    field :signed_up_at, :naive_datetime
    field :last_logged_in_at, :naive_datetime
  end
end
```

Then a basic filtering and ordering query builder can be defined as:

```elixir
defmodule Accounts.User.QueryBuilder do
  use QueryElf,
    schema: Accounts.User,
    searchable_fields: ~w[email name is_active signed_up_at]a,
    sortable_fields: ~w[email name signed_up_at]a
end
```

Where filtering is possible on `email`, `name`, `is_active`, and `signed_up_at`, and sorting is possible on `email`, `name`, and `signed_up_at`. If this is confusing for you, it would be a good idea to read through the basic usage documentation.

## Defining custom filters

Suppose you wish to implement a custom filter to identify recently active users defined as users that logged in in the last `n` days. You can define and use such a filter as below:

```elixir
defmodule Accounts.User.QueryBuilder do
  use QueryElf,
    schema: Accounts.User,
    searchable_fields: ~w[email name is_active signed_up_at]a,
    sortable_fields: ~w[email name signed_up_at]a

  def filter(:active_in_last_days, days, _query) do
    earliest_logged_in_at =
      NaiveDateTime.add(
        NaiveDateTime.utc_now(),
        days * 24 * 3600 * -1,
        :second
      )

    dynamic([u], u.last_logged_in_at > ^earliest_logged_in_at)
  end
end

Accounts.User.QueryBuilder.build_query(active_in_last_days: 30)
|> Repo.all()
```

Suppose you also have a notification preferences schema and a foriegn key from users schema to the preferences schema and you want to implement custom filters to identify recently active users that are happy to receive newsletters, then that can be achieved as below:

```elixir
defmodule Accounts.User do
  schema "users" do
    field :email, :string
    field :password_hash, :string

    field :name, :string
    field :is_active, :boolean

    field :signed_up_at, :naive_datetime
    field :last_logged_in_at, :naive_datetime

    has_one :notification_preferences, NotificationPreferences
  end
end

defmodule Accounts.NotificationPreferences do
  schema "notification_preferences" do
    field :send_product_updates, :boolean
    field :send_newsletters, :boolean
  end
end

defmodule Accounts.User.QueryBuilder do
  use QueryElf,
    schema: Accounts.User,
    searchable_fields: ~w[email name is_active signed_up_at]a,
    sortable_fields: ~w[email name signed_up_at]a

  def filter(:active_in_last_days, days, _query) do
    earliest_logged_in_at =
      NaiveDateTime.add(
        NaiveDateTime.utc_now(),
        days * 24 * 3600 * -1,
        :second
      )

    dynamic([u], u.last_logged_in_at > ^earliest_logged_in_at)
  end

  def filter(:accepts_newsletters, value, query) do
    {
      # Use reusable_join instead of join as explained in the next section
      join(query, assoc(r, :notification_preferences), as: :preferences),
      dynamic([preferences: p], p.send_newsletters == ^value)
    }
  end
end

Accounts.User.QueryBuilder.build_query(active_in_last_days: 30, accepts_newsletters: true)
|> Repo.all()
```

## Using reusable joins

Given the module definition of `User.QueryBuilder` above, if you wrote the following query:

```elixir
Accounts.User.QueryBuilder.build_query(
  _or: [
    accepts_newsletters: true,
    _and: [active_in_last_days: 5, accepts_newsletters: false]
  ]
)
```

Then ecto with throw an error as it would result in two named joins having the same name. This is because both `accepts_newsletters: true` and `accepts_newsletters: false` add a join each between `users` and `notification_preferences` with the name `preferences` and ecto doesn't allow two joins with the same name.

What you really want is that a single join is added to the query as they both are essentially the same join. This is achieved by the `reusable_join` macro.

```elixir
import QueryElf

defmodule Accounts.User.QueryBuilder do
  use QueryElf,
    schema: Accounts.User,
    searchable_fields: ~w[email name is_active signed_up_at]a,
    sortable_fields: ~w[email name signed_up_at]a

  def filter(:accepts_newsletters, value, query) do
    {
      reusable_join(query, assoc(r, :notification_preferences), as: :preferences),
      dynamic([preferences: p], p.send_newsletters == ^value)
    }
  end
end
```

Internally, the `reusable_join` macro checks if a join with the same name has already been added to the query and if so it skips adding the join. Thus, if you have two custom filters that should be using the same join, you can ensure that happens by giving the joins in the filters the same name.

For example, suppose you want to implement custom filters to allow fetching users that are happy to receive newsletters and product updates. In this case, you would need to build two different filters so that they can be used independently and also be combined. But you want to ensure that when combined, the filters use a single join instead of multiple joins on `users` and `notification_preferences`. This is achieved by using `reusable_join` with the same join name in both the custom filters.

```elixir
defmodule Accounts.User.QueryBuilder do
  use QueryElf,
    schema: Accounts.User,
    searchable_fields: ~w[email name is_active signed_up_at]a,
    sortable_fields: ~w[email name signed_up_at]a

  def filter(:accepts_newsletters, value, query) do
    {
      reusable_join(query, assoc(r, :notification_preferences), as: :preferences),
      dynamic([preferences: p], p.send_newsletters == ^value)
    }
  end

  def filter(:accepts_product_updates, value, query) do
    {
      reusable_join(query, assoc(r, :notification_preferences), as: :preferences),
      dynamic([preferences: p], p.send_product_updates == ^value)
    }
  end
end

Accounts.User.QueryBuilder.build_query(accepts_newsletters: true)
|> Repo.all()

Accounts.User.QueryBuilder.build_query(accepts_product_updates: true)
|> Repo.all()

Accounts.User.QueryBuilder.build_query(accepts_newsletters: true, accepts_product_updates: true)
|> Repo.all()
```
