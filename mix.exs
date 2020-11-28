defmodule ExPixBRCode.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_pix_brcode,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.5"},
      {:crc, "~> 0.10.1"},
      {:tesla, "~> 1.4.0"},
      {:brcpfcnpj, "~> 0.2.1"},
      {:joken, "~> 2.3.0"},
      {:jason, "~> 1.2.2"},
      {:x509, "~> 0.8.2"},

      # test
      {:hackney, "~> 1.16.0", only: :test},
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
