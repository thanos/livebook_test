defmodule LivebookTest.Runner.Behaviour do
  @moduledoc false

  @type run_outcome :: {:ok, LivebookTest.Runner.run_result()} | {:error, term()}

  @callback run(script_path :: Path.t(), opts :: keyword()) :: run_outcome()
  @callback run_all(script_pairs :: [{Path.t(), Path.t()}], opts :: keyword()) ::
              [LivebookTest.Runner.run_result()]
end
