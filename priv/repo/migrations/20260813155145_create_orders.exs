defmodule EcommerceChallenge.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add :status, :string, null: false
      add :total_amount, :decimal, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
