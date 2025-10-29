// Define a heating system that adjusts the temperature when there is a trigger.
package 'Heating System' {
	private import ISQ::*;

	item def TriggerSignal;

	action def AdjustTemperature;

	part def HeatingSystem {
		attribute currentTemperature : ISQ::TemperatureValue;

		state heatingControl {
			entry; then idle;

			state idle;
			accept TriggerSignal then adjusting;

			state adjusting {
				entry action AdjustTemperature;
				then idle;
			}
		}
	}
}
