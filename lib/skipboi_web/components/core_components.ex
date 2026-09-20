defmodule SkipboiWeb.CoreComponents do
  @moduledoc "Unstyled wrappers for text inputs and buttons."
  use Phoenix.Component

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :value, :any, default: ""
  attr :class, :string, default: ""
  attr :type, :string, default: "text", values: ~w(text textarea)

  attr :rest, :global,
    include: ~w(readonly disabled placeholder required rows cols maxlength autocomplete width)

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <textarea
      id={@id}
      name={@name}
      class={[@class, ""]}
      {@rest}
    >
      {@value}
    </textarea>
    """
  end

  def input(assigns) do
    ~H"""
    <input
      type="text"
      id={@id}
      name={@name}
      value={@value}
      class={[
        @class,
        "px-2 py-1.5 border-t border-l border-r-[0.5px] border-b-[0.5px] border-black inset-shadow-[1px_1px_0_rgba(0,0,0)]"
      ]}
      {@rest}
    />
    """
  end

  attr :type, :string, default: "button", values: ~w(button submit reset)
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(disabled name value form)
  slot :inner_block, required: true

  def skeubutton(assigns) do
    ~H"""
    <div class="rounded-full flex w-fit items-center p-[0.5px] bg-linear-to-b from-gray-50 via-60% via-gray-200 to-95% to-gray-200">
      <button
        type={@type}
        class={[
          @class,
          "px-2 py-1.5 bg-gray-50 flex gap-1 items-center rounded-full border-none shadow-[inset_0_1px_rgba(255,255,255,0.7),inset_0_0px_1px_rgba(200,200,200,0.7)]"
        ]}
        {@rest}
      >
        {render_slot(@inner_block)}
      </button>
    </div>
    """
  end

  attr :type, :string, default: "button", values: ~w(button submit reset)
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(disabled name value form)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        @class,
        "px-2 py-1.5 bg-white border shadow-[4px_4px_0_rgba(0,0,0)] active:shadow-none active:translate-1 flex gap-1 items-center"
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :type, :atom, default: :number
  attr :value, :any, default: nil
  attr :class, :string, default: ""

  def card(assigns) do
    assigns =
      assign(
        assigns,
        :color_class,
        case assigns.value do
          v when v < 5 -> :blue
          v when v < 9 -> :green
          v when v < 13 -> :red
          _ -> :yellow
        end
        |> color_class()
      )

    ~H"""
    <div class={[
      @class,
      @color_class,
      "w-12 h-16 rounded-md active:shadow-none flex items-center justify-center"
    ]}>
      <span class="text-2xl font-bold">{if @type == :skipbo, do: "S", else: @value}</span>
    </div>
    """
  end

  defp color_class(:blue), do: "text-blue-500 bg-blue-200/30"
  defp color_class(:green), do: "text-green-500 bg-green-200/30"
  defp color_class(:red), do: "text-red-500 bg-red-200/30"
  defp color_class(:yellow), do: "text-yellow-500 bg-yellow-200/30"

  attr :class, :string, default: ""
  slot :inner_block, required: false

  def card_slot(assigns) do
    ~H"""
    <div class={[
      @class,
      "w-12 h-16 rounded-md outline-2 outline-offset-0 flex items-center justify-center"
    ]}>
      <span>{render_slot(@inner_block)}</span>
    </div>
    """
  end
end
