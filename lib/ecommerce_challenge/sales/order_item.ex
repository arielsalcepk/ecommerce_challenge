defmodule EcommerceChallenge.Sales.OrderItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "order_items" do
    field :quantity, :integer
    field :unit_price, :decimal
    field :subtotal, :decimal

    belongs_to :order, EcommerceChallenge.Sales.Order
    belongs_to :product, EcommerceChallenge.Catalog.Product

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(order_item, attrs) do
    order_item
    |> cast(attrs, [:quantity, :unit_price, :subtotal, :order_id, :product_id])
    |> validate_required([:quantity, :unit_price, :subtotal, :order_id, :product_id])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> validate_number(:subtotal, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:order_id)
    |> foreign_key_constraint(:product_id)
  end
end
