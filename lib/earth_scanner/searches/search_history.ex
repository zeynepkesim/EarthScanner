defmodule EarthScanner.Searches.SearchHistory do
  use Ecto.Schema
  import Ecto.Changeset

  alias EarthScanner.Accounts.User

  schema "search_histories" do
    field :source_city, :string
    field :destination_city, :string
    belongs_to :user, User

    timestamps(updated_at: false)
  end

  @required_fields ~w(source_city destination_city user_id)a

  def changeset(search, attrs) do
    search
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:user_id)
  end
end
