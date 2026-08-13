defmodule EcommerceChallenge.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EcommerceChallengeWeb.Telemetry,
      EcommerceChallenge.Repo,
      {DNSCluster,
       query: Application.get_env(:ecommerce_challenge, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EcommerceChallenge.PubSub},
      EcommerceChallengeWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: EcommerceChallenge.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    EcommerceChallengeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
