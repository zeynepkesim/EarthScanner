defmodule EarthScanner.Repo.Migrations.MakeNameFieldsOptionalForAdmins do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :name, :string, null: true
      modify :last_name, :string, null: true
      modify :birthdate, :date, null: true
      modify :nationality, :string, null: true
      modify :residence_address, :string, null: true
    end
  end
end
