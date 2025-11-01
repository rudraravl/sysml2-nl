// Specify a water pump system that activates below 30% and deactivates at 90% tank level.
package 'Water Pump System' {
	private import ScalarValues::*;
	private import SI_Units::*;

	value def Percentage specializes Real {
		unit percent;
	}

	item def Water;

	port def WaterIn {
		in item waterFlow : Water;
	}

	port def WaterOut {
		out item waterFlow : Water;
	}

	part def LevelSensor {
		out level : Percentage;
	}

	part def Pump {
		in isOn : Boolean;
		port waterOutlet : WaterOut;
	}

	part def WaterTank {
		attribute level : Percentage;
		part sensor : LevelSensor;
		port waterInlet : WaterIn;
		
		bind sensor.level = self.level;
	}

	part def Controller {
		in currentLevel : Percentage;
		out pumpCommand : Boolean;

		statemachine PumpControlLogic {
			initial state Idle {
				entry pumpCommand = false;
			}
			
			state Pumping {
				entry pumpCommand = true;
			}

			transition from Idle to Pumping
				when currentLevel < 30;

			transition from Pumping to Idle
				when currentLevel >= 90;
		}
	}

	part def WaterPumpSystem {
		part tank : WaterTank;
		part pump : Pump;
		part controller : Controller;

		connect tank.sensor.level to controller.currentLevel;
		connect controller.pumpCommand to pump.isOn;
		connect pump.waterOutlet to tank.waterInlet;
	}

	requirement def PumpActivationThreshold {
		doc /* The pump shall activate when the water tank level is below 30%. */
		subject controller : Controller;
		constraint { controller.currentLevel < 30 implies controller.pumpCommand }
	}

	requirement def PumpDeactivationThreshold {
		doc /* The pump shall deactivate when the water tank level reaches 90% or more. */
		subject controller : Controller;
		constraint { controller.currentLevel >= 90 implies not controller.pumpCommand }
	}

	requirement activationReq : PumpActivationThreshold;
	
	requirement deactivationReq : PumpDeactivationThreshold;

	satisfy requirement activationReq by Controller::PumpControlLogic;
	satisfy requirement deactivationReq by Controller::PumpControlLogic;
}
