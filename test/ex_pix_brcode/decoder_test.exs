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
               "00020126490014BR.GOV.BCB.PIX0111129989307430212Vacina covid52040000530398654031.55802BR5918BYANCA Q M PEREIRA6009SAO.PAULO62210517Lojinha da paixao63044575"
             ) ==
               {:ok,
                %BRCode{
                  additional_data_field_template: %AdditionalDataField{
                    reference_label: "Lojinha da paixao"
                  },
                  country_code: "BR",
                  crc: "4575",
                  merchant_account_information: %MerchantAccountInfo{
                    chave: "12998930743",
                    gui: "BR.GOV.BCB.PIX",
                    info_adicional: nil,
                    url: nil
                  },
                  merchant_category_code: "0000",
                  merchant_city: "SAO.PAULO",
                  merchant_name: "BYANCA Q M PEREIRA",
                  payload_format_indicator: "01",
                  point_of_initiation_method: nil,
                  transaction_amount: "1.5",
                  transaction_currency: "986",
                  type: :static
                }}
    end
  end
end
