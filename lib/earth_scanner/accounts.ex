defmodule EarthScanner.Accounts do
  import Ecto.Query, warn: false
  alias EarthScanner.Repo
  alias EarthScanner.Accounts.User

  def register_user(attrs) when is_map(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_id(id) when is_integer(id) do
    Repo.get(User, id)
  end

  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    with %User{} = user <- get_user_by_email(email),
         true <- not is_nil(user.password_hash),
         true <- Pbkdf2.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      _ -> {:error, :invalid_credentials}
    end
  end

  def delete_user(%User{} = user, password) when is_binary(password) do
  cond do
    is_nil(user.password_hash) ->
      {:error, :not_reauthenticated}

    Pbkdf2.verify_pass(password, user.password_hash) ->
      case Repo.delete(user) do
        {:ok, _} -> {:ok, :deleted}
        {:error, changeset} -> {:error, changeset}
      end

    true ->
      {:error, :invalid_password}
  end
end
end
