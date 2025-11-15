# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     EarthScanner.Repo.insert!(%EarthScanner.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias EarthScanner.Accounts
alias EarthScanner.Repo

# Create an admin user for testing
case Accounts.register_user(%{
       "username" => "admin",
       "email" => "admin@example.com",
       "password" => "Password123!",
       "password_confirmation" => "Password123!",
       "name" => "Admin",
       "last_name" => "User",
       "birthdate" => "1990-01-01",
       "nationality" => "TR",
       "residence_address" => "Admin Street",
       "phone_number" => "+905551111111"
     }) do
  {:ok, user} ->
    # Update role to admin
    user
    |> Ecto.Changeset.change(role: "admin")
    |> Repo.update!()

    IO.puts("✅ Admin user created: admin@example.com / Password123!")

  {:error, changeset} ->
    IO.puts("❌ Failed to create admin user")
    IO.inspect(changeset.errors)
end
