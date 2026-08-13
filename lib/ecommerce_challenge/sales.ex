defmodule EcommerceChallenge.Sales do
  @moduledoc """
  The Sales context. Handles purchasing products with a concurrency-safe,
  atomic stock decrement (payment itself is faked - there is no real
  payment provider integration).
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias EcommerceChallenge.Repo
  alias EcommerceChallenge.Catalog.Product
  alias EcommerceChallenge.Sales.{Order, OrderItem}

  @doc """
  Gets a single order, preloaded with its line items and each item's product.

  Raises `Ecto.NoResultsError` if the Order does not exist.
  """
  def get_order!(id) do
    Order
    |> Repo.get!(id)
    |> Repo.preload(order_items: :product)
  end

  @doc """
  Purchases `quantity` units of the product identified by `product_id`.

  Atomically decrements stock, creates the order and its single line item,
  and marks the order completed (payment is faked - always succeeds once
  stock is confirmed available). Returns `{:error, :insufficient_stock}`
  if the product doesn't have enough stock at the moment of purchase - safe
  under concurrent purchases of the same product, since the stock decrement
  is a single guarded SQL UPDATE.
  """
  def purchase(product_id, quantity) when is_integer(quantity) and quantity > 0 do
    Multi.new()
    |> Multi.run(:product, fn repo, _changes -> decrement_stock(repo, product_id, quantity) end)
    |> Multi.insert(:order, fn %{product: product} -> order_changeset(product, quantity) end)
    |> Multi.insert(:order_item, fn %{order: order, product: product} ->
      order_item_changeset(order, product, quantity)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{order: order}} -> {:ok, get_order!(order.id)}
      {:error, :product, :insufficient_stock, _changes} -> {:error, :insufficient_stock}
      {:error, _step, changeset, _changes} -> {:error, changeset}
    end
  end

  defp decrement_stock(repo, product_id, quantity) do
    {count, rows} =
      Product
      |> where([p], p.id == ^product_id and p.stock >= ^quantity)
      |> select([p], p)
      |> repo.update_all(inc: [stock: -quantity])

    case {count, rows} do
      {1, [product]} -> {:ok, product}
      {0, _rows} -> {:error, :insufficient_stock}
    end
  end

  defp order_changeset(product, quantity) do
    Order.changeset(%Order{}, %{
      status: "completed",
      total_amount: Decimal.mult(product.price, quantity)
    })
  end

  defp order_item_changeset(order, product, quantity) do
    OrderItem.changeset(%OrderItem{}, %{
      order_id: order.id,
      product_id: product.id,
      quantity: quantity,
      unit_price: product.price,
      subtotal: Decimal.mult(product.price, quantity)
    })
  end
end
