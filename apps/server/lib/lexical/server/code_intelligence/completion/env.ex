defmodule Lexical.Server.CodeIntelligence.Completion.Env do
  alias Lexical.Completion.Builder
  alias Lexical.Completion.Environment
  alias Lexical.Document
  alias Lexical.Document.Position
  alias Lexical.Project
  alias Lexical.Protocol.Types.Completion
  alias Lexical.Server.CodeIntelligence.Completion.Env

  defstruct [:project, :document, :prefix, :suffix, :position, :words, :zero_based_character]

  @type t :: %__MODULE__{
          project: Lexical.Project.t(),
          document: Lexical.Document.t(),
          prefix: String.t(),
          suffix: String.t(),
          position: Lexical.Document.Position.t(),
          words: [String.t()],
          zero_based_character: non_neg_integer()
        }

  @behaviour Environment

  def new(%Project{} = project, %Document{} = document, %Position{} = cursor_position) do
    case Document.fetch_text_at(document, cursor_position.line) do
      {:ok, line} ->
        zero_based_character = cursor_position.character - 1
        graphemes = String.graphemes(line)
        prefix = graphemes |> Enum.take(zero_based_character) |> IO.iodata_to_binary()
        suffix = String.slice(line, zero_based_character..-1)
        words = String.split(prefix)

        {:ok,
         %__MODULE__{
           project: project,
           document: document,
           prefix: prefix,
           suffix: suffix,
           position: cursor_position,
           words: words,
           zero_based_character: zero_based_character
         }}

      _ ->
        {:error, :out_of_bounds}
    end
  end

  @impl Environment
  def function_capture?(%__MODULE__{} = env) do
    case cursor_context(env) do
      {:ok, line, {:alias, module_name}} ->
        # &Enum|
        String.contains?(line, List.to_string([?& | module_name]))

      {:ok, line, {:dot, {:alias, module_name}, _}} ->
        # &Enum.f|
        String.contains?(line, List.to_string([?& | module_name]))

      _ ->
        false
    end
  end

  @impl Environment
  def struct_reference?(%__MODULE__{} = env) do
    case cursor_context(env) do
      {:ok, _line, {:struct, _}} ->
        true

      {:ok, line, {:local_or_var, [?_, ?_ | rest]}} ->
        # a reference to `%__MODULE`, often in a function head, as in
        # def foo(%__)
        String.starts_with?("MODULE", List.to_string(rest)) and String.contains?(line, "%__")

      _ ->
        false
    end
  end

  @impl Environment
  def pipe?(%__MODULE__{} = env) do
    with {:ok, line, context} <- surround_context(env),
         {:ok, {:operator, '|>'}} <- previous_surround_context(line, context) do
      true
    else
      _ ->
        false
    end
  end

  @impl Environment
  def empty?("") do
    true
  end

  def empty?(string) when is_binary(string) do
    String.trim(string) == ""
  end

  @impl Environment
  def last_word(%__MODULE__{} = env) do
    List.last(env.words)
  end

  @behaviour Builder

  @impl Builder
  def snippet(%Env{}, snippet_text, options \\ []) do
    options
    |> Keyword.put(:insert_text, snippet_text)
    |> Keyword.put(:insert_text_format, :snippet)
    |> Completion.Item.new()
  end

  @impl Builder
  def plain_text(%Env{}, insert_text, options \\ []) do
    options
    |> Keyword.put(:insert_text, insert_text)
    |> Completion.Item.new()
  end

  @impl Builder
  def fallback(nil, fallback), do: fallback
  def fallback("", fallback), do: fallback
  def fallback(detail, _), do: detail

  @impl Builder
  def boost(text, amount \\ 5)

  def boost(text, amount) when amount in 0..10 do
    boost_char = ?* - amount
    IO.iodata_to_binary([boost_char, text])
  end

  def boost(text, _) do
    boost(text, 0)
  end

  defp cursor_context(%__MODULE__{} = env) do
    with {:ok, line} <- Document.fetch_text_at(env.document, env.position.line) do
      fragment = String.slice(line, 0..(env.zero_based_character - 1))
      {:ok, line, Code.Fragment.cursor_context(fragment)}
    end
  end

  defp surround_context(%__MODULE__{} = env) do
    with {:ok, line} <- Document.fetch_text_at(env.document, env.position.line),
         %{context: _} = context <-
           Code.Fragment.surround_context(line, {1, env.zero_based_character}) do
      {:ok, line, context}
    end
  end

  defp previous_surround_context(line, %{begin: {1, column}}) do
    previous_surround_context(line, column)
  end

  defp previous_surround_context(_line, 1) do
    :error
  end

  defp previous_surround_context(line, character) when is_integer(character) do
    case Code.Fragment.surround_context(line, {1, character - 1}) do
      :none ->
        previous_surround_context(line, character - 1)

      %{context: context} ->
        {:ok, context}
    end
  end
end
