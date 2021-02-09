import Config

config :query_elf, :id_types, [:id, :binary_id]

if Mix.env() == :dev do
  config :mix_test_watch,
    clear: true,
    tasks: ["test --cover", "credo"]
end
