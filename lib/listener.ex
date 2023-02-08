defmodule HearAndRespond.Listener do
  alias HearAndRespond.ListenerSupervisor

  @responders Application.compile_env(:hear_and_respond, :responders, [])

  def listen(%{"type" => "message"} = event) do
    {:ok, _pid} = Task.Supervisor.start_child(ListenerSupervisor, __MODULE__, :process, [event])
  end

  def listen(_), do: nil

  def process(event) do
    @responders
    |> Enum.flat_map(fn mod -> mod.get_responders() end)
    |> dispatch(event)
  end

  def dispatch(responders, msg) do
    stream = Task.async_stream(responders, fn r -> apply_responder(r, msg) end)
    Stream.run(stream)
  end

  defp apply_responder({regex, mod, fun}, %{text: text} = msg) do
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
