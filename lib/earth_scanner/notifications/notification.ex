defmodule EarthScanner.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :kind, :string
    field :payload, :map
    field :read_at, :utc_datetime

    belongs_to :user, EarthScanner.Accounts.User

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :kind, :payload, :read_at])
    |> validate_required([:user_id, :kind, :payload])
  end
end
