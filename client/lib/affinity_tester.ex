defmodule AffinityTester do
  use GenServer
  require Logger

  def start_link([]) do
    {:ok, ip} = System.fetch_env!("TARGET_ADDR") |> String.to_charlist |> :inet.parse_address
    port = System.fetch_env!("TARGET_PORT") |> String.to_integer
    GenServer.start_link(__MODULE__, [ip, port])
  end

  def init([tgt_ip, tgt_port]) do
    {:ok, sock} = :gen_udp.open(0, [mode: :binary, active: true])
    :timer.send_interval(10_000, :ping) # 15s
    id = Enum.random 1_000_000_000..2_147_483_647
    {:ok, %{sock: sock, tgt_ip: tgt_ip, tgt_port: tgt_port, seq: 1, sent: [], id: id, pod_name: nil, x_address: nil}}
  end

  # sends message to server at regular interval
  def handle_info(:ping, state = %{id: id, sock: sock, tgt_ip: ip, tgt_port: port}) do
    :ok = :gen_udp.send(sock, ip, port, request(state))
    sent = push(state.seq, state.sent)
    peek(id, sent)
    {:noreply, %{state | seq: state.seq + 1, sent: sent}}
  end

  # handles the message received from server in response
  def handle_info({:udp, _sock, _ip, _port, payl}, state) do
    case decode(payl) do
      {:ok, msg} -> validate(msg, state)
      _error -> {:noreply, state}
    end
  end

  def changed?(x, y), do: x != nil and x != y

  def decode(<<"maartensmagic", binterm :: binary>>) do
    {:ok, :erlang.binary_to_term(binterm)}
  end
  def decode(_) do
    {:error, :magic_is_gone}
  end

  def request(%{id: id, seq: seq}) do
    "maartensmagic" <> :erlang.term_to_binary(%{id: id, seq: seq})
  end

  def validate(%{seq: seq, x_address: x_address, pod_name: pod_name}, state) do
    if state.x_address == nil do
      Logger.info "CLIENT-#{state.id} established connection: reflective address is #{inspect x_address}"
    end
    if changed?(state.pod_name, pod_name), do: 
      Logger.error "pod_name changed #{inspect state.pod_name} -> #{inspect pod_name}" 
    if changed?(state.x_address, x_address), do: 
      Logger.error "x_address changed #{inspect state.x_address} -> #{inspect x_address}" 
    {:noreply, %{state | x_address: x_address, pod_name: pod_name, sent: pop(seq, state.sent)}}
  end

  def push(x, xs) do
    [x | xs]
  end

  # pops all values <= x
  def pop(x, [y|ys]) when x >= y do
    pop(x, ys)
  end
  def pop(_y, xs) do
    xs
  end

  def peek(id, xs) do
    if length(xs) > 2 do
      Logger.error "CLIENT-#{id} detected gap #{inspect xs}"
    end
  end

end
