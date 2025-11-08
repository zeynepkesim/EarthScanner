defmodule EarthScannerWeb.UserRegistrationController do
  use EarthScannerWeb, :controller
  alias EarthScanner.Accounts
  alias EarthScanner.Accounts.User

  def new(conn, _params) do
    changeset = User.registration_changeset(%User{}, %{})
    render(conn, :new, form: Phoenix.Component.to_form(changeset))
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Account created successfully. Please sign in.")
        |> redirect(to: ~p"/users/login")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:ok)
        |> render(:new,
          form: Phoenix.Component.to_form(changeset),
          error: "Please fix the errors below and try again."
        )
    end
  end

  # Legacy helpers replaced by proper changeset validations
end
