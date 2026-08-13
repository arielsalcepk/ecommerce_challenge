defmodule EcommerceChallenge.CatalogTest do
  use EcommerceChallenge.DataCase

  alias EcommerceChallenge.Catalog

  describe "products" do
    alias EcommerceChallenge.Catalog.Product

    import EcommerceChallenge.CatalogFixtures

    @invalid_attrs %{
      name: nil,
      description: nil,
      category: nil,
      sku: nil,
      price: nil,
      stock: nil,
      weight_kg: nil
    }

    test "list_products/0 returns all products" do
      product = product_fixture()
      assert Catalog.list_products() == [product]
    end

    test "get_product!/1 returns the product with given id" do
      product = product_fixture()
      assert Catalog.get_product!(product.id) == product
    end

    test "create_product/1 with valid data creates a product" do
      valid_attrs = %{
        name: "some name",
        description: "some description",
        category: "some category",
        sku: "some sku",
        price: "120.5",
        stock: 42,
        weight_kg: "120.5"
      }

      assert {:ok, %Product{} = product} = Catalog.create_product(valid_attrs)
      assert product.name == "some name"
      assert product.description == "some description"
      assert product.category == "some category"
      assert product.sku == "some sku"
      assert product.price == Decimal.new("120.5")
      assert product.stock == 42
      assert product.weight_kg == Decimal.new("120.5")
    end

    test "create_product/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_product(@invalid_attrs)
    end

    test "update_product/2 with valid data updates the product" do
      product = product_fixture()

      update_attrs = %{
        name: "some updated name",
        description: "some updated description",
        category: "some updated category",
        sku: "some updated sku",
        price: "456.7",
        stock: 43,
        weight_kg: "456.7"
      }

      assert {:ok, %Product{} = product} = Catalog.update_product(product, update_attrs)
      assert product.name == "some updated name"
      assert product.description == "some updated description"
      assert product.category == "some updated category"
      assert product.sku == "some updated sku"
      assert product.price == Decimal.new("456.7")
      assert product.stock == 43
      assert product.weight_kg == Decimal.new("456.7")
    end

    test "update_product/2 with invalid data returns error changeset" do
      product = product_fixture()
      assert {:error, %Ecto.Changeset{}} = Catalog.update_product(product, @invalid_attrs)
      assert product == Catalog.get_product!(product.id)
    end

    test "delete_product/1 deletes the product" do
      product = product_fixture()
      assert {:ok, %Product{}} = Catalog.delete_product(product)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_product!(product.id) end
    end

    test "change_product/1 returns a product changeset" do
      product = product_fixture()
      assert %Ecto.Changeset{} = Catalog.change_product(product)
    end
  end

  describe "search and pagination" do
    import EcommerceChallenge.CatalogFixtures

    test "list_products/1 filters by name, sku, or description (case-insensitive)" do
      product_fixture(%{name: "Wireless Mouse", sku: "WM-042", description: "USB receiver"})
      product_fixture(%{name: "Leather Wallet", sku: "LW-019", description: "RFID blocking"})

      assert [%{name: "Wireless Mouse"}] = Catalog.list_products(%{"search" => "mouse"})
      assert [%{name: "Wireless Mouse"}] = Catalog.list_products(%{"search" => "WM-042"})
      assert [%{name: "Wireless Mouse"}] = Catalog.list_products(%{"search" => "receiver"})
      assert Catalog.list_products(%{"search" => "nonexistent"}) == []
    end

    test "list_products/1 paginates at the database level" do
      for n <- 1..21 do
        product_fixture(%{
          name: "Product #{String.pad_leading(to_string(n), 2, "0")}",
          sku: "P-#{n}"
        })
      end

      page_1 = Catalog.list_products(%{"page" => "1"})
      page_2 = Catalog.list_products(%{"page" => "2"})

      assert length(page_1) == 20
      assert length(page_2) == 1
      assert Catalog.total_pages() == 2
      assert Catalog.count_products() == 21
    end

    test "normalize_page/1 defaults invalid or missing values to 1" do
      assert Catalog.normalize_page(nil) == 1
      assert Catalog.normalize_page("") == 1
      assert Catalog.normalize_page("abc") == 1
      assert Catalog.normalize_page("-1") == 1
      assert Catalog.normalize_page("0") == 1
      assert Catalog.normalize_page("3") == 3
    end
  end

  describe "import_csv/1" do
    import EcommerceChallenge.CatalogFixtures

    @csv_headers "name,sku,description,category,price,stock,weight_kg\n"

    defp import_csv_body(csv_body) do
      path = Path.join(System.tmp_dir!(), "import_test_#{System.unique_integer([:positive])}.csv")
      File.write!(path, @csv_headers <> csv_body)

      try do
        Catalog.import_csv(path)
      after
        File.rm!(path)
      end
    end

    test "imports a well-formed row" do
      report = import_csv_body(~s|Mug,MUG-1,A mug,Kitchen,9.99,10,0.3\n|)

      assert report.inserted == 1
      assert report.updated == 0
      assert report.skipped == []
      assert [%{name: "Mug", price: price}] = Catalog.list_products()
      assert Decimal.equal?(price, Decimal.new("9.99"))
    end

    test "strips a $ prefix and commas from price" do
      report = import_csv_body(~s|Desk,DSK-1,A desk,Office,"$1,299.99",5,20.0\n|)

      assert report.inserted == 1
      assert [%{price: price}] = Catalog.list_products()
      assert Decimal.equal?(price, Decimal.new("1299.99"))
    end

    test "rejects a non-numeric price like \"free\"" do
      report = import_csv_body(~s|Sample,SMP-1,A sample,Misc,free,10,0.1\n|)

      assert report.inserted == 0
      assert [%{line: 2, sku: "SMP-1", reasons: reasons}] = report.skipped
      assert Enum.any?(reasons, &(&1 =~ "price"))
      assert Catalog.list_products() == []
    end

    test "rejects negative stock" do
      report = import_csv_body(~s|Lamp,LMP-1,A lamp,Home,10.00,-5,1.0\n|)

      assert report.inserted == 0
      assert [%{sku: "LMP-1", reasons: reasons}] = report.skipped
      assert Enum.any?(reasons, &(&1 =~ "stock"))
    end

    test "rejects a blank name" do
      report = import_csv_body(~s|,SKU-1,Description,Cat,10.00,5,1.0\n|)

      assert report.inserted == 0
      assert [%{reasons: reasons}] = report.skipped
      assert Enum.any?(reasons, &(&1 =~ "name"))
    end

    test "rejects a whitespace-only name" do
      report = import_csv_body(~s|"   ",SKU-1,Description,Cat,10.00,5,1.0\n|)

      assert report.inserted == 0
      assert [%{reasons: reasons}] = report.skipped
      assert Enum.any?(reasons, &(&1 =~ "name"))
    end

    test "defaults a blank category to Uncategorized" do
      import_csv_body(~s|Gift Card,GC-1,A gift card,,25.00,999,0\n|)

      assert [%{category: "Uncategorized"}] = Catalog.list_products()
    end

    test "skips a fully blank row" do
      report = import_csv_body(~s|,,,,,,\n|)

      assert report.inserted == 0
      assert [%{reasons: reasons}] = report.skipped
      assert length(reasons) > 1
    end

    test "upserts by sku: a sku repeated in the same file keeps only the last occurrence" do
      report =
        import_csv_body("""
        Speaker,BS-1,Old description,Electronics,50.00,100,0.5
        Speaker,BS-1,New description,Electronics,45.00,90,0.5
        """)

      assert report.inserted == 1
      assert report.updated == 1
      assert [%{description: "New description", stock: 90}] = Catalog.list_products()
    end

    test "re-importing the same file is idempotent and reports updates, not inserts" do
      csv = ~s|Mug,MUG-1,A mug,Kitchen,9.99,10,0.3\n|

      first = import_csv_body(csv)
      second = import_csv_body(csv)

      assert first.inserted == 1
      assert first.updated == 0
      assert second.inserted == 0
      assert second.updated == 1
      assert Catalog.count_products() == 1
    end

    test "stores an XSS-style name safely as literal text" do
      import_csv_body(~s|"<script>alert('xss')</script>",XSS-1,desc,Misc,1.00,1,0.1\n|)

      assert [%{name: "<script>alert('xss')</script>"}] = Catalog.list_products()
    end

    test "stores a SQL-injection-style name safely and doesn't affect other data" do
      product_fixture(%{name: "Untouched Product", sku: "SAFE-1"})

      import_csv_body(~s|"Robert'); DROP TABLE products;--",SQL-1,desc,Misc,1.00,1,0.1\n|)

      assert Catalog.count_products() == 2
      assert Enum.any?(Catalog.list_products(), &(&1.sku == "SAFE-1"))
    end

    test "strips a leading UTF-8 BOM before parsing headers" do
      path = Path.join(System.tmp_dir!(), "bom_test_#{System.unique_integer([:positive])}.csv")
      File.write!(path, "﻿" <> @csv_headers <> ~s|Mug,MUG-1,A mug,Kitchen,9.99,10,0.3\n|)

      report =
        try do
          Catalog.import_csv(path)
        after
          File.rm!(path)
        end

      assert report.inserted == 1
      assert report.skipped == []
    end
  end
end
