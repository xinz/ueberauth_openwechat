defmodule UeberauthWechat.MixProject do
  use Mix.Project

  @source_url "https://github.com/xinz/ueberauth_openwechat"

  def project do
    [
      app: :ueberauth_openwechat,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {UeberauthWeChat.App, []}
    ]
  end

  defp deps do
    [
      {:ueberauth, github: "xinz/ueberauth", branch: "remove_state_cookie"},
      {:finch, "~> 0.6"},
      {:jason, "~> 1.2"},
      {:ex_doc, ">= 0.0.0", only: [:dev], runtime: false},
      {:mock, "~> 0.3", only: :test}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_url: @source_url,
      homepage_url: @source_url,
      formatters: ["html"]
    ]
  end
end
