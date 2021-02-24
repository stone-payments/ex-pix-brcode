defmodule ExPixBRCode.Payments.Models.DynamicPixPaymentWithDueDateTest do
  use ExUnit.Case, async: true

  alias ExPixBRCode.Changesets
  alias ExPixBRCode.Payments.Models.DynamicPixPaymentWithDueDate

  describe "changeset/2" do
    test "successfully validates a proper payload" do
      payload = %{
        "revisao" => 0,
        "chave" => "9463d2b0-2b1a-4157-80fe-344ccf0f7e13",
        "status" => "ATIVA",
        "txid" => "123456789012345678901234567890",
        "solicitacaoPagador" => "Solicitação",
        "calendario" => %{
          "criacao" => "2021-02-24 22:10:58.154290Z",
          "apresentacao" => "2021-02-24 22:23:49.246328Z",
          "dataDeVencimento" => "2021-02-28 22:23:49.246328Z"
        },
        "devedor" => %{
          "cpf" => Brcpfcnpj.cpf_generate(),
          "nome" => "Ciclano"
        },
        "valor" => %{"original" => "1.30", "final" => "1.30"},
        "recebedor" => %{
          "cpf" => Brcpfcnpj.cpf_generate(),
          "nome" => "Fulano",
          "cidade" => "Rio de Janeiro",
          "uf" => "RJ",
          "cep" => "28610-160",
          "logradouro" => "Avenida Brasil"
        }
      }

      assert {:ok, %DynamicPixPaymentWithDueDate{}} =
               Changesets.cast_and_apply(DynamicPixPaymentWithDueDate, payload)
    end

    test "successfully validates a proper payload with optional fields" do
      payload = %{
        "revisao" => 0,
        "chave" => "9463d2b0-2b1a-4157-80fe-344ccf0f7e13",
        "status" => "ATIVA",
        "txid" => "123456789012345678901234567890",
        "solicitacaoPagador" => "Solicitação",
        "calendario" => %{
          "criacao" => "2021-02-24 22:10:58.154290Z",
          "apresentacao" => "2021-02-24 22:23:49.246328Z",
          "dataDeVencimento" => "2021-02-28 22:23:49.246328Z",
          "validadeAposVencimento" => 2
        },
        "devedor" => %{
          "cpf" => Brcpfcnpj.cpf_generate(),
          "nome" => "Ciclano"
        },
        "valor" => %{
          "original" => "1.30",
          "final" => "1.30",
          "abatimento" => %{
            "modalidade" => 1,
            "valorPerc" => "7.00"
          },
          "desconto" => %{
            "modalidade" => 3,
            "valorPerc" => "6.50"
          },
          "juros" => %{
            "modalidade" => 2,
            "valorPerc" => "6.40"
          },
          "multa" => %{
            "modalidade" => 1,
            "valorPerc" => "6.00"
          }
        },
        "recebedor" => %{
          "cpf" => Brcpfcnpj.cpf_generate(),
          "nome" => "Fulano",
          "nomeFantasia" => "Loja do Fulano",
          "cidade" => "Rio de Janeiro",
          "uf" => "RJ",
          "cep" => "28610-160",
          "logradouro" => "Avenida Brasil"
        },
        "infoAdicionais" => [
          %{
            "nome" => "Campo",
            "valor" => "Valor"
          }
        ]
      }

      assert {:ok, %DynamicPixPaymentWithDueDate{}} =
               Changesets.cast_and_apply(DynamicPixPaymentWithDueDate, payload)
    end

    test "validate 'valor.desconto.descontoDataFixa' when 'valor.desconto.modalidade' either 1 or 2" do
      payload = %{
        "revisao" => 0,
        "chave" => "9463d2b0-2b1a-4157-80fe-344ccf0f7e13",
        "status" => "ATIVA",
        "txid" => "123456789012345678901234567890",
        "solicitacaoPagador" => "Solicitação",
        "calendario" => %{
          "criacao" => "2021-02-24 22:10:58.154290Z",
          "apresentacao" => "2021-02-24 22:23:49.246328Z",
          "dataDeVencimento" => "2021-02-28 22:23:49.246328Z",
          "validadeAposVencimento" => 2
        },
        "devedor" => %{
          "cpf" => Brcpfcnpj.cpf_generate(),
          "nome" => "Ciclano"
        },
        "valor" => %{
          "original" => "1.30",
          "final" => "1.30",
          "abatimento" => %{
            "modalidade" => 1,
            "valorPerc" => "7.00"
          },
          "desconto" => %{
            "modalidade" => Enum.random([1, 2]),
            "descontoDataFixa" => [
              %{
                "valorPerc" => "7.00",
                "data" => "2021-03-01"
              }
            ]
          },
          "juros" => %{
            "modalidade" => 2,
            "valorPerc" => "6.40"
          },
          "multa" => %{
            "modalidade" => 1,
            "valorPerc" => "6.00"
          }
        },
        "recebedor" => %{
          "cpf" => Brcpfcnpj.cpf_generate(),
          "nome" => "Fulano",
          "nomeFantasia" => "Loja do Fulano",
          "cidade" => "Rio de Janeiro",
          "uf" => "RJ",
          "cep" => "28610-160",
          "logradouro" => "Avenida Brasil"
        },
        "infoAdicionais" => [
          %{
            "nome" => "Campo",
            "valor" => "Valor"
          }
        ]
      }

      assert {:ok, %DynamicPixPaymentWithDueDate{}} =
               Changesets.cast_and_apply(DynamicPixPaymentWithDueDate, payload)
    end
  end
end
