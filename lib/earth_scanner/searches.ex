defmodule EarthScanner.Searches do
  @moduledoc """
  Searches context for managing user search history.
  """

  import Ecto.Query, warn: false
  alias EarthScanner.Repo
  alias EarthScanner.Searches.SearchHistory
  alias EarthScanner.Accounts.User

  @max_saved_searches 5

  @doc """
  Records a search query for the given user.

  Automatically maintains a maximum of #{@max_saved_searches} most recent searches.
  When the limit is exceeded, the oldest search is deleted.
  """
  def record_search(%User{id: user_id}, source_city, destination_city) do
    # Create new search entry
    changeset =
      %SearchHistory{}
      |> SearchHistory.changeset(%{
        "source_city" => source_city,
        "destination_city" => destination_city,
        "user_id" => user_id
      })

    case Repo.insert(changeset) do
      {:ok, search} ->
        # Clean up old searches if over limit
        prune_old_searches(user_id)
        {:ok, search}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Gets the last #{@max_saved_searches} searches for the given user, ordered by most recent first.
  """
  def get_recent_searches(%User{id: user_id}) do
    SearchHistory
    |> where(user_id: ^user_id)
    |> order_by([s], desc: s.inserted_at, desc: s.id)
    |> limit(@max_saved_searches)
    |> Repo.all()
  end

  @doc """
  Deletes a specific search history entry.
  """
  def delete_search(%SearchHistory{} = search) do
    Repo.delete(search)
  end

  # Private: removes searches older than the @max_saved_searches limit
  defp prune_old_searches(user_id) do
    count_query =
      from s in SearchHistory,
        where: s.user_id == ^user_id,
        select: count(s.id)

    case Repo.one(count_query) do
      count when count > @max_saved_searches ->
        # Find IDs of searches to delete (oldest ones)
        ids_to_delete_query =
          from s in SearchHistory,
            where: s.user_id == ^user_id,
            order_by: [asc: :inserted_at],
            limit: ^(count - @max_saved_searches),
            select: s.id

        ids_to_delete = Repo.all(ids_to_delete_query)

        # Delete by ID only (delete_all allows only where clause)
        from(s in SearchHistory, where: s.id in ^ids_to_delete)
        |> Repo.delete_all()

      _ ->
        :ok
    end
  end
end
