defmodule Lexical.RemoteControl.CompileTracer do
  alias Lexical.RemoteControl
  alias Lexical.RemoteControl.ModuleMappings

  import RemoteControl.Api.Messages
  require Logger

  def trace({:on_module, _, _}, %Macro.Env{} = env) do
    message = extract_module_updated(env.module)
    ModuleMappings.update(env.module, env.file)
    RemoteControl.notify_listener(message)
    :ok
  end

  def trace(_event, _env) do
    :ok
  end

  def extract_module_updated(module) do
    functions = module.__info__(:functions)
    macros = module.__info__(:macros)

    struct =
      if function_exported?(module, :__struct__, 0) do
        module.__struct__()
        |> Map.from_struct()
        |> Enum.map(fn {k, v} ->
          %{field: k, required?: !is_nil(v)}
        end)
      end

    module_updated(
      name: module,
      functions: functions,
      macros: macros,
      struct: struct
    )
  end
end
