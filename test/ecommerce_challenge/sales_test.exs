defmodule EcommerceChallenge.SalesTest do
  use EcommerceChallenge.DataCase

  alias EcommerceChallenge.Repo
  alias EcommerceChallenge.Sales
  alias EcommerceChallenge.Sales.Order

  import EcommerceChallenge.CatalogFixtures

  describe "purchase/2" do
    test "decrements stock, creates a completed order and a matching line item" do
      product = product_fixture(%{price: "10.00", stock: 5})

      assert {:ok, %Order{} = order} = Sales.purchase(product.id, 2)

      assert order.status == "completed"
      assert Decimal.equal?(order.total_amount, Decimal.new("20.00"))

      [item] = order.order_items
      assert item.product_id == product.id
      assert item.quantity == 2
      assert Decimal.equal?(item.unit_price, Decimal.new("10.00"))
      assert Decimal.equal?(item.subtotal, Decimal.new("20.00"))

      updated_product = Repo.get!(EcommerceChallenge.Catalog.Product, product.id)
      assert updated_product.stock == 3
    end

    test "returns :insufficient_stock and changes nothing when stock is too low" do
      product = product_fixture(%{stock: 1})

      assert {:error, :insufficient_stock} = Sales.purchase(product.id, 2)

      updated_product = Repo.get!(EcommerceChallenge.Catalog.Product, product.id)
      assert updated_product.stock == 1
      assert Repo.aggregate(Order, :count) == 0
    end

    test "returns :insufficient_stock for a product id that doesn't exist" do
      assert {:error, :insufficient_stock} = Sales.purchase(-1, 1)
    end

    test "concurrent purchases against the same limited stock never oversell" do
      product = product_fixture(%{stock: 1})
      Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

      results =
        1..5
        |> Enum.map(fn _ -> Task.async(fn -> Sales.purchase(product.id, 1) end) end)
        |> Task.await_many()

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &match?({:error, :insufficient_stock}, &1)) == 4

      updated_product = Repo.get!(EcommerceChallenge.Catalog.Product, product.id)
      assert updated_product.stock == 0
    end
  end
end
