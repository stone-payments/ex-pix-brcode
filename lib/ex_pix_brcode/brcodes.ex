defmodule ExPixBRCode.BRCodes do
  @moduledoc """
  Utilities for BRCode.

  BRCode is a specialization of the EMV®-QRCPS specification for MPM (merchant-presented mode).
  """

  alias ExPixBRCode.BRCodes.Decoder
  alias ExPixBRCode.BRCodes.Models.BRCode

  defdelegate decode(brcode, opts \\ []), to: Decoder
  defdelegate decode_to(brcode, opts \\ [], schema \\ BRCode), to: Decoder
end
