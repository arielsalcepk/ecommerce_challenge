defmodule EcommerceChallenge.Catalog do
  @moduledoc """
  The Catalog context.
  """

  import Ecto.Query, warn: false
  alias EcommerceChallenge.Repo

  alias EcommerceChallenge.Catalog.Product

  @page_size 20

  @doc "The number of products shown per page in `list_products/1`."
  def page_size, do: @page_size

  @doc """
  Returns a page of products, optionally filtered by a search term matching
  name, sku, or description (case-insensitive). Only the requested page's
  rows are ever fetched from the database.

  ## Examples

      iex> list_products()
      [%Product{}, ...]

      iex> list_products(%{"search" => "mouse", "page" => "2"})
      [%Product{}, ...]

  """
  def list_products(params \\ %{}) do
    page = normalize_page(params["page"])

    Product
    |> search_query(params["search"])
    |> order_by([p], asc: p.name)
    |> limit(^@page_size)
    |> offset(^((page - 1) * @page_size))
    |> Repo.all()
  end

  @doc "Total number of products matching the given search term."
  def count_products(params \\ %{}) do
    Product
    |> search_query(params["search"])
    |> Repo.aggregate(:count)
  end

  @doc "Total number of pages for the given search term, at least 1."
  def total_pages(params \\ %{}) do
    max(ceil(count_products(params) / @page_size), 1)
  end

  @doc "Parses a page param into a positive page number, defaulting to 1."
  def normalize_page(page) when is_integer(page), do: max(page, 1)

  def normalize_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _rest} when n > 0 -> n
      _ -> 1
    end
  end

  def normalize_page(_page), do: 1

  defp search_query(query, search) when search in [nil, ""], do: query

  defp search_query(query, search) do
    pattern = "%#{search}%"

    from p in query,
      where: ilike(p.name, ^pattern) or ilike(p.sku, ^pattern) or ilike(p.description, ^pattern)
  end

  @doc """
  Gets a single product.

  Raises `Ecto.NoResultsError` if the Product does not exist.

  ## Examples

      iex> get_product!(123)
      %Product{}

      iex> get_product!(456)
      ** (Ecto.NoResultsError)

  """
  def get_product!(id), do: Repo.get!(Product, id)

  @doc """
  Creates a product.

  ## Examples

      iex> create_product(%{field: value})
      {:ok, %Product{}}

      iex> create_product(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_product(attrs) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a product.

  ## Examples

      iex> update_product(product, %{field: new_value})
      {:ok, %Product{}}

      iex> update_product(product, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a product.

  ## Examples

      iex> delete_product(product)
      {:ok, %Product{}}

      iex> delete_product(product)
      {:error, %Ecto.Changeset{}}

  """
  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking product changes.

  ## Examples

      iex> change_product(product)
      %Ecto.Changeset{data: %Product{}}

  """
  def change_product(%Product{} = product, attrs \\ %{}) do
    Product.changeset(product, attrs)
  end

  @replace_on_conflict [:name, :description, :category, :price, :stock, :weight_kg, :updated_at]

  @doc """
  Imports products from a CSV file at `path`.

  Products are upserted by `sku` (insert if new, update if the sku already
  exists) so re-importing an updated catalog file is safe and idempotent.
  Each row is validated and inserted independently, so one bad row doesn't
  abort the rest of the file.

  Returns a report: `%{inserted: count, updated: count, skipped: [%{line: line, sku: sku, reasons: [String.t()]}]}`.
  """
  def import_csv(path) do
    existing_skus = Product |> select([p], p.sku) |> Repo.all() |> MapSet.new()

    path
    |> File.read!()
    |> strip_bom()
    |> NimbleCSV.RFC4180.parse_string(skip_headers: false)
    |> rows_with_headers()
    |> Enum.with_index(2)
    |> Enum.reduce(
      %{inserted: 0, updated: 0, skipped: [], seen_skus: existing_skus},
      &import_row/2
    )
    |> Map.take([:inserted, :updated, :skipped])
  end

  defp strip_bom("﻿" <> rest), do: rest
  defp strip_bom(content), do: content

  defp rows_with_headers([headers | rows]) do
    Enum.map(rows, fn row -> headers |> Enum.zip(row) |> Map.new() end)
  end

  defp rows_with_headers([]), do: []

  defp import_row({row, line_no}, acc) do
    attrs = strip_currency_symbols(row)
    changeset = Product.changeset(%Product{}, attrs)

    case Repo.insert(changeset,
           on_conflict: {:replace, @replace_on_conflict},
           conflict_target: :sku,
           returning: true
         ) do
      {:ok, product} ->
        if MapSet.member?(acc.seen_skus, product.sku) do
          %{acc | updated: acc.updated + 1}
        else
          %{acc | inserted: acc.inserted + 1, seen_skus: MapSet.put(acc.seen_skus, product.sku)}
        end

      {:error, changeset} ->
        skipped_row = %{
          line: line_no,
          sku: Map.get(row, "sku"),
          reasons: error_messages(changeset)
        }

        %{acc | skipped: [skipped_row | acc.skipped]}
    end
  end

  defp strip_currency_symbols(row) do
    Map.update(row, "price", "", fn price -> String.replace(price, ~r/[$,]/, "") end)
  end

  defp error_messages(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field} #{&1}") end)
  end
end
