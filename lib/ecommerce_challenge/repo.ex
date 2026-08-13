defmodule EcommerceChallenge.Repo do
  use Ecto.Repo,
    otp_app: :ecommerce_challenge,
    adapter: Ecto.Adapters.Postgres
end
