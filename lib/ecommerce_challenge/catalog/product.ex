defmodule EcommerceChallenge.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:name, :sku, :price, :stock]
  @optional_fields [:description, :category, :weight_kg]

  schema "products" do
    field :name, :string
    field :sku, :string
    field :description, :string
    field :category, :string
    field :price, :decimal
    field :stock, :integer
    field :weight_kg, :decimal

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> update_change(:name, &normalize_string/1)
    |> update_change(:sku, &normalize_string/1)
    |> normalize_category()
    |> validate_required(@required_fields)
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:stock, greater_than_or_equal_to: 0)
    |> unique_constraint(:sku)
    |> check_constraint(:price, name: :price_must_be_non_negative)
    |> check_constraint(:stock, name: :stock_must_be_non_negative)
  end

  defp normalize_string(value) when is_binary(value), do: String.trim(value)
  defp normalize_string(value), do: value

  defp normalize_category(changeset) do
    category =
      case get_field(changeset, :category) do
        nil -> nil
        value -> String.trim(value)
      end

    case category do
      value when value in [nil, ""] -> put_change(changeset, :category, "Uncategorized")
      value -> put_change(changeset, :category, value)
    end
  end
end
