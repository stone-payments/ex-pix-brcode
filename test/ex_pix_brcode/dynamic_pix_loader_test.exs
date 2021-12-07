defmodule ExPixBRCode.Payments.DynamicPixLoaderTest do
  use ExUnit.Case, async: true

  alias ExPixBRCode.Payments.DynamicPixLoader
  alias ExPixBRCode.Payments.Models.{DynamicImmediatePixPayment, DynamicPixPaymentWithDueDate}

  alias ExPixBRCode.Payments.Models.DynamicImmediatePixPayment.{
    Calendario,
    Valor,
    Valor.Retirada,
    Valor.Retirada.Saque,
    Valor.Retirada.Troco
  }

  @client Tesla.client([], Tesla.Mock)

  setup do
    ca_key = X509.PrivateKey.new_rsa(1024)

    ca =
      X509.Certificate.self_signed(
        ca_key,
        "/C=BR/ST=SP/L=Sao Paulo/O=Acme/CN=RSA Pix Root CA",
        template: :root_ca
      )

    my_key = X509.PrivateKey.new_rsa(1024)

    my_cert =
      my_key
      |> X509.PublicKey.derive()
      |> X509.Certificate.new(
        "/C=BR/ST=RJ/L=Rio de Janeiro/O=PSP Bank/CN=PSP",
        ca,
        ca_key,
        extensions: [
          subject_alt_name:
            X509.Certificate.Extension.subject_alt_name(["somepixpsp.br", "www.somepixpsp.br"])
        ]
      )

    raw_cert = X509.Certificate.to_der(my_cert)

    x5c = [
      Base.encode64(raw_cert),
      ca |> X509.Certificate.to_der() |> Base.encode64()
    ]

    {_, pubkey_map} =
      my_cert
      |> X509.Certificate.public_key()
      |> JOSE.JWK.from_key()
      |> JOSE.JWK.to_map()

    thumbprint =
      :sha
      |> :crypto.hash(raw_cert)
      |> Base.url_encode64(padding: false)

    thumbprintS256 =
      :sha256
      |> :crypto.hash(raw_cert)
      |> Base.url_encode64(padding: false)

    kid = Ecto.UUID.generate()

    pem = my_key |> JOSE.JWK.from_key() |> JOSE.JWK.to_pem()

    jku = "https://somepixpsp.br/pix/v2/certs"

    signer =
      Joken.Signer.create("RS256", %{"pem" => pem}, %{
        "x5t" => thumbprint,
        "kid" => kid,
        "jku" => jku
      })

    signerS256 =
      Joken.Signer.create("RS256", %{"pem" => pem}, %{
        "x5t#S256" => thumbprintS256,
        "kid" => kid,
        "jku" => jku
      })

    jwks = %{
      "keys" => [
        Map.merge(
          pubkey_map,
          %{
            "kid" => kid,
            "x5c" => x5c,
            "x5t" => thumbprint,
            "x5t#S256" => thumbprintS256,
            "kty" => "RSA",
            "key_ops" => ["verify"]
          }
        )
      ]
    }

    invalid_jwk = %{
      "keys" => [
        %{
          "kid" => kid,
          "x5c" => x5c,
          "x5t" => thumbprint,
          "kty" => "RSA",
          "e" => "AQAB",
          "n" =>
            "0DO2yRYKsVKTbkUTyjkd6a5qLLQRhlkmzOek2ZLLX8ohaZU8NDGjLCvLCA8kPM7cS7j/7uE8g2tskBMsiIyiS8EZ6HzDbdx4A60ncvrAiGb0Y9dZETtld2W3Wf8EaveIdllLOy0379CQw9v/rvHLaJvr1/Rjp5je4LSMTiSW7nDSliNq41hwfXBoSRtst6fmejTL81Bvmn7TjYgQohwu++dRhhltlJJLEl/eAffx7JZLbDFC4WRWk1jbCbf2Q80NlEftm72gDUz79nLg2Dv6igaH3pm8X7mBrgmmxscy5Jmdn32zcvTvwZVEFa0ri7S96Ho4BZdCTuacMrPxq7sjEw",
          "key_ops" => ["verify"]
        }
      ]
    }

    {:ok, jku: jku, signer: signer, signerS256: signerS256, jwks: jwks, invalid_jwk: invalid_jwk}
  end

  describe "load_pix/2" do
    for key_type <- [
          :cpf,
          :cnpj,
          :phone,
          :email,
          :random_key
        ] do
      test "succeeds for payment with #{key_type} key", %{jku: jku} = ctx do
        payment = build_pix_payment() |> with_key(unquote(key_type))
        pix_url = "https://somepixpsp.br/pix/v2/#{Ecto.UUID.generate()}"

        Tesla.Mock.mock(fn
          %{url: ^pix_url} ->
            %{}
            |> Joken.generate_and_sign!(payment, ctx.signer)
            |> Tesla.Mock.text(headers: [{"content-type", "application/jose"}])

          %{url: ^jku} ->
            Tesla.Mock.json(ctx.jwks)
        end)

        assert {:ok,
                %DynamicImmediatePixPayment{
                  calendario: %Calendario{
                    apresentacao: ~U[2020-11-28 03:15:39Z],
                    criacao: ~U[2020-11-13 23:59:49Z],
                    expiracao: 86400
                  },
                  chave: payment.chave,
                  devedor: nil,
                  infoAdicionais: [],
                  revisao: 0,
                  solicitacaoPagador: nil,
                  status: :ATIVA,
                  txid: "4DE46328260C11EB91C04049FC2CA371",
                  valor: %Valor{original: Decimal.new("1.00")}
                }} == DynamicPixLoader.load_pix(@client, pix_url)

        x5t = ctx.jwks["keys"] |> hd() |> Map.get("x5t")
        kid = ctx.jwks["keys"] |> hd() |> Map.get("kid")
        key = {x5t, kid}
        assert %{^key => _} = :persistent_term.get(ctx.jku)
      end

      test "succeeds for dynamic due date payment with #{key_type} key", %{jku: jku} = ctx do
        dpp = "2020-11-13"
        cod_mun = "1111111"
        devedor_cpf = Brcpfcnpj.cpf_generate()
        recebedor_cpf = Brcpfcnpj.cpf_generate()

        payment =
          build_due_date_pix_payment()
          |> with_key(unquote(key_type))
          |> put_in([:devedor, :cpf], devedor_cpf)
          |> put_in([:recebedor, :cpf], recebedor_cpf)

        pix_url =
          "https://somepixpsp.br/pix/v2/cobv/#{Ecto.UUID.generate()}?DPP=#{dpp}&codMun=#{cod_mun}"

        Tesla.Mock.mock(fn
          %{url: ^pix_url, query: [DPP: ^dpp, codMun: ^cod_mun]} ->
            %{}
            |> Joken.generate_and_sign!(payment, ctx.signer)
            |> Tesla.Mock.text(headers: [{"content-type", "application/jose"}])

          %{url: ^jku} ->
            Tesla.Mock.json(ctx.jwks)
        end)

        assert {:ok,
                %DynamicPixPaymentWithDueDate{
                  calendario: %DynamicPixPaymentWithDueDate.Calendario{
                    apresentacao: ~U[2020-11-28 03:15:39Z],
                    criacao: ~U[2020-11-13 23:59:49Z],
                    dataDeVencimento: ~D[2020-11-13],
                    validadeAposVencimento: 30
                  },
                  chave: payment.chave,
                  devedor: %DynamicPixPaymentWithDueDate.Devedor{
                    cpf: devedor_cpf,
                    nome: "Cicrano"
                  },
                  infoAdicionais: [],
                  revisao: 0,
                  solicitacaoPagador: nil,
                  status: :ATIVA,
                  txid: "4DE46328260C11EB91C04049FC2CA371",
                  valor: %DynamicPixPaymentWithDueDate.Valor{final: Decimal.new("1.00")},
                  recebedor: %DynamicPixPaymentWithDueDate.Recebedor{
                    cpf: recebedor_cpf,
                    nome: "Fulano",
                    cidade: "Rio de Janeiro",
                    uf: "RJ",
                    cep: "28610-160",
                    logradouro: "Avenida Brasil"
                  }
                }} == DynamicPixLoader.load_pix(@client, pix_url, dpp: dpp, cod_mun: cod_mun)

        x5t = ctx.jwks["keys"] |> hd() |> Map.get("x5t")
        kid = ctx.jwks["keys"] |> hd() |> Map.get("kid")
        key = {x5t, kid}
        assert %{^key => _} = :persistent_term.get(ctx.jku)
      end

      test "succeeds for withdrawal with #{key_type} key", %{jku: jku} = ctx do
        payment = build_pix_withdrawal() |> with_key(unquote(key_type))
        pix_url = "https://somepixpsp.br/pix/v2/#{Ecto.UUID.generate()}"

        Tesla.Mock.mock(fn
          %{url: ^pix_url} ->
            %{}
            |> Joken.generate_and_sign!(payment, ctx.signer)
            |> Tesla.Mock.text(headers: [{"content-type", "application/jose"}])

          %{url: ^jku} ->
            Tesla.Mock.json(ctx.jwks)
        end)

        assert {:ok,
                %DynamicImmediatePixPayment{
                  calendario: %Calendario{
                    apresentacao: ~U[2020-11-28 03:15:39Z],
                    criacao: ~U[2020-11-13 23:59:49Z],
                    expiracao: 86400
                  },
                  chave: payment.chave,
                  devedor: nil,
                  infoAdicionais: [],
                  revisao: 0,
                  solicitacaoPagador: nil,
                  status: :ATIVA,
                  txid: "4DE46328260C11EB91C04049FC2CA371",
                  valor: %Valor{
                    modalidadeAlteracao: 0,
                    original: Decimal.new("0.00"),
                    retirada: %Retirada{
                      saque: %Saque{
                        modalidadeAgente: "AGTEC",
                        modalidadeAlteracao: 0,
                        prestadorDoServicoDeSaque: "16501555",
                        valor: Decimal.new("10.00")
                      },
                      troco: nil
                    }
                  }
                }} == DynamicPixLoader.load_pix(@client, pix_url)

        x5t = ctx.jwks["keys"] |> hd() |> Map.get("x5t")
        kid = ctx.jwks["keys"] |> hd() |> Map.get("kid")
        key = {x5t, kid}
        assert %{^key => _} = :persistent_term.get(ctx.jku)
      end

      test "succeeds for payment with change with #{key_type} key", %{jku: jku} = ctx do
        payment = build_pix_payment_with_change() |> with_key(unquote(key_type))
        pix_url = "https://somepixpsp.br/pix/v2/#{Ecto.UUID.generate()}"

        Tesla.Mock.mock(fn
          %{url: ^pix_url} ->
            %{}
            |> Joken.generate_and_sign!(payment, ctx.signer)
            |> Tesla.Mock.text(headers: [{"content-type", "application/jose"}])

          %{url: ^jku} ->
            Tesla.Mock.json(ctx.jwks)
        end)

        assert {:ok,
                %DynamicImmediatePixPayment{
                  calendario: %Calendario{
                    apresentacao: ~U[2020-11-28 03:15:39Z],
                    criacao: ~U[2020-11-13 23:59:49Z],
                    expiracao: 86400
                  },
                  chave: payment.chave,
                  devedor: nil,
                  infoAdicionais: [],
                  revisao: 0,
                  solicitacaoPagador: nil,
                  status: :ATIVA,
                  txid: "4DE46328260C11EB91C04049FC2CA371",
                  valor: %Valor{
                    modalidadeAlteracao: 0,
                    original: Decimal.new("10.00"),
                    retirada: %Retirada{
                      troco: %Troco{
                        modalidadeAgente: "AGTEC",
                        modalidadeAlteracao: 0,
                        prestadorDoServicoDeSaque: "16501555",
                        valor: Decimal.new("10.00")
                      },
                      saque: nil
                    }
                  }
                }} == DynamicPixLoader.load_pix(@client, pix_url)

        x5t = ctx.jwks["keys"] |> hd() |> Map.get("x5t")
        kid = ctx.jwks["keys"] |> hd() |> Map.get("kid")
        key = {x5t, kid}
        assert %{^key => _} = :persistent_term.get(ctx.jku)
      end
    end

    test "can skip certifica validations", %{jku: jku} = ctx do
      payment = build_pix_payment()
      pix_url = "https://somepixpsp.br/pix/v2/#{Ecto.UUID.generate()}"

      Tesla.Mock.mock(fn
        %{url: ^pix_url} ->
          %{}
          |> Joken.generate_and_sign!(payment, ctx.signer)
          |> Tesla.Mock.text(headers: [{"content-type", "application/jose"}])

        %{url: ^jku} ->
          key = ctx.jwks["keys"] |> hd()

          key = %{key | "x5c" => Enum.reverse(key["x5c"])}

          Tesla.Mock.json(%{keys: [key]})
      end)

      assert {:ok,
              %DynamicImmediatePixPayment{
                calendario: %Calendario{
                  apresentacao: ~U[2020-11-28 03:15:39Z],
                  criacao: ~U[2020-11-13 23:59:49Z],
                  expiracao: 86400
                },
                chave: "14413050762",
                devedor: nil,
                infoAdicionais: [],
                revisao: 0,
                solicitacaoPagador: nil,
                status: :ATIVA,
                txid: "4DE46328260C11EB91C04049FC2CA371",
                valor: %Valor{original: Decimal.new("1.00")}
              }} ==
               DynamicPixLoader.load_pix(@client, pix_url,
                 leaf_certificate_should_fail: false,
                 x5c_should_fail: false
               )

      x5t = ctx.jwks["keys"] |> hd() |> Map.get("x5t")
      kid = ctx.jwks["keys"] |> hd() |> Map.get("kid")
      key = {x5t, kid}
      assert %{^key => _} = :persistent_term.get(ctx.jku)
    end

    test "validates parameters for RSA public keys",
         %{jku: jku, invalid_jwk: invalid_jwk} = ctx do
      payment = build_pix_payment() |> with_key(:cpf)
      pix_url = "https://somepixpsp.br/pix/v2/#{Ecto.UUID.generate()}"

      Tesla.Mock.mock(fn
        %{url: ^pix_url} ->
          %{}
          |> Joken.generate_and_sign!(payment, ctx.signer)
          |> Tesla.Mock.text(headers: [{"content-type", "application/jose"}])

        %{url: ^jku} ->
          Tesla.Mock.json(invalid_jwk)
      end)

      assert {:error, {:validation, _}} = DynamicPixLoader.load_pix(@client, pix_url)
    end
  end

  describe "load_pix/2 - x5t#S256" do
    for key_type <- [
          :cpf,
          :cnpj,
          :phone,
          :email,
          :random_key
        ] do
      test "succeeds for payment with #{key_type} key", %{jku: jku} = ctx do
        payment = build_pix_payment() |> with_key(unquote(key_type))
        pix_url = "https://somepixpsp.br/pix/v2/#{Ecto.UUID.generate()}"

        Tesla.Mock.mock(fn
          %{url: ^pix_url} ->
            %{}
            |> Joken.generate_and_sign!(payment, ctx.signerS256)
            |> Tesla.Mock.text(headers: [{"content-type", "application/jose"}])

          %{url: ^jku} ->
            Tesla.Mock.json(ctx.jwks)
        end)

        assert {:ok,
                %DynamicImmediatePixPayment{
                  calendario: %Calendario{
                    apresentacao: ~U[2020-11-28 03:15:39Z],
                    criacao: ~U[2020-11-13 23:59:49Z],
                    expiracao: 86400
                  },
                  chave: payment.chave,
                  devedor: nil,
                  infoAdicionais: [],
                  revisao: 0,
                  solicitacaoPagador: nil,
                  status: :ATIVA,
                  txid: "4DE46328260C11EB91C04049FC2CA371",
                  valor: %Valor{original: Decimal.new("1.00")}
                }} == DynamicPixLoader.load_pix(@client, pix_url)

        x5t = ctx.jwks["keys"] |> hd() |> Map.get("x5t")
        kid = ctx.jwks["keys"] |> hd() |> Map.get("kid")
        key = {x5t, kid}
        assert %{^key => _} = :persistent_term.get(ctx.jku)
      end
    end

    test "can skip certifica validations", %{jku: jku} = ctx do
      payment = build_pix_payment()
      pix_url = "https://somepixpsp.br/pix/v2/#{Ecto.UUID.generate()}"

      Tesla.Mock.mock(fn
        %{url: ^pix_url} ->
          %{}
          |> Joken.generate_and_sign!(payment, ctx.signerS256)
          |> Tesla.Mock.text(headers: [{"content-type", "application/jose"}])

        %{url: ^jku} ->
          key = ctx.jwks["keys"] |> hd()

          key = %{key | "x5c" => Enum.reverse(key["x5c"])}

          Tesla.Mock.json(%{keys: [key]})
      end)

      assert {:ok,
              %DynamicImmediatePixPayment{
                calendario: %Calendario{
                  apresentacao: ~U[2020-11-28 03:15:39Z],
                  criacao: ~U[2020-11-13 23:59:49Z],
                  expiracao: 86400
                },
                chave: "14413050762",
                devedor: nil,
                infoAdicionais: [],
                revisao: 0,
                solicitacaoPagador: nil,
                status: :ATIVA,
                txid: "4DE46328260C11EB91C04049FC2CA371",
                valor: %Valor{original: Decimal.new("1.00")}
              }} ==
               DynamicPixLoader.load_pix(@client, pix_url,
                 leaf_certificate_should_fail: false,
                 x5c_should_fail: false
               )

      x5t = ctx.jwks["keys"] |> hd() |> Map.get("x5t")
      kid = ctx.jwks["keys"] |> hd() |> Map.get("kid")
      key = {x5t, kid}
      assert %{^key => _} = :persistent_term.get(ctx.jku)
    end
  end

  defp build_pix_payment do
    %{
      calendario: %{
        apresentacao: "2020-11-28 03:15:39Z",
        criacao: "2020-11-13 23:59:49Z",
        expiracao: 86400
      },
      chave: "14413050762",
      devedor: nil,
      infoAdicionais: [],
      revisao: 0,
      solicitacaoPagador: nil,
      status: :ATIVA,
      txid: "4DE46328260C11EB91C04049FC2CA371",
      valor: %{original: "1.00"}
    }
  end

  defp build_pix_withdrawal do
    %{
      calendario: %{
        apresentacao: "2020-11-28 03:15:39Z",
        criacao: "2020-11-13 23:59:49Z",
        expiracao: 86400
      },
      chave: "14413050762",
      devedor: nil,
      infoAdicionais: [],
      revisao: 0,
      solicitacaoPagador: nil,
      status: :ATIVA,
      txid: "4DE46328260C11EB91C04049FC2CA371",
      valor: %{
        original: "0.00",
        modalidadeAlteracao: 0,
        retirada: %{
          saque: %{
            valor: "10.00",
            modalidadeAlteracao: 0,
            prestadorDoServicoDeSaque: "16501555",
            modalidadeAgente: "AGTEC"
          }
        }
      }
    }
  end

  defp build_pix_payment_with_change do
    %{
      calendario: %{
        apresentacao: "2020-11-28 03:15:39Z",
        criacao: "2020-11-13 23:59:49Z",
        expiracao: 86400
      },
      chave: "14413050762",
      devedor: nil,
      infoAdicionais: [],
      revisao: 0,
      solicitacaoPagador: nil,
      status: :ATIVA,
      txid: "4DE46328260C11EB91C04049FC2CA371",
      valor: %{
        original: "10.00",
        modalidadeAlteracao: 0,
        retirada: %{
          troco: %{
            valor: "10.00",
            modalidadeAlteracao: 0,
            prestadorDoServicoDeSaque: "16501555",
            modalidadeAgente: "AGTEC"
          }
        }
      }
    }
  end

  defp build_due_date_pix_payment do
    %{
      calendario: %{
        apresentacao: "2020-11-28 03:15:39Z",
        criacao: "2020-11-13 23:59:49Z",
        dataDeVencimento: "2020-11-13",
        validadeAposVencimento: 30
      },
      chave: "14413050762",
      devedor: %{
        cpf: Brcpfcnpj.cpf_generate(),
        nome: "Cicrano"
      },
      infoAdicionais: [],
      revisao: 0,
      solicitacaoPagador: nil,
      status: :ATIVA,
      txid: "4DE46328260C11EB91C04049FC2CA371",
      valor: %{final: "1.00"},
      recebedor: %{
        cpf: Brcpfcnpj.cpf_generate(),
        nome: "Fulano",
        cidade: "Rio de Janeiro",
        uf: "RJ",
        cep: "28610-160",
        logradouro: "Avenida Brasil"
      }
    }
  end

  defp with_key(payment, :cpf), do: %{payment | chave: Brcpfcnpj.cpf_generate()}
  defp with_key(payment, :cnpj), do: %{payment | chave: Brcpfcnpj.cnpj_generate()}
  defp with_key(payment, :phone), do: %{payment | chave: "+5521987676565"}
  defp with_key(payment, :email), do: %{payment | chave: "some@email.com"}
  defp with_key(payment, :random_key), do: %{payment | chave: Ecto.UUID.generate()}
end
