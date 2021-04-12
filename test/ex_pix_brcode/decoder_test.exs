defmodule ExPixBRCode.DecoderTest do
  use ExUnit.Case, async: true

  alias ExPixBRCode.BRCodes.Decoder
  alias ExPixBRCode.BRCodes.Models.BRCode
  alias ExPixBRCode.BRCodes.Models.BRCode.{AdditionalDataField, MerchantAccountInfo}

  describe "decode/2" do
    test "succeeds on BACEN example" do
      assert Decoder.decode(
               "00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D"
             ) ==
               {:ok,
                %{
                  "additional_data_field_template" => %{"reference_label" => "***"},
                  "country_code" => "BR",
                  "crc" => "1D3D",
                  "merchant_account_information" => %{
                    "gui" => "br.gov.bcb.pix",
                    "chave" => "123e4567-e12b-12d1-a456-426655440000"
                  },
                  "merchant_category_code" => "0000",
                  "merchant_city" => "BRASILIA",
                  "merchant_name" => "Fulano de Tal",
                  "payload_format_indicator" => "01",
                  "transaction_currency" => "986"
                }}
    end

    test "can handle non-ascii characters" do
      assert Decoder.decode(
               "00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913Fulano de Tal6008BRASÍLIA62070503***6304B4F6"
             ) ==
               {:ok,
                %{
                  "additional_data_field_template" => %{"reference_label" => "***"},
                  "country_code" => "BR",
                  "crc" => "B4F6",
                  "merchant_account_information" => %{
                    "gui" => "br.gov.bcb.pix",
                    "chave" => "123e4567-e12b-12d1-a456-426655440000"
                  },
                  "merchant_category_code" => "0000",
                  "merchant_city" => "BRASÍLIA",
                  "merchant_name" => "Fulano de Tal",
                  "payload_format_indicator" => "01",
                  "transaction_currency" => "986"
                }}
    end

    test "fails when encoded length is invalid" do
      invalid_units_digit_length = "000AXYZ2BFE"
      invalid_tens_digit_length = "00A0XYZA8E8"

      assert {:error, {:validation, {:invalid_length_for_tag, "00"}}} ==
               Decoder.decode(invalid_units_digit_length)

      assert {:error, {:validation, {:invalid_length_for_tag, "00"}}} ==
               Decoder.decode(invalid_tens_digit_length)
    end

    test "fails when upon corrupted data" do
      # The correct CRC would be "2BFE"
      valid_data = "000AXYZ"
      invalid_crc = "EFB2"
      input = valid_data <> invalid_crc

      assert {:error, :invalid_crc} ==
               Decoder.decode(input)
    end

    test "fails when value has incorrect length" do
      encoded = "421337BF8A"

      assert {:error, {:validation, {:unexpected_value_length_for_key, "42"}}} ==
               Decoder.decode(encoded)
    end
  end

  describe "decode_to/2" do
    test "succeeds on BACEN example" do
      assert Decoder.decode_to(
               "00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D"
             ) ==
               {:ok,
                %BRCode{
                  additional_data_field_template: %AdditionalDataField{
                    reference_label: "***"
                  },
                  country_code: "BR",
                  crc: "1D3D",
                  merchant_account_information: %MerchantAccountInfo{
                    chave: "123e4567-e12b-12d1-a456-426655440000",
                    gui: "br.gov.bcb.pix",
                    info_adicional: nil,
                    url: nil
                  },
                  merchant_category_code: "0000",
                  merchant_city: "BRASILIA",
                  merchant_name: "Fulano de Tal",
                  payload_format_indicator: "01",
                  point_of_initiation_method: nil,
                  transaction_amount: nil,
                  transaction_currency: "986",
                  type: :static
                }}
    end

    test "succeeds with examples from financial institutions (REDACTED FIELDS) - 2020-11-23" do
      brcode =
        "00020101021226850014br.gov.bcb.pix2563exemplodeurl.com.br/pix/v2/11111111-1111-1111-1111-11111111111152040000530398654040.015802BR5925TESTE DE TESTE DO TESTEIE6014RIO DE JANEIRO62070503***6304CD52"

      assert Decoder.decode_to(brcode) ==
               {:ok,
                %BRCode{
                  additional_data_field_template: %AdditionalDataField{
                    reference_label: "***"
                  },
                  country_code: "BR",
                  crc: "CD52",
                  merchant_account_information: %MerchantAccountInfo{
                    chave: nil,
                    gui: "br.gov.bcb.pix",
                    info_adicional: nil,
                    url: "exemplodeurl.com.br/pix/v2/11111111-1111-1111-1111-111111111111"
                  },
                  merchant_category_code: "0000",
                  merchant_city: "RIO DE JANEIRO",
                  merchant_name: "TESTE DE TESTE DO TESTEIE",
                  payload_format_indicator: "01",
                  point_of_initiation_method: "12",
                  transaction_amount: "0.01",
                  transaction_currency: "986",
                  type: :dynamic_payment_immediate
                }}

      brcode =
        "00020126580014BR.GOV.BCB.PIX013611111111-1111-1111-1111-11111111111152040000530398654040.015802BR5925TESTE DO TESTE DO TESTEIE6009SAO PAULO6226052211111111111111111111116304642D"

      assert Decoder.decode_to(brcode) ==
               {:ok,
                %BRCode{
                  additional_data_field_template: %AdditionalDataField{
                    reference_label: "1111111111111111111111"
                  },
                  country_code: "BR",
                  crc: "642D",
                  merchant_account_information: %MerchantAccountInfo{
                    chave: "11111111-1111-1111-1111-111111111111",
                    gui: "BR.GOV.BCB.PIX",
                    info_adicional: nil,
                    url: nil
                  },
                  merchant_category_code: "0000",
                  merchant_city: "SAO PAULO",
                  merchant_name: "TESTE DO TESTE DO TESTEIE",
                  payload_format_indicator: "01",
                  point_of_initiation_method: nil,
                  transaction_amount: "0.01",
                  transaction_currency: "986",
                  type: :static
                }}

      brcode =
        "00020101021226850014br.gov.bcb.pix2563exemplodeurl2.com.br/qr/v2/11111111-1111-1111-1111-11111111111152040000530398654041.005802BR5925TESTE DO TESTE DO TESTEIE6009NOVA LIMA62070503***63040B0F"

      assert Decoder.decode_to(brcode) ==
               {:ok,
                %BRCode{
                  additional_data_field_template: %AdditionalDataField{
                    reference_label: "***"
                  },
                  country_code: "BR",
                  crc: "0B0F",
                  merchant_account_information: %MerchantAccountInfo{
                    chave: nil,
                    gui: "br.gov.bcb.pix",
                    info_adicional: nil,
                    url: "exemplodeurl2.com.br/qr/v2/11111111-1111-1111-1111-111111111111"
                  },
                  merchant_category_code: "0000",
                  merchant_city: "NOVA LIMA",
                  merchant_name: "TESTE DO TESTE DO TESTEIE",
                  payload_format_indicator: "01",
                  point_of_initiation_method: "12",
                  transaction_amount: "1.00",
                  transaction_currency: "986",
                  type: :dynamic_payment_immediate
                }}

      brcode =
        "00020126580014BR.GOV.BCB.PIX013611111111-1111-1111-1111-11111111111152040000530398654040.015802BR5925Teste do Teste do TesteIE6009SAO PAULO61081111111162160512NUgpnvaS87Ts6304760E"

      assert Decoder.decode_to(brcode) ==
               {:ok,
                %BRCode{
                  additional_data_field_template: %AdditionalDataField{
                    reference_label: "NUgpnvaS87Ts"
                  },
                  country_code: "BR",
                  crc: "760E",
                  merchant_account_information: %MerchantAccountInfo{
                    chave: "11111111-1111-1111-1111-111111111111",
                    gui: "BR.GOV.BCB.PIX",
                    info_adicional: nil,
                    url: nil
                  },
                  merchant_category_code: "0000",
                  merchant_city: "SAO PAULO",
                  merchant_name: "Teste do Teste do TesteIE",
                  payload_format_indicator: "01",
                  point_of_initiation_method: nil,
                  postal_code: "11111111",
                  transaction_amount: "0.01",
                  transaction_currency: "986",
                  type: :static
                }}

      brcode =
        "00020101021226820014br.gov.bcb.pix2560exemplodeurl.com/pix/v2/11111111-1111-1111-1111-11111111111152040000530398654045.805802BR5925TESTE DO TESTE DO TESTEIE6014RIO DE JANEIRO622905251111111111111111111111111630449F9"

      assert Decoder.decode_to(brcode) ==
               {:ok,
                %BRCode{
                  additional_data_field_template: %AdditionalDataField{
                    reference_label: "1111111111111111111111111"
                  },
                  country_code: "BR",
                  crc: "49F9",
                  merchant_account_information: %MerchantAccountInfo{
                    chave: nil,
                    gui: "br.gov.bcb.pix",
                    info_adicional: nil,
                    url: "exemplodeurl.com/pix/v2/11111111-1111-1111-1111-111111111111"
                  },
                  merchant_category_code: "0000",
                  merchant_city: "RIO DE JANEIRO",
                  merchant_name: "TESTE DO TESTE DO TESTEIE",
                  payload_format_indicator: "01",
                  point_of_initiation_method: "12",
                  postal_code: nil,
                  transaction_amount: "5.80",
                  transaction_currency: "986",
                  type: :dynamic_payment_immediate
                }}
    end

    test "succeeds with BRCode has free text on reference_label field" do
      assert Decoder.decode_to(
               "00020126490014BR.GOV.BCB.PIX0111111111111110212Vacina covid52040000530398654031005802BR5904CARL6010SAN.FIERRO62100506b4b4c46304040C"
             ) ==
               {:ok,
                %BRCode{
                  additional_data_field_template: %AdditionalDataField{
                    reference_label: "b4b4c4"
                  },
                  country_code: "BR",
                  crc: "040C",
                  merchant_account_information: %MerchantAccountInfo{
                    chave: "11111111111",
                    gui: "BR.GOV.BCB.PIX",
                    info_adicional: "Vacina covid",
                    url: nil
                  },
                  merchant_category_code: "0000",
                  merchant_city: "SAN.FIERRO",
                  merchant_name: "CARL",
                  payload_format_indicator: "01",
                  point_of_initiation_method: nil,
                  transaction_amount: "100",
                  transaction_currency: "986",
                  type: :static
                }}
    end

    test "succeds with BRCode has transaction_amount with '10'" do
      assert Decoder.decode_to(
               "00020126490014BR.GOV.BCB.PIX0111111111111110212Vacina covid5204000053039865402105802BR5904CARL6010SAN.FIERRO62090505o1ab46304970D"
             ) ==
               {:ok,
                %BRCode{
                  additional_data_field_template: %AdditionalDataField{
                    reference_label: "o1ab4"
                  },
                  country_code: "BR",
                  crc: "970D",
                  merchant_account_information: %MerchantAccountInfo{
                    chave: "11111111111",
                    gui: "BR.GOV.BCB.PIX",
                    info_adicional: "Vacina covid",
                    url: nil
                  },
                  merchant_category_code: "0000",
                  merchant_city: "SAN.FIERRO",
                  merchant_name: "CARL",
                  payload_format_indicator: "01",
                  point_of_initiation_method: nil,
                  transaction_amount: "10",
                  transaction_currency: "986",
                  type: :static
                }}
    end

    test "succeds with BRCode has transaction_amount with '10.'" do
      assert Decoder.decode_to(
               "00020126490014BR.GOV.BCB.PIX0111111111111110212Vacina covid520400005303986540310.5802BR5904CARL6010SAN.FIERRO62100506b4b4c463049878"
             ) ==
               {:ok,
                %BRCode{
                  additional_data_field_template: %AdditionalDataField{
                    reference_label: "b4b4c4"
                  },
                  country_code: "BR",
                  crc: "9878",
                  merchant_account_information: %MerchantAccountInfo{
                    chave: "11111111111",
                    gui: "BR.GOV.BCB.PIX",
                    info_adicional: "Vacina covid",
                    url: nil
                  },
                  merchant_category_code: "0000",
                  merchant_city: "SAN.FIERRO",
                  merchant_name: "CARL",
                  payload_format_indicator: "01",
                  point_of_initiation_method: nil,
                  transaction_amount: "10.",
                  transaction_currency: "986",
                  type: :static
                }}
    end

    test "succeds with BRCode has transaction_amount with '0.9'" do
      assert Decoder.decode_to(
               "00020126490014BR.GOV.BCB.PIX0111111111111110212Vacina covid52040000530398654030.95802BR5904CARL6010SAN.FIERRO62100506b4b4c463044D69"
             ) ==
               {:ok,
                %BRCode{
                  additional_data_field_template: %AdditionalDataField{
                    reference_label: "b4b4c4"
                  },
                  country_code: "BR",
                  crc: "4D69",
                  merchant_account_information: %MerchantAccountInfo{
                    chave: "11111111111",
                    gui: "BR.GOV.BCB.PIX",
                    info_adicional: "Vacina covid",
                    url: nil
                  },
                  merchant_category_code: "0000",
                  merchant_city: "SAN.FIERRO",
                  merchant_name: "CARL",
                  payload_format_indicator: "01",
                  point_of_initiation_method: nil,
                  transaction_amount: "0.9",
                  transaction_currency: "986",
                  type: :static
                }}
    end

    test "succeeds on BRCode type identification with dynamic_payment_with_due_date type" do
      assert Decoder.decode_to(
               "00020126990014br.gov.bcb.pix2577qr-h.sandbox.pix.bcb.gov.br/rest/api/v2/cobv/9b95a87c10a84d65bcbf55a48a2e50c85204000053039865802BR5903Pix6008BRASILIA62070503***63048ECF"
             ) == {
               :ok,
               %BRCode{
                 additional_data_field_template: %AdditionalDataField{reference_label: "***"},
                 country_code: "BR",
                 crc: "8ECF",
                 merchant_account_information: %MerchantAccountInfo{
                   chave: nil,
                   gui: "br.gov.bcb.pix",
                   info_adicional: nil,
                   url:
                     "qr-h.sandbox.pix.bcb.gov.br/rest/api/v2/cobv/9b95a87c10a84d65bcbf55a48a2e50c8"
                 },
                 merchant_category_code: "0000",
                 merchant_city: "BRASILIA",
                 merchant_name: "Pix",
                 payload_format_indicator: "01",
                 point_of_initiation_method: nil,
                 postal_code: nil,
                 transaction_amount: nil,
                 transaction_currency: "986",
                 type: :dynamic_payment_with_due_date
               }
             }
    end

    test "succeeds on validate BRCode size" do
      assert {:error, :invalid_input_size} =
               Decoder.decode_to(
                 "00020104141234567890123426580014BR.GOV.BCB.PIX0136123e4567-e12b-12d1-a456-42665544000027300012BR.COM.OUTRO011001234567895204000053039865406123.455802BR5915NOMEDORECEBEDOR6008BRASILIA61087007490062530515RP123456789201950300017BR.GOV.BCB.PIX12301051.0.080450014BR.GOV.BCB.PIX0123PADRAO.URL.PIX/0123ABCD81390012BR.COM.OUTRO01190123.ABCD.3456.WXYZ8899009588888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888895500519090909090909090909090909090909090909090909090909096304ABE9"
               )
    end

    test "succeeds on validate invalid format for merchant_name BRCode field" do
      assert {:error, {:validation, changeset}} =
               Decoder.decode_to(
                 "00020126830014br.gov.bcb.pix01364004901d-bd85-4769-8e52-cb4c42c506dc0221Jornada pagador 57768520400005303986540573.625802BR5926BANCOCENTRALDOBRASIL0003816008BRASILIA62080504oooo6304EFF5"
               )

      assert [
               merchant_name:
                 {"should be at most %{count} character(s)",
                  [count: 25, validation: :length, kind: :max, type: :string]}
             ] == changeset.errors
    end

    test "succeeds on validate invalid format for merchant_city BRCode field" do
      assert {:error, {:validation, changeset}} =
               Decoder.decode_to(
                 "00020126830014br.gov.bcb.pix01364004901d-bd85-4769-8e52-cb4c42c506dc0221Jornada pagador 57768520400005303986540573.625802BR5903Pix6008Brasília62080504oooo6304B243"
               )

      assert [merchant_city: {"has invalid format", [validation: :format]}] == changeset.errors
    end

    test "succeeds on validate invalid format for reference_label BRCode field" do
      assert {:error, {:validation, changeset}} =
               Decoder.decode_to(
                 "00020104141234567890123426580014BR.GOV.BCB.PIX0136123e4567-e12b-12d1-a456-42665544000027300012BR.COM.OUTRO011001234567895204000053039865406123.455802BR5917NOME DO RECEBEDOR6008BRASILIA610870074900622005161234567890👀1234580390012BR.COM.OUTRO01190123.ABCD.3456.WXYZ630475EF"
               )

      assert [reference_label: {"has invalid format", [validation: :format]}] =
               changeset.changes.additional_data_field_template.errors
    end

    test "Succeeds on validate protocol presence on URL" do
      assert {:error, {:validation, changeset}} =
               Decoder.decode_to(
                 "00020126990014br.gov.bcb.pix2577https://qr-h.sandbox.pix.bcb.gov.br/rest/api/v2/ac8ab4efe7db4200885f5ab3c34725204000053039865802BR5903Pix6008BRASILIA62070503***63041043"
               )

      assert [url: {"URL with protocol", []}] ==
               changeset.changes.merchant_account_information.errors
    end
  end
end
