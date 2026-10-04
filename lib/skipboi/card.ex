defmodule Skipboi.Card do
  @enforce_keys [:value, :type]
  defstruct [:value, :type]

  @type t :: %__MODULE__{
          value: pos_integer() | nil,
          type: :number | :skipbo
        }
end
