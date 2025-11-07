defmodule EarthScannerWeb.ProfileControllerTest do
  use EarthScannerWeb.ConnCase, async: true

  alias EarthScanner.Accounts

  test "redirects to login when not authenticated", %{conn: conn} do
  conn = get(conn, ~p"/profile")
  assert redirected_to(conn) == ~p"/users/login"
  assert get_flash(conn, :error) =~ "Please log in"
end


  test "renders profile with user info when logged in", %{conn: conn} do
    uniq = Integer.to_string(System.unique_integer([:positive]))
    email = "profile" <> uniq <> "@example.com"

    {:ok, _user} =
      Accounts.register_user(%{
        "username" => "prof_user_" <> uniq,
        "password" => "verylongpassword",
        "password_confirmation" => "verylongpassword",
        "name" => "Eve",
        "last_name" => "Ada",
        "email" => email,
        "birthdate" => "1992-02-02",
        "nationality" => "ID",
        "residence_address" => "Jl. Profile 1",
        "phone_number" => "+620000000002"
      })

    conn =
      conn
      |> post(~p"/users/login", %{
        "session" => %{"email" => email, "password" => "verylongpassword"}
      })

    conn = get(recycle(conn), ~p"/profile")
    html = html_response(conn, 200)
    assert html =~ "Your profile"
    assert html =~ email
    assert html =~ "Eve"
    assert html =~ "Ada"
  end

  describe "GET /profile/edit" do
    test "renders edit profile page for logged-in user", %{conn: conn} do
      uniq = Integer.to_string(System.unique_integer([:positive]))
      email = "edit" <> uniq <> "@example.com"

      {:ok, _user} =
        Accounts.register_user(%{
          "username" => "edit_user_" <> uniq,
          "password" => "verylongpassword",
          "password_confirmation" => "verylongpassword",
          "name" => "Edit",
          "last_name" => "User",
          "email" => email,
          "birthdate" => "1990-01-01",
          "nationality" => "AZ",
          "residence_address" => "Baku city",
          "phone_number" => "+994500000000"
        })

      conn =
        conn
        |> post(~p"/users/login", %{
          "session" => %{"email" => email, "password" => "verylongpassword"}
        })

      conn = get(recycle(conn), ~p"/profile/edit")
      assert html_response(conn, 200) =~ "Edit Profile"
    end
  end

  describe "PUT /profile" do
    test "updates user profile successfully", %{conn: conn} do
      uniq = Integer.to_string(System.unique_integer([:positive]))
      email = "update" <> uniq <> "@example.com"

      {:ok, user} =
        Accounts.register_user(%{
          "username" => "update_user_" <> uniq,
          "password" => "verylongpassword",
          "password_confirmation" => "verylongpassword",
          "name" => "Old",
          "last_name" => "Name",
          "email" => email,
          "birthdate" => "1990-01-01",
          "nationality" => "AZ",
          "residence_address" => "Baku city",
          "phone_number" => "+994500000000"
        })

      conn =
        conn
        |> post(~p"/users/login", %{
          "session" => %{"email" => email, "password" => "verylongpassword"}
        })

      update_params = %{
        "user" => %{
          "username" => "new_username_" <> uniq,
          "name" => "New",
          "last_name" => "Name",
          "email" => email,
          "birthdate" => "1990-01-01",
          "nationality" => "AZ",
          "residence_address" => "Baku city",
          "phone_number" => "+994500000000"
        }
      }

      conn = put(recycle(conn), ~p"/profile", update_params)
      assert redirected_to(conn) == ~p"/profile"

      updated_user = Accounts.get_user_by_id(user.id)
      assert updated_user.username == "new_username_" <> uniq
      assert updated_user.name == "New"
    end
  end
end
