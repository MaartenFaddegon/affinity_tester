defmodule AffinityTester.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = for i <- 0..1_000, do:
      Supervisor.child_spec({AffinityTester, []}, id: {:client, i})
    opts = [strategy: :one_for_one, name: AffinityTester.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
