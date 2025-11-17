defmodule EarthScanner.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields ~w(username name last_name email birthdate nationality residence_address phone_number)a
  @password_min_len 8

  schema "users" do
    field :username, :string
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true
    field :password_hash, :string
    field :role, :string, default: "user"
    field :name, :string
    field :last_name, :string
    field :email, :string
    field :birthdate, :date
    field :nationality, :string
    field :residence_address, :string
    field :phone_number, :string

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :username,
      :password,
      :password_confirmation,
      :name,
      :last_name,
      :email,
      :birthdate,
      :nationality,
      :residence_address,
      :phone_number
    ])
    |> validate_required(@required_fields ++ [:password])
    |> validate_length(:password, min: @password_min_len)
    |> validate_confirmation(:password)
    |> validate_format(:email, ~r/^\S+@\S+$/)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> maybe_put_password_hash()
  end

  # Hash the password when needed.
  # - If the changeset is valid and has a new :password, set :password_hash.
  # - Otherwise, do nothing.
  defp maybe_put_password_hash(%Ecto.Changeset{valid?: true} = changeset) do
    if password = get_change(changeset, :password) do
      put_change(changeset, :password_hash, Pbkdf2.hash_pwd_salt(password))
    else
      changeset
    end
  end

  defp maybe_put_password_hash(changeset), do: changeset

  def profile_changeset(user, attrs) do
  user
  |> cast(attrs, [
    :username,
    :name,
    :last_name,
    :email,
    :birthdate,
    :nationality,
    :residence_address,
    :phone_number
  ])
  |> validate_required([:username, :email, :name, :last_name])
  |> validate_format(:email, ~r/^[\w._%+-]+@[\w.-]+\.[a-zA-Z]{2,}$/, message: "Invalid email")
  |> validate_format(:phone_number, ~r/^\+?\d{7,15}$/, message: "Phone must contain only digits and optional +")
  |> validate_format(:name, ~r/^[A-Za-z]+$/, message: "Name must contain only letters")
  |> validate_format(:last_name, ~r/^[A-Za-z]+$/, message: "Last name must contain only letters")
  |> unique_constraint(:email)
  |> unique_constraint(:username)
end


  # Changeset for admin creation (simpler than regular user registration)
  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :password, :password_confirmation, :email, :phone_number])
    |> validate_required([:username, :password, :email, :phone_number])
    |> validate_length(:password, min: @password_min_len)
    |> validate_confirmation(:password)
    |> validate_format(:email, ~r/^\S+@\S+$/)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> put_change(:role, "admin")
    |> maybe_put_password_hash()
  end
end
