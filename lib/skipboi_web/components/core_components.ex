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
  attr :text, :string, default: ""
  slot :inner_block, required: false

  def button(assigns) do
    ~H"""
    <div class="w-fit perspective-500 translate-y-[2px]">
      <div class="bg-gray-800 border-x-3 border-t-0 border-b-3 border-gray-800 rounded-sm rotate-x-[30deg] origin-top">
        <button
          type={@type}
          class={[
            @class,
            "h-8 rounded-sm [box-shadow:inset_0_2px_0_rgba(255,255,255,0.35),inset_0_-2px_0_rgba(0,0,0,0.15),0_4px_0_rgba(151,60,0)] border-none bg-amber-500 -translate-y-1 active:-translate-y-0 active:[box-shadow:inset_0_2px_0_rgba(255,255,255,0.35),inset_0_-2px_0_rgba(0,0,0,0.15)]"
          ]}
          {@rest}
        >
          <div class="flex gap-2 items-center text-amber-900">
            <span class="text-lg [text-shadow:0_-1px_0_rgba(0,0,0,0.3),0_1px_0_rgba(255,255,255,0.2)]">{@text}</span>
            {render_slot(@inner_block)}
          </div>
        </button>
      </div>
    </div>
    """
  end

  attr :text, :string, default: ""
  attr :outer_class, :string, default: ""
  attr :text_class, :string, default: ""
  attr :disabled, :boolean, default: false
  attr :side, :string, default: "bottom", values: ~w(top left bottom right)
  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <div class={[
      "flex flex-col gap-1 items-center",
      @side in ["left", "right"] && "flex-row gap-0",
      @outer_class
    ]}>
      <span
        :if={@side in ["top", "left"]}
        class={[
          "text-xs",
          @side in ["left", "right"] && "[writing-mode:vertical-lr] rotate-180",
          @text_class
        ]}
      >{@text}</span>
      <div class={[
        "flex gap-1 outline outline-dashed p-2 rounded-md",
        @disabled && "pointer-events-none"
      ]}>
        {render_slot(@inner_block)}
      </div>
      <span
        :if={@side in ["bottom", "right"]}
        class={[
          "text-xs",
          @side in ["left", "right"] && "[writing-mode:vertical-lr] rotate-180",
          @text_class
        ]}
      >{@text}</span>
    </div>
    """
  end
end
