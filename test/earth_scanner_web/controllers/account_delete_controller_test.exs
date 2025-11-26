defmodule EarthScannerWeb.AccountDeleteControllerTest do
  use EarthScannerWeb.ConnCase, async: false
  alias EarthScanner.{Accounts, Repo}
  alias EarthScanner.Accounts.User

  defp register_user!() do
    {:ok, user} =
      Accounts.register_user(%{
        "username" => "zuser",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "Zeynep",
        "last_name" => "Kesim",
        "email" => "zuser@example.com",
        "birthdate" => "2000-01-01",
        "nationality" => "TR",
        "residence_address" => "Somewhere 1",
        "phone_number" => "+905551112233"
      })

    user
  end

  test "requires login to see confirm page", %{conn: conn} do
    conn = get(conn, ~p"/users/delete")
    assert redirected_to(conn) == ~p"/users/login"
  end

  test "renders confirm page when logged in", %{conn: conn} do
    user = register_user!()
    conn = conn |> init_test_session(%{user_id: user.id}) |> get(~p"/users/delete")
    assert html_response(conn, 200) =~ "Delete account"
  end

  test "rejects wrong password", %{conn: conn} do
    user = register_user!()

    conn =
      conn
      |> init_test_session(%{user_id: user.id})
      |> post(~p"/users/delete", %{"delete" => %{"password" => "Wrong!", "confirm" => "yes"}})

    assert redirected_to(conn) == ~p"/users/delete"
    assert get_flash(conn, :error) =~ "Invalid password"
    # user still exists
    assert Repo.get(User, user.id)
  end

  test "deletes account with correct password and logs out", %{conn: conn} do
    user = register_user!()

    conn =
      conn
      |> init_test_session(%{user_id: user.id})
      |> post(~p"/users/delete", %{
        "delete" => %{"password" => "Password123!", "confirm" => "yes"}
      })

    assert redirected_to(conn) == ~p"/"
    assert get_flash(conn, :info) =~ "deleted"
    # user deleted
    refute Repo.get(User, user.id)

    # ensure session is cleared (user logged out)
    # simulate browser following the redirect so cookie/session changes take effect
    conn = recycle(conn) |> get(~p"/")
    assert get_session(conn, :user_id) == nil
  end
end
