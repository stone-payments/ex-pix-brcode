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

    test "successfully validates a proper payload for 'original' with value 0 when 'modalidadeAlteracao' has value 1" do
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
        "valor" => %{
          "original" => "0",
          "modalidadeAlteracao" => "1"
        }
      }

      assert {:ok, %DynamicImmediatePixPayment{}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)
    end

    test "successfully validates field 'modalidadeAlteracao'" do
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
        "valor" => %{
          "original" => "0",
          "modalidadeAlteracao" => "0"
        }
      }

      assert {:error, {:validation, %{changes: %{valor: %{errors: errors, valid?: false}}}}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      assert errors == [
               original:
                 {"must be greater than %{number}",
                  [validation: :number, kind: :greater_than, number: 0]}
             ]
    end

    for modalidadeAgente <- ["AGTEC", "AGTOT", "AGPSS"] do
      test "successfully validates a proper withdrawal payload without optional fields and 'saque.modalidadeAgente' #{
             modalidadeAgente
           } " do
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
          "valor" => %{
            "original" => "0",
            "retirada" => %{
              "saque" => %{
                "valor" => "10.00",
                "prestadorDoServicoDeSaque" => "16501555",
                "modalidadeAgente" => unquote(modalidadeAgente)
              }
            }
          }
        }

        assert {:ok, %DynamicImmediatePixPayment{}} =
                 Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)
      end
    end

    test "successfully validates a proper withdrawal payload with optional fields" do
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
        "valor" => %{
          "original" => "0",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "saque" => %{
              "valor" => "10.00",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:ok, %DynamicImmediatePixPayment{}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)
    end

    test "successfully validates field 'original' for withdrawal" do
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
        "valor" => %{
          "original" => "10.00",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "saque" => %{
              "valor" => "10.00",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:error, {:validation, %{changes: %{valor: %{errors: errors, valid?: false}}}}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      assert errors == [
               original:
                 {"must be equal to %{number}", [validation: :number, kind: :equal_to, number: 0]}
             ]
    end

    test "successfully validates field 'modalidadeAlteracao' for withdrawal" do
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
        "valor" => %{
          "original" => "0",
          "modalidadeAlteracao" => "1",
          "retirada" => %{
            "saque" => %{
              "valor" => "10.00",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:error, {:validation, %{changes: %{valor: %{errors: errors, valid?: false}}}}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      assert errors == [
               modalidadeAlteracao: {"must be 0 when it is withdrawal or payment with change", []}
             ]
    end

    test "successfully validates field 'saque.modalidadeAlteracao' and 'saque.valor' for withdrawal" do
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
        "valor" => %{
          "original" => "0",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "saque" => %{
              "valor" => "0",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:error,
              {:validation,
               %{
                 changes: %{
                   valor: %{
                     changes: %{retirada: %{changes: %{saque: %{errors: errors, valid?: false}}}}
                   }
                 }
               }}} = Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      assert errors == [
               valor:
                 {"must be greater than %{number}",
                  [validation: :number, kind: :greater_than, number: 0]}
             ]
    end

    test "successfully validates a proper payload for 'valor' with value 0 when 'saque.modalidadeAlteracao' has value 1" do
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
        "valor" => %{
          "original" => "0",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "saque" => %{
              "valor" => "0",
              "modalidadeAlteracao" => "1",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:ok, %DynamicImmediatePixPayment{}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)
    end

    test "successfully validates field 'saque.prestadorDoServicoDeSaque' length for withdrawal" do
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
        "valor" => %{
          "original" => "0",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "saque" => %{
              "valor" => "10",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "1650155",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:error,
              {:validation,
               %{
                 changes: %{
                   valor: %{
                     changes: %{retirada: %{changes: %{saque: %{errors: errors, valid?: false}}}}
                   }
                 }
               }}} = Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      assert errors == [
               prestadorDoServicoDeSaque:
                 {"should be %{count} character(s)",
                  [{:count, 8}, {:validation, :length}, {:kind, :is}, {:type, :string}]}
             ]
    end

    test "successfully validates field 'saque.prestadorDoServicoDeSaque' format for withdrawal" do
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
        "valor" => %{
          "original" => "0",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "saque" => %{
              "valor" => "10",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "1650155a",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:error,
              {:validation,
               %{
                 changes: %{
                   valor: %{
                     changes: %{retirada: %{changes: %{saque: %{errors: errors, valid?: false}}}}
                   }
                 }
               }}} = Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      # Accepts only digits
      assert errors == [prestadorDoServicoDeSaque: {"has invalid format", [validation: :format]}]
    end

    test "successfully validates field 'saque.modalidadeAgente' format for withdrawal" do
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
        "valor" => %{
          "original" => "0",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "saque" => %{
              "valor" => "10",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTT"
            }
          }
        }
      }

      assert {:error,
              {:validation,
               %{
                 changes: %{
                   valor: %{
                     changes: %{
                       retirada: %{changes: %{saque: %{errors: errors, valid?: false}}}
                     }
                   }
                 }
               }}} = Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      assert errors == [
               modalidadeAgente:
                 {"is invalid", [{:validation, :inclusion}, {:enum, ["AGTEC", "AGTOT", "AGPSS"]}]}
             ]
    end

    # AQUUUUUUUUUUUUUUUUUUUUUUIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIi!!!!!!!!!!!!!!!!!
    # AQUUUUUUUUUUUUUUUUUUUUUUIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIi!!!!!!!!!!!!!!!!!
    # AQUUUUUUUUUUUUUUUUUUUUUUIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIi!!!!!!!!!!!!!!!!!
    # AQUUUUUUUUUUUUUUUUUUUUUUIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIi!!!!!!!!!!!!!!!!!
    # AQUUUUUUUUUUUUUUUUUUUUUUIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIi!!!!!!!!!!!!!!!!!
    # AQUUUUUUUUUUUUUUUUUUUUUUIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIi!!!!!!!!!!!!!!!!!
    # AQUUUUUUUUUUUUUUUUUUUUUUIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIi!!!!!!!!!!!!!!!!!
    # AQUUUUUUUUUUUUUUUUUUUUUUIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIi!!!!!!!!!!!!!!!!!
    # AQUUUUUUUUUUUUUUUUUUUUUUIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIi!!!!!!!!!!!!!!!!!
    # AQUUUUUUUUUUUUUUUUUUUUUUIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIi!!!!!!!!!!!!!!!!!

    test "successfully validates a proper payment with change payload without optional fields" do
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
        "valor" => %{
          "original" => "10",
          "retirada" => %{
            "troco" => %{
              "valor" => "10.00",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:ok, %DynamicImmediatePixPayment{}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)
    end

    test "successfully validates a proper payment with change payload with optional fields" do
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
        "valor" => %{
          "original" => "10",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "troco" => %{
              "valor" => "10.00",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:ok, %DynamicImmediatePixPayment{}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)
    end

    test "successfully validates field 'original' for payment with change" do
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
        "valor" => %{
          "original" => "0",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "troco" => %{
              "valor" => "10.00",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:error, {:validation, %{changes: %{valor: %{errors: errors, valid?: false}}}}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      assert errors == [
               original:
                 {"must be greater than %{number}",
                  [validation: :number, kind: :greater_than, number: 0]}
             ]
    end

    test "successfully validates field 'modalidadeAlteracao' for payment with change" do
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
        "valor" => %{
          "original" => "10",
          "modalidadeAlteracao" => "1",
          "retirada" => %{
            "troco" => %{
              "valor" => "10.00",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:error, {:validation, %{changes: %{valor: %{errors: errors, valid?: false}}}}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      assert errors == [
               modalidadeAlteracao: {"must be 0 when it is withdrawal or payment with change", []}
             ]
    end

    test "successfully validates field 'troco.modalidadeAlteracao' and 'troco.valor' for payment with change" do
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
        "valor" => %{
          "original" => "10",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "troco" => %{
              "valor" => "0",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:error,
              {:validation,
               %{
                 changes: %{
                   valor: %{
                     changes: %{retirada: %{changes: %{troco: %{errors: errors, valid?: false}}}}
                   }
                 }
               }}} = Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      assert errors == [
               valor:
                 {"must be greater than %{number}",
                  [validation: :number, kind: :greater_than, number: 0]}
             ]
    end

    test "successfully validates a proper payment with change payload for 'valor' with value 0 when 'troco.modalidadeAlteracao' has value 1" do
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
        "valor" => %{
          "original" => "10",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "troco" => %{
              "valor" => "0",
              "modalidadeAlteracao" => "1",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:ok, %DynamicImmediatePixPayment{}} =
               Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)
    end

    test "successfully validates field 'troco.prestadorDoServicoDeSaque' length for payment with change" do
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
        "valor" => %{
          "original" => "10",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "troco" => %{
              "valor" => "10",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "1650155",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:error,
              {:validation,
               %{
                 changes: %{
                   valor: %{
                     changes: %{retirada: %{changes: %{troco: %{errors: errors, valid?: false}}}}
                   }
                 }
               }}} = Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      assert errors == [
               prestadorDoServicoDeSaque:
                 {"should be %{count} character(s)",
                  [{:count, 8}, {:validation, :length}, {:kind, :is}, {:type, :string}]}
             ]
    end

    test "successfully validates field 'troco.prestadorDoServicoDeSaque' format for payment with change" do
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
        "valor" => %{
          "original" => "10",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "troco" => %{
              "valor" => "10",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "1650155a",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:error,
              {:validation,
               %{
                 changes: %{
                   valor: %{
                     changes: %{retirada: %{changes: %{troco: %{errors: errors, valid?: false}}}}
                   }
                 }
               }}} = Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      # Accepts only digits
      assert errors == [prestadorDoServicoDeSaque: {"has invalid format", [validation: :format]}]
    end

    test "successfully validates field 'saque.modalidadeAgente' format for payment with change" do
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
        "valor" => %{
          "original" => "0",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "troco" => %{
              "valor" => "10",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTT"
            }
          }
        }
      }

      assert {:error,
              {:validation,
               %{
                 changes: %{
                   valor: %{
                     changes: %{
                       retirada: %{changes: %{troco: %{errors: errors, valid?: false}}}
                     }
                   }
                 }
               }}} = Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      assert errors == [
               modalidadeAgente: {"is invalid", [{:validation, :inclusion}, {:enum, ["AGTEC"]}]}
             ]
    end

    test "successfully validates if there is only withdrawal or payment with change" do
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
        "valor" => %{
          "original" => "0",
          "modalidadeAlteracao" => "0",
          "retirada" => %{
            "saque" => %{
              "valor" => "10",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTEC"
            },
            "troco" => %{
              "valor" => "10",
              "modalidadeAlteracao" => "0",
              "prestadorDoServicoDeSaque" => "16501555",
              "modalidadeAgente" => "AGTEC"
            }
          }
        }
      }

      assert {:error,
              {:validation,
               %{
                 changes: %{
                   valor: %{errors: errors, valid?: false}
                 }
               }}} = Changesets.cast_and_apply(DynamicImmediatePixPayment, payload)

      assert errors == [
               retirada: {"only one of withdrawal or payment with change must be present", []}
             ]
    end
  end
end
