defmodule Lexical.Server.Configuration.Support do
  alias Lexical.Protocol.Types.ClientCapabilities

  defstruct code_action_dynamic_registration?: false,
            hierarchical_document_symbols?: false,
            snippet?: false,
            deprecated?: false,
            tags?: false,
            signature_help?: false

  def new(%ClientCapabilities{} = client_capabilities) do
    dynamic_registration? =
      client_capabilities
      |> get_in([:text_document, :code_action, :dynamic_registration])
      |> bool()

    hierarchical_symbols? =
      client_capabilities
      |> get_in([:text_document, :document_symbol, :hierarchical_document_symbol_support])
      |> bool()

    snippet? =
      client_capabilities
      |> get_in([:text_document, :completion, :completion_item, :snippet_support])
      |> bool()

    deprecated? =
      client_capabilities
      |> get_in([:text_document, :completion, :completion_item, :deprecated_support])
      |> bool()

    tags? =
      client_capabilities
      |> get_in([:text_document, :completion, :completion_item, :tag_support])
      |> bool()

    signature_help? =
      client_capabilities
      |> get_in([:text_document, :signature_help])
      |> bool()

    %__MODULE__{
      code_action_dynamic_registration?: dynamic_registration?,
      hierarchical_document_symbols?: hierarchical_symbols?,
      snippet?: snippet?,
      deprecated?: deprecated?,
      tags?: tags?,
      signature_help?: signature_help?
    }
  end

  def new(_) do
    %__MODULE__{}
  end

  defp bool(b) when b in [true, false], do: b
  defp bool(_), do: false
end
