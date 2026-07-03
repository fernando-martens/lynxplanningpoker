// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `pnpm add some-package` (from a directory with a
// package.json) and import them using a path starting with the package name:
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/lynxplanningpoker"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Copy-to-clipboard: triggered via `JS.dispatch("phx:copy", to: "#some-input")`.
// Reads the dispatched element's value/textContent and writes it to the clipboard.
// If the source element has `data-copy-feedback="some-id"`, shows that element
// for 2s as visual confirmation.
window.addEventListener("phx:copy", (event) => {
  const target = event.target
  if (!target) return
  const text = target.value ?? target.textContent ?? ""
  if (!text) return
  navigator.clipboard.writeText(text).then(() => {
    const feedbackId = target.dataset.copyFeedback
    if (!feedbackId) return
    const feedback = document.getElementById(feedbackId)
    if (!feedback) return
    feedback.style.display = "inline-flex"
    clearTimeout(feedback._copyTimer)
    feedback._copyTimer = setTimeout(() => {
      feedback.style.display = "none"
    }, 2000)
  })
})

// Inputs flagged with `data-select-on-click` (e.g. the invite-URL field in
// the room) select their text on click for easier copy. Delegated listener
// instead of inline `onclick=` so the CSP can drop `'unsafe-inline'`.
window.addEventListener("click", (e) => {
  const el = e.target.closest("[data-select-on-click]")
  if (el && typeof el.select === "function") el.select()
})

// Focus an input and select its text: `JS.dispatch("phx:select", to: "#input")`.
// Used when the "Tell us your name" modal opens so the temporary name is
// pre-selected and a single keystroke replaces it.
window.addEventListener("phx:select", (event) => {
  const el = event.target
  if (!el || typeof el.focus !== "function") return
  // Defer to the next frame: the modal's `display` was just flipped in the
  // same JS chain, so the input isn't focusable until layout settles.
  requestAnimationFrame(() => {
    el.focus()
    if (typeof el.select === "function") el.select()
  })
})

// Tree easter egg: clicking a forest tree makes it sway for half a second.
// Pure client-side — no roundtrip to the server.
window.addEventListener("click", (e) => {
  const tree = e.target.closest(".room-forest-tree")
  if (!tree || tree.classList.contains("is-shaking")) return

  tree.classList.add("is-shaking")
  setTimeout(() => tree.classList.remove("is-shaking"), 600)
})

// Cloudflare Turnstile (room-creation form): the submit button is rendered
// disabled by the server and only enabled once a verified token exists.
//
// Race-condition-safe: `api.js` (loaded `async defer` inline in the form) can
// resolve before this `defer` script runs, so we CANNOT rely on the
// `data-callback` being defined in time — Turnstile would call
// `window.lynxTurnstileEnable` while it's still `undefined` and the captcha
// would show checked with the button stuck disabled.
//
// The single source of truth is the token in `input[name="cf-turnstile-response"]`
// (the exact field the server verifies in `room_controller.ex`). We mirror its
// presence to the button's `disabled` state via a short poll (covers the race
// when the token settles before this script runs) and a `MutationObserver`
// (covers the interactive case where the user completes the challenge much
// later). The three `data-callback` hooks (`data-callback`,
// `data-error-callback`, `data-expired-callback`) are kept as instant
// defense-in-depth, but the token — not the callbacks — drives the state.
//
// Fallback: if the Turnstile widget never renders within 8s (blocked, offline),
// we assume Turnstile is unavailable and enable the button anyway — the server
// still calls `Turnstile.verify/2` and returns the "please complete the human
// verification" flash if the token is missing, so we never silently accept an
// unverified submission.
const TURNSTILE_FALLBACK_MS = 8000

const turnstileForm = () => document.querySelector(".cf-turnstile")
  && document.querySelector("#create-room-form")

const turnstileTokenInput = () => {
  const form = turnstileForm()
  return form && form.querySelector('input[name="cf-turnstile-response"]')
}

const turnstileSubmitButton = () => {
  const form = turnstileForm()
  return form && form.querySelector("button[type=submit]")
}

const turnstileWidgetRendered = () => {
  const widget = document.querySelector(".cf-turnstile")
  return !!widget && widget.children.length > 0
}

const syncTurnstileButton = () => {
  const btn = turnstileSubmitButton()
  if (!btn) return
  const input = turnstileTokenInput()
  const token = input && input.value
  btn.disabled = !token
}

window.lynxTurnstileEnable = () => syncTurnstileButton()
window.lynxTurnstileDisable = () => syncTurnstileButton()

// Only wire this up on the create-room form — elsewhere there's no widget and
// the button is server-rendered enabled, so we must not touch it.
if (turnstileForm()) {
  syncTurnstileButton()

  // 1) Short poll (150ms, up to 8s): covers the case where the token settled
  //    before this script ran (the race) and the token input didn't fire a
  //    mutation our observer catches. Cheap and bounded.
  let polling = true
  const stopPolling = () => { polling = false }
  const startedAt = Date.now()
  const poll = () => {
    if (!polling) return
    syncTurnstileButton()
    const input = turnstileTokenInput()
    const settled = input && input.value
    const elapsed = Date.now() - startedAt
    if (settled) { stopPolling(); return }
    if (elapsed < TURNSTILE_FALLBACK_MS) {
      setTimeout(poll, 150)
    } else {
      // 2) Fallback: 8s elapsed with no token. If the widget rendered, the
      //    user is interacting (interactive Turnstile) — keep waiting via the
      //    MutationObserver below; never force-enable a half-solved
      //    challenge. Only force-enable if the widget never loaded at all.
      if (!turnstileWidgetRendered()) {
        const btn = turnstileSubmitButton()
        if (btn) btn.disabled = false
      }
      stopPolling()
    }
  }
  setTimeout(poll, 150)

  // 3) MutationObserver on the token input: covers the interactive case
  //    where the user completes the challenge well after the 8s poll ended.
  //    Attributes mutations (value set via property/attribute by Turnstile)
  //    are observed. Stops observing once a token is present.
  const input = turnstileTokenInput()
  if (input && "MutationObserver" in window) {
    const observer = new MutationObserver(() => {
      syncTurnstileButton()
      if (input.value) observer.disconnect()
    })
    observer.observe(input, { attributes: true, attributeFilter: ["value"] })
    // Some Turnstile builds set `.value` as a property without dispatching an
    // attribute mutation; also watch the widget subtree for the token input
    // being added/changed, plus a low-frequency safety poll (1s, capped to
    // ~120s) so an interactive challenge that takes longer than the initial
    // 8s poll still flips the button the moment the token shows up.
    const widget = document.querySelector(".cf-turnstile")
    if (widget) {
      observer.observe(widget, { childList: true, subtree: true })
    }
    let safetyTicks = 0
    const safetyPoll = () => {
      syncTurnstileButton()
      if (input.value) return
      if (++safetyTicks < 120) setTimeout(safetyPoll, 1000)
    }
    setTimeout(safetyPoll, 1000)
  }
}

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

