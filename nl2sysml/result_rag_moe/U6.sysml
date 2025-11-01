// Specify a water pump system that activates below 30% and deactivates at 90% tank level.
package 'Water Pump System' {
	private import ScalarValues::*;

	value def Percentage :> Real;
	item def Water;

	port def WaterInPort {
		in item water : Water;
	}

	port def WaterOutPort {
		out item water : Water;
	}

	part def WaterTank {
		attribute level : Percentage;
		port waterIn : WaterInPort;
	}

	part def Pump {
		attribute isActive : Boolean = false;
		port waterOut : WaterOutPort;
	}

	part def LevelSensor {
		out signal levelReading : Percentage;
	}

	part def Controller {
		in signal currentLevel : Percentage;
		out signal pumpCommand : Boolean;

		state machine controlLogic {
			initial state Idle;

			state Idle {
				entry assign pumpCommand = false;
			}

			state Pumping {
				entry assign pumpCommand = true;
			}

			transition from Idle to Pumping
				when currentLevel < 30.0;

			transition from Pumping to Idle
				when currentLevel >= 90.0;
		}
	}

	requirement def PumpActivation {
		doc "The pump shall activate when the tank level falls below 30%.";
	}

	requirement def PumpDeactivation {
		doc "The pump shall deactivate when the tank level is at or above 90%.";
	}

	part def WaterPumpSystem {
		part tank : WaterTank;
		part pump : Pump;
		part sensor : LevelSensor;
		part controller : Controller;

		bind sensor.levelReading = tank.level;
		bind pump.isActive = controller.pumpCommand;

		connect sensor.levelReading to controller.currentLevel;
		connect pump.waterOut to tank.waterIn;

		requirement activationReq : PumpActivation {
			subject pump;
		}
		requirement deactivationReq : PumpDeactivation {
			subject pump;
		}

		satisfy activationReq by controller.controlLogic;
		satisfy deactivationReq by controller.controlLogic;
	}

	part system : WaterPumpSystem;
}
