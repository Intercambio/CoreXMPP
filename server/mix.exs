defmodule Ejabberd.Server.Mixfile do
  use Mix.Project

  def project do
    [app: :xmpp_server,
     version: "0.0.1",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :ejabberd]]
  end
  
  defp deps do
    [{:ejabberd, github: "processone/ejabberd", tag: "16.09"}]
  end
end
