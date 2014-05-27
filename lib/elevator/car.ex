#TODO: 'arrival' needs to inform the pids of the Calls and HallSignal

defmodule Elevator.Car do
  use GenServer

  @timeout 1000
  @initial_state [floor: 0, dir: 0, calls: [], num: 0]
  # dir(-1, 0, 1)

  def start_link(num) do
    state = Dict.put(@initial_state, :num, num)
    GenServer.start_link(__MODULE__, state, [])
  end

  def init(state) do
    {:ok, state, @timeout}
  end

  def go_to(pid, floor, caller) do
    GenServer.cast(pid, {:destination, floor, caller})
  end

  # OPT handlers
  def handle_cast({:destination, dest, caller}, state) do
    IO.puts "let's go to #{dest}"
    state = add_call(state, dest, caller)

    {:noreply, state, @timeout}
  end

  # This is our heartbeat function to either handle arrival at a floor or travel to the next
  def handle_info(:timeout, state) do
    state = case state[:dir] do
      0 -> arrival(state[:calls], state)
      _ -> travel(state)
    end
    {:noreply, state, @timeout}
    #TODO we might want the timeout for cast and calls so that it mimics the doors waiting
    # to close after floor selection
  end

  defp arrival(calls, state) when length(calls) == 0 do
    case message_hall_signal(:destination, [state[:floor], state[:dir]]) do
      {:ok, dest} -> dispatch(dest, state)
      {:none}     -> state #nowhere to go
    end
  end

  defp arrival(calls, state) do
    {curr_calls, other_calls} = Enum.split_while(state[:calls], &(&1.floor == state[:floor]))
    arrival_notice(curr_calls, state)
    message_hall_signal(:arrival, [state[:floor], state[:dir]])
    #TODO find a next_destination from calls if possible
    Dict.merge(state, [calls: other_calls])
  end

  defp travel(state) do
    new_floor = state[:floor] + state[:dir]
    new_dir = if should_stop?(new_floor, state) do
      #TODO too simple, we need to keep moving if we have more calls in that dir
      0
    else
      IO.puts "passing #{new_floor}"
      state[:dir]
    end
    Dict.merge(state, [floor: new_floor, dir: new_dir])
  end

  defp should_stop?(floor, state) do
    hd(state[:calls]).floor == floor
    # TODO also should message HallMonitor to see if we can catch a rider in passing
  end

  defp dispatch(call, state) do
    Dict.merge(state, [dir: update_dir(call.floor - state[:floor]), calls: update_dest(state[:calls], call, state[:dir])])
  end

  defp update_dir(delta) do
    cond do
      delta == 0 -> 0
      delta > 0  -> 1
      true       -> -1
    end
  end

  defp update_dest(dests, item, dir) do
    #sorts by dir 1st and floor 2nd because of order of field of Elevator.Call
    #TODO but needs to be reversed order of floor?
    new_list = [item | dests] |> Enum.sort
    if dir > 0, do: new_list |> Enum.reverse,
    else: new_list
  end

  defp arrival_notice(arrivals, state) do
    Enum.each(arrivals, &(send(&1.caller, {:arrival, state[:floor], self})))
  end

  defp add_call(state, new_dest, caller) do
    delta = (new_dest - state[:floor])
    dir = trunc(delta/delta)
    new_call = %Elevator.Call{dir: dir, floor: new_dest, caller: caller}
    Dict.merge(state, [dir: dir, calls: [new_call | state[:calls]]])
  end

  defp message_hall_signal(message, params) do
    GenServer.call(:hall_signal, {message, params})
  end
end
