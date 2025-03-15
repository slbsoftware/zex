defmodule Zex.Repo do
  use Ecto.Repo,
    otp_app: :zex,
    adapter: Ecto.Adapters.Postgres
end
