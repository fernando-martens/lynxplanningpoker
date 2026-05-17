defmodule Lynxplanningpoker.Presence do
  use Phoenix.Presence,
    otp_app: :lynxplanningpoker,
    pubsub_server: Lynxplanningpoker.PubSub

  @doc """
  Returns the PubSub topic where this room's presence is tracked. Subscribe to
  it to receive `%Phoenix.Socket.Broadcast{event: "presence_diff", ...}`.
  """
  def room_topic(room_id), do: "room_presence:#{room_id}"
end
