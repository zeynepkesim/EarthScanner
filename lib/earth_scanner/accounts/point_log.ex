defmodule EarthScanner.Accounts.PointLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "point_logs" do
    field :change_amount, :integer
    field :reason, :string
    field :balance_after, :integer
    belongs_to :user, EarthScanner.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(point_log, attrs) do
    point_log
    |> cast(attrs, [:user_id, :change_amount, :reason, :balance_after])
    |> validate_required([:user_id, :change_amount, :reason, :balance_after])
  end
end
