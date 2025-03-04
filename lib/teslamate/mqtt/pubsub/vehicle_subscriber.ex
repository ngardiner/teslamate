defmodule TeslaMate.Mqtt.PubSub.VehicleSubscriber do
  use GenServer

  require Logger
  import Core.Dependency, only: [call: 3]

  alias TeslaMate.Mqtt.Publisher
  alias TeslaMate.Vehicles

  defstruct [:car_id, :last_summary, :deps]
  alias __MODULE__, as: State

  def child_spec(arg) do
    %{
      id: :"#{__MODULE__}#{Keyword.fetch!(arg, :car_id)}",
      start: {__MODULE__, :start_link, [arg]}
    }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    car_id = Keyword.fetch!(opts, :car_id)

    deps = %{
      vehicles: Keyword.get(opts, :deps_vehicles, Vehicles),
      publisher: Keyword.get(opts, :deps_publisher, Publisher)
    }

    :ok = call(deps.vehicles, :subscribe, [car_id])

    {:ok, %State{car_id: car_id, deps: deps}}
  end

  @impl true
  def handle_info(summary, %State{last_summary: summary} = state) do
    {:noreply, state}
  end

  @blacklist [:car]
  @always_published ~w(charge_energy_added charger_actual_current charger_phases
                       charger_power charger_voltage scheduled_charging_start_time
                       time_to_full_charge)a

  def handle_info(summary, state) do
    summary
    |> Map.from_struct()
    |> Stream.filter(fn {key, value} ->
      not (key in @blacklist) and (not is_nil(value) or key in @always_published)
    end)
    |> Task.async_stream(&publish(&1, state),
      max_concurrency: 10,
      on_timeout: :kill_task,
      ordered: false
    )
    |> Enum.each(fn
      {_, reason} when reason != :ok -> Logger.warn("MQTT publishing failed: #{inspect(reason)}")
      _ok -> nil
    end)

    {:noreply, %State{state | last_summary: summary}}
  end

  defp publish({key, value}, %State{car_id: car_id, deps: deps}) do
    call(deps.publisher, :publish, [
      "teslamate/cars/#{car_id}/#{key}",
      to_str(value),
      [retain: true, qos: 1]
    ])
  end

  defp to_str(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp to_str(value), do: to_string(value)
end
