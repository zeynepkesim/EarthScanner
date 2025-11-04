defmodule EarthScanner.Accounts do

  import Ecto.Query, warn: false
  alias EarthScanner.Repo
  alias EarthScanner.Accounts.User

  def register_user(attrs) when is_map(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end
end
