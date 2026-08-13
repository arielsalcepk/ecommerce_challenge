defmodule EcommerceChallenge.CatalogFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `EcommerceChallenge.Catalog` context.
  """

  @doc """
  Generate a product.
  """
  def product_fixture(attrs \\ %{}) do
    {:ok, product} =
      attrs
      |> Enum.into(%{
        category: "some category",
        description: "some description",
        name: "some name",
        price: "120.5",
        sku: "some sku",
        stock: 42,
        weight_kg: "120.5"
      })
      |> EcommerceChallenge.Catalog.create_product()

    product
  end
end
