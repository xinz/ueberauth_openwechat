defmodule UeberauthWeChat do
  @moduledoc false

  defmodule App do
    @moduledoc false

    use Application

    @impl true
    def start(_type, _args) do
      children = [
        {
          Finch,
          name: UeberauthWeChat.HttpClient,
          pools: %{
            :default => [size: 100]
          }
        }
      ]

      opts = [strategy: :one_for_one]
      Supervisor.start_link(children, opts)
    end
  end
end
