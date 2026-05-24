defmodule Lynxplanningpoker.Decks do
  @moduledoc """
  Definições dos decks de cartas suportados.

  Cada deck é uma lista de tuplas `{label, numeric_value}` onde:
  - `label` é a string mostrada/armazenada (campo `users.vote`)
  - `numeric_value` é o valor usado em médias (campo `users.vote_value`), ou
    `nil` para cartas não-numéricas como `"?"` ou `"☕"`.
  """

  @fibonacci [
    {"0", 0},
    {"1", 1},
    {"2", 2},
    {"3", 3},
    {"5", 5},
    {"8", 8},
    {"13", 13},
    {"21", 21},
    {"34", 34},
    {"55", 55},
    {"89", 89},
    {"?", nil}
  ]

  @doc "Deck usado por padrão pelas salas."
  def default, do: fibonacci()

  def fibonacci, do: @fibonacci

  @doc "Lista de labels (strings) do deck, na ordem de exibição."
  def labels(deck \\ default()), do: Enum.map(deck, &elem(&1, 0))

  @doc """
  Resolve o valor numérico de uma label.

  Retorna `nil` para labels não-numéricas (`"?"`, `"☕"`, etc.) ou desconhecidas.
  """
  def numeric_value(deck \\ default(), label)
  def numeric_value(_deck, nil), do: nil

  def numeric_value(deck, label) when is_binary(label) do
    case List.keyfind(deck, label, 0) do
      {^label, value} -> value
      nil -> nil
    end
  end
end
