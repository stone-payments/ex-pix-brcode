defmodule ExPixBRCode.Payments.Models.StaticPixPaymentTest do
  use ExUnit.Case, async: true

  alias ExPixBRCode.BRCodes.Decoder
  alias ExPixBRCode.BRCodes.Models.BRCode
  alias ExPixBRCode.Payments
  alias ExPixBRCode.Payments.Models.StaticPixPayment

  describe "from_brcode/2 for static payments" do
    test "successfully cast static payment without optional fields" do
      assert {:ok, brcode} =
               Decoder.decode_to(
                 "00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D"
               )

      assert brcode == %BRCode{
               additional_data_field_template: %BRCode.AdditionalDataField{reference_label: "***"},
               country_code: "BR",
               crc: "1D3D",
               merchant_account_information: %BRCode.MerchantAccountInfo{
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
               postal_code: nil,
               transaction_amount: nil,
               transaction_currency: "986",
               type: :static
             }

      assert {:ok,
              %StaticPixPayment{
                additional_information: nil,
                key: "123e4567-e12b-12d1-a456-426655440000",
                key_type: "random_key",
                transaction_amount: nil,
                transaction_id: "***"
              }} == Payments.from_brcode(nil, brcode)
    end

    test "successfully cast static payment with optional fields" do
      assert {:ok, brcode} =
               Decoder.decode_to(
                 "00020126490014BR.GOV.BCB.PIX0111111111111110212Vacina covid52040000530398654031005802BR5904CARL6010SAN.FIERRO62210517Lojinha da paixao63045982"
               )

      assert brcode == %BRCode{
               additional_data_field_template: %BRCode.AdditionalDataField{
                 reference_label: "Lojinha da paixao"
               },
               country_code: "BR",
               crc: "5982",
               merchant_account_information: %BRCode.MerchantAccountInfo{
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
               postal_code: nil,
               transaction_amount: "100",
               transaction_currency: "986",
               type: :static
             }

      assert {:ok,
              %StaticPixPayment{
                additional_information: "Vacina covid",
                key: "11111111111",
                key_type: "cpf",
                transaction_amount: "100",
                transaction_id: "Lojinha da paixao"
              }} == Payments.from_brcode(nil, brcode)
    end
  end
end
