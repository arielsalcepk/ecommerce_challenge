defmodule EcommerceChallenge.Sales.Order do
  use Ecto.Schema
  import Ecto.Changeset

  schema "orders" do
    field :status, :string
    field :total_amount, :decimal

    has_many :order_items, EcommerceChallenge.Sales.OrderItem

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [:status, :total_amount])
    |> validate_required([:status, :total_amount])
    |> validate_number(:total_amount, greater_than_or_equal_to: 0)
  end
end
