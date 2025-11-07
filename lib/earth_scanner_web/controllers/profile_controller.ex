defmodule EarthScannerWeb.ProfileController do
  use EarthScannerWeb, :controller
  alias EarthScanner.Accounts

  def show(conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "Please log in to view your profile")
        |> redirect(to: ~p"/users/login")

      user ->
        render(conn, :show, user: user)
    end
  end

  def edit(conn, _params) do
    user = conn.assigns.current_user
    changeset = Accounts.User.profile_changeset(user, %{})
    render(conn, :edit, form: Phoenix.Component.to_form(changeset), user: user)
  end

  def update(conn, %{"user" => user_params}) do
    user = conn.assigns[:current_user]

    case Accounts.update_user(user, user_params) do
      {:ok, updated_user} ->
        conn
        |> put_flash(:info, "Profile updated successfully")
        |> redirect(to: ~p"/profile")

      {:error, changeset} ->
        render(conn, :edit, form: Phoenix.Component.to_form(changeset), user: user)
    end
  end
end
