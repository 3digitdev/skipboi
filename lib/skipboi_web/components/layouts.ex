defmodule SkipboiWeb.Layouts do
  use SkipboiWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    {render_slot(@inner_block)}
    <div class="pointer-events-none fixed inset-x-4 bottom-4 z-50 flex flex-col items-end gap-3">
      <div
        :for={kind <- [:info, :error]}
        :if={Phoenix.Flash.get(@flash, kind)}
        id={"toast-#{kind}"}
        phx-hook="FlashToast"
        data-kind={kind}
        data-message={Phoenix.Flash.get(@flash, kind)}
        data-timeout={if kind == :error, do: 10000, else: 6000}
        role={if kind == :error, do: "alert", else: "status"}
        aria-atomic="true"
        class={[
          "pointer-events-auto box-border flex w-full max-w-sm items-center gap-3 rounded-lg border border-solid bg-white p-4 text-slate-900 shadow-lg",
          if(kind == :error, do: "border-red-300", else: "border-green-300")
        ]}
      >
        <Heroicons.exclamation_circle
          :if={kind == :error}
          class="size-5 shrink-0 text-red-600"
          aria-hidden="true"
        />
        <Heroicons.check_circle
          :if={kind == :info}
          class="size-5 shrink-0 text-green-600"
          aria-hidden="true"
        />
        <p class="m-0 min-w-0 flex-1 text-sm leading-6 wrap-anywhere">
          {Phoenix.Flash.get(@flash, kind)}
        </p>
        <button
          type="button"
          phx-click="lv:clear-flash"
          phx-value-key={kind}
          aria-label="Dismiss message"
          class="flex size-8 shrink-0 cursor-pointer items-center justify-center rounded border-0 bg-transparent p-0 text-red-500 hover:bg-slate-100 focus-visible:outline-2 focus-visible:outline-blue-600"
        >
          <Heroicons.x_mark aria-hidden="true" class="size-5" />
        </button>
      </div>
    </div>
    <p
      id="connection-status"
      role="status"
      hidden
      phx-disconnected={JS.remove_attribute("hidden", to: "#connection-status")}
      phx-connected={JS.set_attribute({"hidden", ""}, to: "#connection-status")}
    >
      Connection lost. Attempting to reconnect… wait before sending a move.
    </p>
    """
  end
end
