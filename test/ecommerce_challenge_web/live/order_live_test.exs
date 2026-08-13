defmodule EcommerceChallengeWeb.OrderLiveTest do
  use EcommerceChallengeWeb.ConnCase

  import Phoenix.LiveViewTest
  import EcommerceChallenge.CatalogFixtures

  alias EcommerceChallenge.Sales

  test "displays the order's line items and total", %{conn: conn} do
    product = product_fixture(%{name: "Mug", price: "9.99", stock: 10})
    {:ok, order} = Sales.purchase(product.id, 2)

    {:ok, _order_live, html} = live(conn, ~p"/orders/#{order}")

    assert html =~ "Order confirmed"
    assert html =~ "Mug"
    assert html =~ "completed"
  end
end
