defmodule HearHear.Listener do
  @moduledoc """
  Base module for managing listeners. A listener is a module that contains
  one or more `listen/1` functions, listens to a messaging source, and
  decides when to accept the payload for response processing.
  """
  alias HearHear.ListenerSupervisor

  @listeners Application.compile_env(:hear_hear, :listeners, [])
  @responders Application.compile_env(:hear_hear, :responders, [])

  @doc """
  Listen to any input, via a list of configured `HearHear.Listener`s
  """
  @spec listen(any) :: :ok
  def listen(msg) do
    Enum.each(@listeners, fn l -> l.listen(msg) end)
  end

  @doc """
  Listeners can decide to `accept` messages that pass through them. Messages
  can be any arbitrary `map`, but, they must have a `text` field.
  """
  @spec accept(map) :: {:ok, pid}
  def accept(%{"text" => _text} = msg) do
    {:ok, _pid} = Task.Supervisor.start_child(ListenerSupervisor, __MODULE__, :invoke, [msg])
  end

  @doc """
  Invoke the configured `HearHear.Responder`s. Load them from config and
  dispatch the message to all of them.
  """
  @spec invoke(map) :: :ok
  def invoke(%{"text" => _text} = msg) do
    @responders
    |> Enum.flat_map(fn mod -> mod.get_responders() end)
    |> dispatch(msg)
  end

  @doc """
  Dispatch the given message to all the given responders
  """
  @spec dispatch([Module], map) :: :ok
  def dispatch(responders, %{"text" => _text} = msg) do
    stream = Task.async_stream(responders, fn r -> apply_responder(r, msg) end)
    Stream.run(stream)
  end

  defp apply_responder({regex, mod, fun}, %{"text" => text} = msg) do
    if Regex.match?(regex, text) do
      msg = Map.put(msg, :matches, find_matches(regex, text))
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
