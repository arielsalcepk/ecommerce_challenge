defmodule EcommerceChallengeWeb.ProductLiveTest do
  use EcommerceChallengeWeb.ConnCase

  import Phoenix.LiveViewTest
  import EcommerceChallenge.CatalogFixtures

  @create_attrs %{
    name: "some name",
    description: "some description",
    category: "some category",
    sku: "some other sku",
    price: "120.5",
    stock: 42,
    weight_kg: "120.5"
  }
  @update_attrs %{
    name: "some updated name",
    description: "some updated description",
    category: "some updated category",
    sku: "some updated sku",
    price: "456.7",
    stock: 43,
    weight_kg: "456.7"
  }
  @invalid_attrs %{
    name: nil,
    description: nil,
    category: nil,
    sku: nil,
    price: nil,
    stock: nil,
    weight_kg: nil
  }
  defp create_product(_) do
    product = product_fixture()

    %{product: product}
  end

  describe "Index" do
    setup [:create_product]

    test "lists all products", %{conn: conn, product: product} do
      {:ok, _index_live, html} = live(conn, ~p"/products")

      assert html =~ "Listing Products"
      assert html =~ product.name
    end

    test "saves new product", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Product")
               |> render_click()
               |> follow_redirect(conn, ~p"/products/new")

      assert render(form_live) =~ "New Product"

      assert form_live
             |> form("#product-form", product: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#product-form", product: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/products")

      html = render(index_live)
      assert html =~ "Product created successfully"
      assert html =~ "some name"
    end

    test "updates product in listing", %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#products-#{product.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/products/#{product}/edit")

      assert render(form_live) =~ "Edit Product"

      assert form_live
             |> form("#product-form", product: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#product-form", product: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/products")

      html = render(index_live)
      assert html =~ "Product updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes product in listing", %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      assert index_live |> element("#products-#{product.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#products-#{product.id}")
    end

    test "filters products by search term", %{conn: conn} do
      product_fixture(%{name: "Wireless Mouse", sku: "WM-042"})
      product_fixture(%{name: "Leather Wallet", sku: "LW-019"})

      {:ok, index_live, _html} = live(conn, ~p"/products")

      html =
        index_live
        |> form("#search-form", %{"search" => "mouse"})
        |> render_change()

      assert html =~ "Wireless Mouse"
      refute html =~ "Leather Wallet"
    end

    test "paginates results", %{conn: conn} do
      for n <- 1..21 do
        product_fixture(%{name: "Product #{n}", sku: "P-#{n}"})
      end

      {:ok, index_live, html} = live(conn, ~p"/products")
      assert html =~ "Page 1 of"

      html = index_live |> element("a", "Next") |> render_click()

      assert html =~ "Page 2 of"
    end

    test "imports products from a CSV file and shows the report", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/products")

      csv =
        "name,sku,description,category,price,stock,weight_kg\nMug,MUG-1,A mug,Kitchen,9.99,10,0.3\n"

      file =
        file_input(index_live, "#csv-import-form", :csv, [
          %{
            name: "products.csv",
            content: csv,
            type: "text/csv"
          }
        ])

      assert render_upload(file, "products.csv") =~ "100%"

      html =
        index_live
        |> form("#csv-import-form")
        |> render_submit()

      assert html =~ "1 inserted, 0 updated, 0 skipped"
      assert html =~ "Mug"
    end
  end

  describe "Show" do
    setup [:create_product]

    test "displays product", %{conn: conn, product: product} do
      {:ok, _show_live, html} = live(conn, ~p"/products/#{product}")

      assert html =~ "Show Product"
      assert html =~ product.name
    end

    test "updates product and returns to show", %{conn: conn, product: product} do
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/products/#{product}/edit?return_to=show")

      assert render(form_live) =~ "Edit Product"

      assert form_live
             |> form("#product-form", product: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#product-form", product: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/products/#{product}")

      html = render(show_live)
      assert html =~ "Product updated successfully"
      assert html =~ "some updated name"
    end

    test "buying a product decrements stock and redirects to the order confirmation", %{
      conn: conn,
      product: product
    } do
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      assert {:ok, _order_live, html} =
               show_live
               |> form("#buy-form", %{"quantity" => "2"})
               |> render_submit()
               |> follow_redirect(conn)

      assert html =~ "Order confirmed"
      assert html =~ product.name

      assert EcommerceChallenge.Catalog.get_product!(product.id).stock == product.stock - 2
    end

    test "shows an error when the requested quantity exceeds available stock", %{conn: conn} do
      product = product_fixture(%{stock: 1, sku: "low-stock-sku"})
      {:ok, show_live, _html} = live(conn, ~p"/products/#{product}")

      html =
        show_live
        |> form("#buy-form", %{"quantity" => "5"})
        |> render_submit()

      assert html =~ "Not enough stock"
    end
  end
end
