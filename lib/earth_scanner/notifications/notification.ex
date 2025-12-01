defmodule EarthScanner.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :kind, :string
    field :payload, :map
    field :read_at, :utc_datetime
    field :status, :string, default: "pending"
    field :attempts, :integer, default: 0
    field :last_attempted_at, :utc_datetime
    field :error, :string
    field :delivered_at, :utc_datetime

    belongs_to :user, EarthScanner.Accounts.User

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :kind, :payload, :read_at, :status, :attempts, :last_attempted_at, :error, :delivered_at])
    |> validate_required([:user_id, :kind, :payload])
  end
end
