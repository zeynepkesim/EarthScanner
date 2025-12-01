defmodule EarthScanner.Notifications do
  @moduledoc false

  import Ecto.Query, warn: false
  alias EarthScanner.Repo
  alias EarthScanner.Notifications.Notification
  require Logger

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
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      select: count(n.id)
    )
    |> Repo.one()
  end

  @doc """
  Mark an attempt on a notification with latest attempt time and error message.
  Returns {:ok, notification}.
  """
  def mark_attempt(%Notification{} = notification, attrs \\ %{}) do
    changes = %{
      attempts: (notification.attempts || 0) + 1,
      last_attempted_at: DateTime.utc_now()
    }

    changes = Map.merge(changes, Map.take(attrs, [:error]))

    notification
    |> Notification.changeset(changes)
    |> Repo.update()
  end

  def mark_sent(%Notification{} = notification) do
    changes = %{
      status: "sent",
      delivered_at: DateTime.utc_now(),
      error: nil
    }

    notification
    |> Notification.changeset(changes)
    |> Repo.update()
  end

  def mark_failed(%Notification{} = notification, reason) do
    changes = %{
      status: "failed",
      error: inspect(reason),
      last_attempted_at: DateTime.utc_now()
    }

    notification
    |> Notification.changeset(changes)
    |> Repo.update()
  end

  @doc """
  Synchronously attempt to deliver the notification's email with retries.

  - `notification` is an Ecto `%Notification{}` struct persisted in DB.
  - `email_fun` is a zero-arity function that returns a Swoosh email struct.
  This function will block until the message is delivered or the 10-minute deadline is reached.
  """
  def send_with_retries(%Notification{} = notification, email_fun, opts \\ [])
      when is_function(email_fun, 0) do
    # Default deadline: 30 seconds (was 10 minutes) to avoid long blocking admin requests
    max_deadline_sec = Keyword.get(opts, :deadline_seconds, 30)
    start = DateTime.utc_now()
    deadline = DateTime.add(start, max_deadline_sec, :second)

    attempt_loop(notification, email_fun, deadline, 0)
  end

  defp attempt_loop(notification, email_fun, deadline, attempts) do
    # reload latest state
    notification = Repo.get(Notification, notification.id)

    if DateTime.compare(DateTime.utc_now(), deadline) == :gt do
      Logger.warning("Notification #{notification.id} exceeded delivery deadline; marking failed")
      {:ok, _} = mark_failed(notification, "deadline_exceeded")
      {:error, :deadline_exceeded}
    else
      # build email and attempt delivery
      email =
        try do
          email_fun.()
        rescue
          e ->
            {:error, {:email_build_failed, e}}
        end

      case email do
        {:error, _} = err ->
          Logger.error(
            "Failed to build email for notification #{notification.id}: #{inspect(err)}"
          )

          {:ok, _} = mark_attempt(notification, %{error: inspect(err)})
          {:ok, _} = mark_failed(notification, err)
          {:error, err}

        email_struct ->
          # attempt delivery
          result =
            try do
              EarthScanner.Mailer.deliver(email_struct)
            rescue
              e -> {:error, e}
            end

          case result do
            {:ok, _resp} ->
              Logger.info("Notification #{notification.id} sent successfully")
              {:ok, _} = mark_sent(notification)
              {:ok, :sent}

            {:error, reason} ->
              Logger.warning("Notification #{notification.id} delivery failed: #{inspect(reason)}")
              {:ok, _} = mark_attempt(notification, %{error: inspect(reason)})

              # compute backoff (exponential), but cap to remaining time
              next_attempts = attempts + 1
              backoff = backoff_ms(next_attempts)
              remaining_ms = DateTime.diff(deadline, DateTime.utc_now(), :millisecond)
              sleep_ms = if remaining_ms <= 0, do: 0, else: min(backoff, remaining_ms)

              if sleep_ms > 0 do
                :timer.sleep(sleep_ms)
                attempt_loop(notification, email_fun, deadline, next_attempts)
              else
                Logger.warning(
                  "No time left for retrying notification #{notification.id}; marking failed"
                )

                {:ok, _} = mark_failed(notification, reason)
                {:error, :no_time_left}
              end
          end
      end
    end
  end

  defp backoff_ms(attempt) when attempt <= 0, do: 1000

  defp backoff_ms(attempt) do
    # exponential backoff in ms: 1000 * 2^(attempt-1), capped at 30s
    ms = trunc(1000 * :math.pow(2, attempt - 1))
    min(ms, 30_000)
  end
end
