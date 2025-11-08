defmodule EarthScannerWeb.AdminUserController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Accounts
  alias EarthScanner.Accounts.User

  def new(conn, _params) do
    changeset = User.admin_changeset(%User{}, %{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    creator = conn.assigns.current_user

    case Accounts.create_admin(creator, user_params) do
      {:ok, _admin} ->
        conn
        |> put_flash(:info, "Admin created successfully.")
        |> redirect(to: "/profile")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "Not allowed.")
        |> redirect(to: "/")
    end
  end
end
