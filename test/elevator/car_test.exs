defmodule Elevatar.CarTest do
  use ExUnit.Case, async: true
  alias Elevator.Car

  @hall_signal :hall_signal_test
  @venue :elevator_events

  setup do
    {:ok, _hall} = Elevator.HallSignal.start_link(@venue, name: @hall_signal)
    {:ok, car} = Elevator.Car.start_link({@venue, @hall_signal, :infinity})
    {:ok, car: car}
  end

  test "hall hail 4 -> 2", %{car: car} do
    Elevator.HallSignal.floor_call(@hall_signal, 4, -1, self)
    assert_arrival(car, 4)
    Car.go_to(car, 2, self)
    assert_arrival(car, 2)
  end

  test "2 hall hails 1 -> 3, 4 -> 2", %{car: car} do
    Elevator.HallSignal.floor_call(@hall_signal, 1, 1, self) #rider 1 hail
    tick(car)
    Elevator.HallSignal.floor_call(@hall_signal, 4, -1, self) # rider 2 hail
    assert_receive {:arrival, 1, ^car} # rider 1 boards
    Car.go_to(car, 3, self) # rider 1 goes to 3
    assert_arrival(car, 3) # rider 1 exits
    assert_arrival(car, 4) # rider 2 boards
    Car.go_to(car, 2, self) # rider 2 goes to 2
    assert_arrival(car, 2) # rider 2 exits
  end

  test "hall signal removes hail when car already parked there", %{car: car} do
    Elevator.HallSignal.floor_call(@hall_signal, 1, 1, self)
    assert_arrival(car, 1)
    assert [] == :sys.get_state(@hall_signal)[:hails]
  end

  defp assert_arrival(car, floor) do
    continue(car)
    assert_receive {:arrival, ^floor, ^car}
  end

  defp continue(car) do
    tick(car)
    case Process.info(self, :message_queue_len) do
      {:message_queue_len, 0} -> continue(car)
      {:message_queue_len, _} -> nil
    end
  end

  defp tick(car), do: send(car, :timeout)
end
