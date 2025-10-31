defmodule WhiteBreadContext do
  use WhiteBread.Context
  use Hound.Helpers

  # 1-arity: state
  scenario_starting_state fn state ->
    Hound.start_session()
    state
  end

  # 2-arity: status, state
  scenario_finalize fn _status, _state ->
    Hound.end_session()
    :ok
  end

  given_ ~r/^I am a visitor$/, fn state, _extra ->
    {:ok, state}
  end

  when_ ~r/^I visit the homepage$/, fn state, _extra ->
    navigate_to("http://localhost:4002/")
    {:ok, state}
  end

  then_ ~r/^I should see a Phoenix welcome message$/, fn state, _extra ->
    page_text = visible_page_text()
    assert String.contains?(page_text, "Phoenix")
    {:ok, state}
  end
end
