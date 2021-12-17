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
      {:crc, "~> 0.10.2"},
      {:tesla, "~> 1.4.4"},
      {:brcpfcnpj, "~> 1.0.0"},
      {:joken, "~> 2.4.0"},
      {:jason, "~> 1.2"},
      {:x509, "~> 0.8.2"},

      # test
      {:hackney, "~> 1.17"},
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
