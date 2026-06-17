defmodule LivebookTest.TestSupport do
  @moduledoc false

  def with_env(app, key, value, fun) do
    previous = Application.get_env(app, key)

    Application.put_env(app, key, value)

    try do
      fun.()
    after
      if previous == nil do
        Application.delete_env(app, key)
      else
        Application.put_env(app, key, previous)
      end
    end
  end
end
