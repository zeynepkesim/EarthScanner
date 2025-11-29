defmodule EarthScanner.Notifications do
  @moduledoc false

  import Ecto.Query, warn: false
  alias EarthScanner.Repo
  alias EarthScanner.Notifications.Notification

  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  def list_for_user(user_id) do
    from(n in Notification, where: n.user_id == ^user_id, order_by: [desc: n.inserted_at])
    |> Repo.all()
  end

  @doc """
  Returns the count of unread notifications for the given user.
  """
  def unread_count_for_user(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at), select: count(n.id))
    |> Repo.one()
  end
end
