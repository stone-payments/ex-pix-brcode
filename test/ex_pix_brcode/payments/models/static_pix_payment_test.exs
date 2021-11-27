defmodule ExPixBRCode.Payments.Models.StaticPixPaymentTest do
  use ExUnit.Case, async: true

  alias ExPixBRCode.Changesets
  alias ExPixBRCode.Payments.Models.StaticPixPayment

  describe "changeset/2" do
    test "successfully validates static pix payment" do
      payload = %{
        "key" => "9463a2a0-2b1a-4157-80fe-344ccf0f7e13",
        "key_type" => "random_key",
        "transaction_id" => "000112aa",
        "transaction_amount" => "10.36"
      }

      assert {:ok, %StaticPixPayment{}} = Changesets.cast_and_apply(StaticPixPayment, payload)
    end

    test "successfully on validates a proper UUID random key" do
      payload = %{
        "key" => "9463A2A0-2b1A-4157-80fe-344ccf0f7e13",
        "key_type" => "random_key",
        "transaction_id" => "000112aa",
        "transaction_amount" => "10.36"
      }

      assert {:error, {:validation, changeset}} =
               Changesets.cast_and_apply(StaticPixPayment, payload)

      assert [key: {"has invalid format", []}] == changeset.errors
    end

    test "successfully validates static pix payment with withdrawal service provider" do
      payload = %{
        "key" => "9463a2a0-2b1a-4157-80fe-344ccf0f7e13",
        "key_type" => "random_key",
        "transaction_id" => "000112aa",
        "transaction_amount" => "10.36",
        "withdrawal_service_provider" => "16501555"
      }

      assert {:ok, %StaticPixPayment{}} = Changesets.cast_and_apply(StaticPixPayment, payload)
    end

    test "successfully on validates a proper withdrawal service provider" do
      payload = %{
        "key" => "9463a2a0-2b1a-4157-80fe-344ccf0f7e13",
        "key_type" => "random_key",
        "transaction_id" => "000112aa",
        "transaction_amount" => "10.36",
        "withdrawal_service_provider" => "16501"
      }

      assert {:error, {:validation, changeset}} =
               Changesets.cast_and_apply(StaticPixPayment, payload)

      assert [
               withdrawal_service_provider:
                 {"should be %{count} character(s)",
                  [{:count, 8}, {:validation, :length}, {:kind, :is}, {:type, :string}]}
             ] == changeset.errors
    end
  end
end
