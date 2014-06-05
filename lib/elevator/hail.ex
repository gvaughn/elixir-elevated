defmodule Elevator.Hail do
  alias __MODULE__
  defstruct dir: 1, floor: 1, caller: nil

  def create(from_floor, to_floor, caller) do
    %__MODULE__{dir: dir(from_floor, to_floor), floor: to_floor, caller: caller}
  end

  def best_match(calls, %Hail{floor: floor, dir: dir}) do
    #TODO refactor me need to find better match that just first
    List.first(calls) || :none
  end

  def add_call(calls, current_floor, new_floor, caller) do
    new_call = create(current_floor, new_floor, caller)
    #TODO add some sorting before return
    [new_call | calls]
  end

  def dir(floor, floor), do: 0

  def dir(from_floor, to_floor) do
    delta = to_floor - from_floor
    trunc(delta / abs(delta))
  end
end
