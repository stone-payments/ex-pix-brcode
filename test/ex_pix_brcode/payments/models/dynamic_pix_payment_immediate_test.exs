defmodule ExPixBRCode.Payments.Models.DynamicImmediatePixPaymentTest do
  use ExUnit.Case, async: true

  alias ExPixBRCode.Changesets
  alias ExPixBRCode.Payments.Models.DynamicImmediatePixPayment

  describe "changeset/2" do
    test "only validate 'devedor.nome' if cpf or cnpj is present" do
      payload = %{
        "calendario" => %{
          "apresentacao" => "2020-11-25T18:06:39Z",
          "criacao" => "2020-11-13T13:46:43Z",
          "expiracao" => 3600
        },
        "chave" => "9463d2b0-2b1a-4157-80fe-344ccf0f7e13",
        "devedor" => %{"cpf" => nil, "cnpj" => nil, "nome" => nil},
        "infoAdicionais" => [%{"nome" => "Campo", "valor" => "Valor"}],
        "revisao" => 0,
        "solicitacaoPagador" => "Solicitação",
        "status" => "ATIVA",
        "txid" => "123456789012345678901234567890",
        "valor" => %{"original" => "1.30"}
      }

      assert {:ok, %DynamicImmediatePixPayment{}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)
    end

    test "successfully validates a proper payload" do
      payload = %{
        "calendario" => %{
          "apresentacao" => "2020-11-25T18:06:39Z",
          "criacao" => "2020-11-13T13:46:43Z",
          "expiracao" => 3600
        },
        "chave" => "9463d2b0-2b1a-4157-80fe-344ccf0f7e13",
        "devedor" => %{"cpf" => Brcpfcnpj.cpf_generate(), "nome" => "Fulano"},
        "infoAdicionais" => [%{"nome" => "Campo", "valor" => "Valor"}],
        "revisao" => 0,
        "solicitacaoPagador" => "Solicitação",
        "status" => "ATIVA",
        "txid" => "123456789012345678901234567890",
        "valor" => %{"original" => "1.30"}
      }

      assert {:ok, %DynamicImmediatePixPayment{}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)
    end

    test "successfully validates a proper payload without optional fields" do
      payload = %{
        "calendario" => %{
          "apresentacao" => "2020-11-25T18:06:39Z",
          "criacao" => "2020-11-13T13:46:43Z"
        },
        "chave" => "9463d2b0-2b1a-4157-80fe-344ccf0f7e13",
        "devedor" => nil,
        "infoAdicionais" => nil,
        "revisao" => 0,
        "solicitacaoPagador" => nil,
        "status" => "ATIVA",
        "txid" => "123456789012345678901234567890",
        "valor" => %{"original" => "1.30"}
      }

      assert {:ok, %DynamicImmediatePixPayment{}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)
    end

    test "successfully validates a proper payload without applying txid minimum length restriction" do
      payload = %{
        "calendario" => %{
          "apresentacao" => "2020-11-25T18:06:39Z",
          "criacao" => "2020-11-13T13:46:43Z",
          "expiracao" => 3600
        },
        "chave" => "9463d2b0-2b1a-4157-80fe-344ccf0f7e13",
        "devedor" => %{"cpf" => Brcpfcnpj.cpf_generate(), "nome" => "Fulano"},
        "infoAdicionais" => [%{"nome" => "Campo", "valor" => "Valor"}],
        "revisao" => 0,
        "solicitacaoPagador" => "Solicitação",
        "status" => "ATIVA",
        "txid" => "1234",
        "valor" => %{"original" => "1.30"}
      }

      assert {:ok, %DynamicImmediatePixPayment{}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)
    end

  end
end
