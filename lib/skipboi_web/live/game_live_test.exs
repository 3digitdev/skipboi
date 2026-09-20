defmodule SkipboiWeb.GameLiveTest do
  use SkipboiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Skipboi.Games

  test "creates a room from the home page", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/")
    view |> element("#create-game") |> render_click()
    {path, _} = assert_redirect(view)
    assert path =~ "/games/"
    Games.finish(String.replace_prefix(path, "/games/", ""))
  end

  test "two browsers share updates, late joins see state, and ending closes both", %{conn: conn} do
    id = Games.create()
    on_exit(fn -> Games.finish(id) end)
    {:ok, first, _} = live(conn, ~p"/games/#{id}")
    {:ok, second, _} = live(build_conn(), ~p"/games/#{id}")
    render_hook(first, "publish", %{revision: 0, json: ~s({"score":7})})
    assert has_element?(second, "#shared-state", "7")
    {:ok, late, _} = live(build_conn(), ~p"/games/#{id}")
    assert has_element?(late, "#shared-state", "7")
    render_hook(second, "publish", %{revision: 0, json: ~s({"score":99})})
    assert {:ok, %{state: %{"score" => 7}}} = Games.get(id)
    first |> element("#end-game") |> render_click()
    assert_redirect(first, "/")
    assert_redirect(second, "/")
    assert_redirect(late, "/")
  end

  test "missing games redirect home", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/games/missing")
  end
end
