# Loadex

A simple distributed load test runner.

`Loadex` was created with two things in mind - genarating huge loads in a controlled manner, while being able to fully customize the test's flow.
These goals are achieved by using plain Elixir to create *scenarios* and then laveraging Elixir's massive concurrency capabilities to run them on one or multiple machines.

~~Docs can be found at [https://hexdocs.pm/loadex](https://hexdocs.pm/loadex).~~ (not yet, but soon!)

## Installation

Add `loadex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:loadex, "~> 0.0.1"}
  ]
end
```
  
### Example:
  
```elixir
defmodule ExampleScenario do
  use Loadex.Scenario

  setup do
    1..100
  end

  scenario index do
    loop_after 500, 10, iteration do
      IO.puts("My number is \#{index}, iteration \#{iteration}!")
    end
  end

  teardown index do
    IO.puts("Bye from \#{index}!")
  end
end
  ```

Then:

```bash
iex> Loadex.run(scenario: "./scenarios/example_scenario.exs", rate: 30, restart: true)
```

More information can be found in [the docs](https://hexdocs.pm/loadex)
