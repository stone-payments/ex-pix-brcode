The following is a benchmark comparison between the current implementation
and the one proposed in this pull request

```shell
Elixir 1.10.4
Erlang 22.3.4.2

Benchmark suite executing with the following configuration:
warmup: 2 s
time: 5 s
memory time: 0 ns
parallel: 1
inputs: first_brcode, fourth brcode, second_brcode, third_brcode
Estimated total run time: 56 s

Benchmarking Current Implementation with input first_brcode...
Benchmarking Current Implementation with input fourth brcode...
Benchmarking Current Implementation with input second_brcode...
Benchmarking Current Implementation with input third_brcode...
Benchmarking Proposed Implementation with Binary Recursion with input first_brcode...
Benchmarking Proposed Implementation with Binary Recursion with input fourth brcode...
Benchmarking Proposed Implementation with Binary Recursion with input second_brcode...
Benchmarking Proposed Implementation with Binary Recursion with input third_brcode...

##### With input first_brcode #####
Name                                                    ips        average  deviation         median         99th %
Proposed Implementation with Binary Recursion      283.89 K        3.52 μs    ±54.05%        3.40 μs        6.93 μs
Current Implementation                              23.18 K       43.14 μs     ±8.72%       42.67 μs       58.42 μs

Comparison:
Proposed Implementation with Binary Recursion      283.89 K
Current Implementation                              23.18 K - 12.25x slower +39.61 μs

##### With input fourth brcode #####
Name                                                    ips        average  deviation         median         99th %
Proposed Implementation with Binary Recursion      282.72 K        3.54 μs    ±45.64%        3.41 μs        6.82 μs
Current Implementation                              23.39 K       42.76 μs    ±10.14%       42.07 μs       59.18 μs

Comparison:
Proposed Implementation with Binary Recursion      282.72 K
Current Implementation                              23.39 K - 12.09x slower +39.22 μs

##### With input second_brcode #####
Name                                                    ips        average  deviation         median         99th %
Proposed Implementation with Binary Recursion      336.58 K        2.97 μs    ±43.22%        2.89 μs        6.03 μs
Current Implementation                              31.89 K       31.36 μs     ±9.18%       31.08 μs       44.07 μs

Comparison:
Proposed Implementation with Binary Recursion      336.58 K
Current Implementation                              31.89 K - 10.56x slower +28.39 μs

##### With input third_brcode #####
Name                                                    ips        average  deviation         median         99th %
Proposed Implementation with Binary Recursion      297.89 K        3.36 μs   ±163.28%        3.24 μs        6.75 μs
Current Implementation                              25.40 K       39.37 μs    ±11.90%       38.73 μs       60.25 μs

Comparison:
Proposed Implementation with Binary Recursion      297.89 K
Current Implementation                              25.40 K - 11.73x slower +36.02 μs
```

The benchmarks were run as follows, using Benchee and with the current implementation copied to the `CurrentDecoder` module:

```elixir
Benchee.run(
  %{
    "Current Implementation" => &ExPixBRCode.CurrentDecoder.decode/1,
    "Proposed Implementation with Binary Recursion" => &ExPixBRCode.Decoder.decode/1
  },
  warmup: 2,
  inputs: %{
    "first_brcode" =>
      "00020101021226850014br.gov.bcb.pix2563exemplodeurl.com.br/pix/v2/11111111-1111-1111-1111-11111111111152040000530398654040.015802BR5925TESTE DE TESTE DO TESTEIE6014RIO DE JANEIRO62070503***6304CD52",
    "second_brcode" =>
      "00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D",
    "third_brcode" =>
      "00020126580014BR.GOV.BCB.PIX013611111111-1111-1111-1111-11111111111152040000530398654040.015802BR5925TESTE DO TESTE DO TESTEIE6009SAO PAULO6226052211111111111111111111116304642D",
    "fourth brcode" =>
      "00020101021226850014br.gov.bcb.pix2563exemplodeurl2.com.br/qr/v2/11111111-1111-1111-1111-11111111111152040000530398654041.005802BR5925TESTE DO TESTE DO TESTEIE6009NOVA LIMA62070503***63040B0F"
  }
)
```
