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

  # FR-05: Change password
  def change_password(%User{} = user, current_password, new_password, new_password_confirmation)
      when is_binary(current_password) and is_binary(new_password) and
             is_binary(new_password_confirmation) do
    # Step 1: Verify the current password is correct
    cond do
      is_nil(user.password_hash) ->
        {:error, :no_password_set}

      not Pbkdf2.verify_pass(current_password, user.password_hash) ->
        {:error, :invalid_current_password}

      new_password != new_password_confirmation ->
        {:error, :password_confirmation_mismatch}

      String.length(new_password) < 8 ->
        {:error, :password_too_short}

      true ->
        # Step 2: Update the password
        user
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_change(:password_hash, Pbkdf2.hash_pwd_salt(new_password))
        |> Repo.update()
    end
  end

  # FR-02: Admin creation (controlled)
  # Only existing admins can create new admins
  def create_admin(%User{role: "admin"} = _creator, attrs) when is_map(attrs) do
    %User{}
    |> User.admin_changeset(attrs)
    |> Repo.insert()
  end

  # If a non-admin tries to create an admin, return error
  def create_admin(%User{role: role}, _attrs) when role != "admin" do
    {:error, :unauthorized}
  end
end
