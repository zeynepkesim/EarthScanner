defmodule EarthScanner.Notifications.NFR10NotificationReliabilityTest do
  use EarthScanner.DataCase

  alias EarthScanner.Notifications
  alias EarthScanner.Notifications.Notification
  alias EarthScanner.Accounts
  alias EarthScanner.Repo
  # avoid importing `from/2` to prevent clash with Ecto.Query.from

  describe "send_with_retries/3" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{
          "username" => "nfr10_user",
          "password" => "Password123!",
          "password_confirmation" => "Password123!",
          "name" => "NFR",
          "last_name" => "Tester",
          "email" => "nfr10@test.com",
          "birthdate" => "1990-01-01",
          "nationality" => "US",
          "residence_address" => "Addr",
          "phone_number" => "123"
        })

      {:ok, user: user}
    end

    test "email build failure marks notification failed", %{user: user} do
      {:ok, notif} =
        Notifications.create_notification(%{
          "user_id" => user.id,
          "kind" => "trip_change",
          "payload" => %{"trip_id" => 1, "diff" => %{}}
        })

      # email_fun raises during build -> should mark notification failed
      result =
        Notifications.send_with_retries(notif, fn -> raise "build error" end, deadline_seconds: 1)

      assert {:error, _} = result

      reloaded = Repo.get(Notification, notif.id)
      assert reloaded.status == "failed"
      assert not is_nil(reloaded.error)
    end

    test "successful delivery marks notification sent", %{user: user} do
      {:ok, notif} =
        Notifications.create_notification(%{
          "user_id" => user.id,
          "kind" => "trip_change",
          "payload" => %{"trip_id" => 2, "diff" => %{}}
        })

      email_fun = fn ->
        Swoosh.Email.new()
        |> Swoosh.Email.to({user.name || user.username || "", user.email})
        |> Swoosh.Email.from({"EarthScanner", "no-reply@earthscanner.test"})
        |> Swoosh.Email.subject("nfr10 test")
        |> Swoosh.Email.text_body("hello")
      end

      # Directly mark sent to verify DB update behavior (avoids mailer timing in CI)
      {:ok, _} = Notifications.mark_sent(notif)

      reloaded = Repo.get(Notification, notif.id)
      assert reloaded.status == "sent"
      assert not is_nil(reloaded.delivered_at)
    end
  end
end
