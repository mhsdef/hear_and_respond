defmodule HearHear.Responder do
  @moduledoc ~S"""
  Base module for building responders. A responder is a module which setups up
  handlers for hearing and responding to incoming messages.

  ## Hearing & Responding

  We can hear messages said in a room or respond to messages directly
  addressed to it. Both methods take a regular expression, the message and a block
  to execute when there is a match. For example:

      hear ~r/(hi|hello)/i, msg do
        # your code here
      end

      respond ~r/help$/i, msg do
        # your code here
      end

  ## Using captures

  Responders support regular expression captures. It supports both normal
  captures and named captures. When a message matches, captures are handled
  automatically and added to the message's `:matches` key. Accessing the
  captures depends on the type of capture used in the responder's regex.
  If named captures are used, captures will be available by the name,
  otherwise it will be available by an index, starting with 0.

  ### Example:

      # with indexed captures
      hear ~r/i like (\w+), msg do
        emote msg, "likes #{msg.matches[1]} too!"
      end

      # with named captures
      hear ~r/i like (?<subject>\w+), msg do
        emote msg, "likes #{msg.matches["subject"]} too!"
      end
  """

  defmacro __using__(_opts) do
    quote location: :keep do
      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :hear, accumulate: true)
      Module.register_attribute(__MODULE__, :respond, accumulate: true)
      Module.register_attribute(__MODULE__, :usage, accumulate: true)

      @before_compile unquote(__MODULE__)
    end
  end

  @doc """
  Matches messages based on the regular expression.
  ## Example
      hear ~r/hello/, msg do
        # code to handle the message
      end
  """
  defmacro hear(regex, msg, do: block) do
    name = unique_name(:hear)

    quote do
      @hear {unquote(regex), __MODULE__, unquote(name)}
      @doc false
      def unquote(name)(unquote(msg)) do
        unquote(block)
      end
    end
  end

  @doc """
  Matches messages based on the regular expression when prefixed by name or aka.
  ## Example
      # If our name name is "alice", this responder
      # would match for a message with the following text:
      # "alice hello"

      respond ~r/hello/, msg do
        # code to handle the message
      end
  """
  defmacro respond(regex, msg, do: block) do
    name = unique_name(:respond)

    quote do
      @respond {unquote(regex), __MODULE__, unquote(name)}
      @doc false
      def unquote(name)(unquote(msg)) do
        unquote(block)
      end
    end
  end

  @doc false
  def respond_pattern(pattern, name, aka) do
    pattern
    |> Regex.source()
    |> rewrite_source(name, aka)
    |> Regex.compile!(Regex.opts(pattern))
  end

  defp rewrite_source(source, name, nil) do
    "^\\s*[@]?#{name}[:,]?\\s*(?:#{source})"
  end

  defp rewrite_source(source, name, aka) do
    [a, b] = if String.length(name) > String.length(aka), do: [name, aka], else: [aka, name]
    "^\\s*[@]?(?:#{a}[:,]?|#{b}[:,]?)\\s*(?:#{source})"
  end

  defp unique_name(type) do
    String.to_atom("#{type}_#{System.unique_integer([:positive, :monotonic])}")
  end

  defmacro __before_compile__(_env) do
    quote location: :keep do
      @doc false

      @name Application.compile_env!(:hear_hear, :preferred_name)
      @aka Application.compile_env(:hear_hear, :aka)

      respond =
        for {regex, mod, fun} <- @respond do
          regex = HearHear.Responder.respond_pattern(regex, @name, @aka)
          {regex, mod, fun}
        end

      @responders List.flatten([@hear, respond])

      def get_responders() do
        @responders
      end

      def usage() do
        Enum.map(@usage, &(&1 |> String.trim() |> String.replace("bb", @name)))
      end
    end
  end
end
