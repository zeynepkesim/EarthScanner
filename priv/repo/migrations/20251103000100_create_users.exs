defmodule EarthScanner.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :username, :string, null: false
      add :password_hash, :string, null: false
      add :name, :string, null: false
      add :last_name, :string, null: false
      add :email, :string, null: false
      add :birthdate, :date, null: false
      add :nationality, :string, null: false
      add :residence_address, :string, null: false
      add :phone_number, :string, null: false

      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
  end
end
