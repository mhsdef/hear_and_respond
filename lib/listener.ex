defmodule HearHearNow.Listener do
  @moduledoc """
  Base module for managing listeners. A listener is a module that contains
  one or more `listen/1` functions that listen to a source and make the
  decision when to accept the payload for response processing.
  """
  alias HearHearNow.ListenerSupervisor

  @listeners Application.compile_env(:hear_hear_now, :listeners, [])
  @responders Application.compile_env(:hear_hear_now, :responders, [])

  def listen(msg) do
    Enum.each(@listeners, fn l -> l.listen(msg) end)
  end

  def accept(msg) do
    {:ok, _pid} = Task.Supervisor.start_child(ListenerSupervisor, __MODULE__, :invoke, [msg])
  end

  def invoke(event) do
    @responders
    |> Enum.flat_map(fn {mod, _} -> mod.get_responders() end)
    |> dispatch(event)
  end

  def dispatch(responders, msg) do
    stream = Task.async_stream(responders, fn r -> apply_responder(r, msg) end)
    Stream.run(stream)
  end

  defp apply_responder({regex, mod, fun}, %{"text" => text} = msg) do
    if Regex.match?(regex, text) do
      msg = %{msg | matches: find_matches(regex, text)}
      apply(mod, fun, [msg])
    end
  end

  defp find_matches(regex, text) do
    case Regex.names(regex) do
      [] ->
        matches = Regex.run(regex, text)

        Enum.reduce(Enum.with_index(matches), %{}, fn {match, index}, acc ->
          Map.put(acc, index, match)
        end)

      _ ->
        Regex.named_captures(regex, text)
    end
  end
end
