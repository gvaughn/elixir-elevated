use Mix.Config

config :elevator,
  banks: [
    [ name: "A",
      event_name: {:global, :elevator_events},
      display: :visual,
      tick: 1000,
      num_cars: 1
    ]
  ]

