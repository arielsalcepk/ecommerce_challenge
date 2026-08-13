defmodule EcommerceChallenge.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :name, :string, null: false
      add :sku, :string, null: false
      add :description, :text
      add :category, :string
      add :price, :decimal, null: false
      add :stock, :integer, null: false
      add :weight_kg, :decimal

      timestamps(type: :utc_datetime)
    end

    create unique_index(:products, [:sku])

    create constraint(:products, :price_must_be_non_negative, check: "price >= 0")
    create constraint(:products, :stock_must_be_non_negative, check: "stock >= 0")
  end
end
