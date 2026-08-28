package 'Boiler Feedwater Pumping Subsystem' {
	private import ScalarValues::*;

	attribute def Pressure :> Real;
	unit def kPa;

	attribute def FlowRate :> Real;
	unit def kg_per_s;

	attribute def Power :> Real;
	unit def kW;

	attribute def Speed :> Real;
	unit def rpm;

	attribute def Torque :> Real;
	unit def Nm;

	item def Feedwater;
	item def ElectricPower;

	port def FeedwaterInPort {
		in item feedwater : Feedwater;
		attribute pressure : Pressure;
		attribute flowRate : FlowRate;
	}

	port def FeedwaterOutPort {
		out item feedwater : Feedwater;
		attribute pressure : Pressure;
		attribute flowRate : FlowRate;
	}

	port def PressureTapPort {
		out attribute pressure : Pressure;
	}

	port def PressureSinkPort {
		in attribute pressure : Pressure;
	}

	port def FlowTapPort {
		out attribute flowRate : FlowRate;
	}

	port def FlowSinkPort {
		in attribute flowRate : FlowRate;
	}

	port def SpeedTapPort {
		out attribute speed : Speed;
	}

	port def SpeedSinkPort {
		in attribute speed : Speed;
	}

	port def PumpCommandPort {
		in attribute start : Boolean;
		in attribute stop : Boolean;
		in attribute reset : Boolean;
	}

	port def PumpStatusPort {
		out attribute running : Boolean;
		out attribute tripped : Boolean;
	}

	port def ElectricalPowerPort {
		in item electricPower : ElectricPower;
	}

	port def ShaftPort {
		attribute torque : Torque;
		attribute speed : Speed;
	}

	action def RampUpSpeed;
	action def RampDownSpeed;
	action def StartMotor;
	action def StopMotor;
	action def CloseDischargeValve;
	action def OpenDischargeValve;
	action def MaintainPressure;
	action def TriggerAlarm;

	action def StartPumpSequence {
		action closeDischargeValve : CloseDischargeValve;
		action startMotor : StartMotor;
		action rampSpeedUp : RampUpSpeed;
		action openDischargeValve : OpenDischargeValve;
	}

	action def StopPumpSequence {
		action closeDischargeValve : CloseDischargeValve;
		action rampSpeedDown : RampDownSpeed;
		action stopMotor : StopMotor;
	}

	action def DeliverFeedwaterToBoiler;

	state def PumpControlStateMachine {
		attribute startCommand : Boolean;
		attribute stopCommand : Boolean;
		attribute resetCommand : Boolean;
		attribute faultDetected : Boolean;
		attribute currentSpeed : Speed;
		attribute targetSpeed : Speed;

		state stopped;
		state starting {
			entry do StartPumpSequence;
		}
		state running {
			entry do MaintainPressure;
		}
		state tripped {
			entry do TriggerAlarm;
		}

		transition first stopped then starting;
		transition first starting then running;
		transition first starting then tripped;
		transition first running then stopped;
		transition first running then tripped;
		transition first tripped then stopped;
	}

	part def Motor {
		port powerPort : ElectricalPowerPort;
		port shaft : ShaftPort;
		port speedOutput : SpeedTapPort;
		attribute ratedPower : Power;
		attribute currentSpeed : Speed;
	}

	part def Impeller {
		port shaft : ShaftPort;
		port suction : FeedwaterInPort;
		port discharge : FeedwaterOutPort;
	}

	part def Casing {
		port suction : FeedwaterInPort;
		port discharge : FeedwaterOutPort;
	}

	part def MechanicalSeal {
		port shaft : ShaftPort;
	}

	part def BoilerFeedwaterPump {
		port suction : FeedwaterInPort;
		port discharge : FeedwaterOutPort;
		port pressureTap : PressureTapPort;
		port flowTap : FlowTapPort;

		part motor : Motor;
		part impeller : Impeller;
		part casing : Casing;
		part mechanicalSeal : MechanicalSeal;

		connect suction to casing.suction;
		connect casing.suction to impeller.suction;
		connect impeller.discharge to casing.discharge;
		connect casing.discharge to discharge;
		connect motor.shaft to impeller.shaft;
		connect mechanicalSeal.shaft to motor.shaft;
	}

	part def SuctionStrainer {
		port inlet : FeedwaterInPort;
		port outlet : FeedwaterOutPort;
	}

	part def DeaeratorTank {
		port outletA : FeedwaterOutPort;
		port outletB : FeedwaterOutPort;
	}

	part def CheckValve {
		port inlet : FeedwaterInPort;
		port outlet : FeedwaterOutPort;
	}

	part def ControlValve {
		port inlet : FeedwaterInPort;
		port outlet : FeedwaterOutPort;
		attribute valvePosition : Real;
	}

	part def PressureTransmitter {
		port sensing : PressureSinkPort;
		port signal : PressureTapPort;
	}

	part def FlowTransmitter {
		port sensing : FlowSinkPort;
		port signal : FlowTapPort;
	}

	part def PumpController {
		port command : PumpCommandPort;
		port pressureFeedback : PressureSinkPort;
		port flowFeedback : FlowSinkPort;
		port speedFeedback : SpeedSinkPort;
		port status : PumpStatusPort;

		attribute faultDetected : Boolean = false;
		attribute targetSpeed : Speed = 3000;

		exhibit pumpControlStates : PumpControlStateMachine {
			in startCommand = command.start;
			in stopCommand = command.stop;
			in resetCommand = command.reset;
			in faultDetected = faultDetected;
			in currentSpeed = speedFeedback.speed;
			in targetSpeed = targetSpeed;
		}
	}

	part def PumpLine {
		port suction : FeedwaterInPort;
		port discharge : FeedwaterOutPort;

		part strainer : SuctionStrainer;
		part pump : BoilerFeedwaterPump;
		part checkValve : CheckValve;
		part pressureTransmitter : PressureTransmitter;
		part flowTransmitter : FlowTransmitter;
		part controller : PumpController;

		connect suction to strainer.inlet;
		connect strainer.outlet to pump.suction;
		connect pump.discharge to checkValve.inlet;
		connect checkValve.outlet to discharge;
		connect pump.pressureTap to pressureTransmitter.sensing;
		connect pump.flowTap to flowTransmitter.sensing;
		connect pressureTransmitter.signal to controller.pressureFeedback;
		connect flowTransmitter.signal to controller.flowFeedback;
		connect pump.motor.speedOutput to controller.speedFeedback;
	}

	part def Boiler {
		port feedwaterInlet : FeedwaterInPort;
	}

	part def BoilerFeedwaterPumpingSubsystem {
		part deaeratorTank : DeaeratorTank;
		part pumpLineA : PumpLine;
		part pumpLineB : PumpLine;
		part feedwaterControlValve : ControlValve;
		part boiler : Boiler;

		perform action deliverFeedwaterToBoiler : DeliverFeedwaterToBoiler;

		connect deaeratorTank.outletA to pumpLineA.suction;
		connect deaeratorTank.outletB to pumpLineB.suction;
		connect pumpLineA.discharge to feedwaterControlValve.inlet;
		connect pumpLineB.discharge to feedwaterControlValve.inlet;
		connect feedwaterControlValve.outlet to boiler.feedwaterInlet;
	}

	requirement def FlowRateRequirement {
		doc /* The pump shall deliver feedwater at a continuous flow rate between 80 and 120 kg/s. */
		subject pump : BoilerFeedwaterPump;
		attribute minFlowRate : FlowRate = 80;
		attribute maxFlowRate : FlowRate = 120;
		constraint { pump.discharge.flowRate >= minFlowRate and pump.discharge.flowRate <= maxFlowRate }
	}

	requirement def PressureDeliveryRequirement {
		doc /* The pump shall deliver feedwater at a pressure of at least 10 MPa at the discharge. */
		subject pump : BoilerFeedwaterPump;
		attribute minDischargePressure : Pressure = 10000;
		constraint { pump.discharge.pressure >= minDischargePressure }
	}

	requirement def EnergyEfficiencyRequirement {
		doc /* The pump motor rated power shall not exceed 5000 kW. */
		subject pump : BoilerFeedwaterPump;
		attribute maxPower : Power = 5000;
		constraint { pump.motor.ratedPower <= maxPower }
	}

	requirement subsystemSpecification {
		doc /* Overall boiler feedwater pumping subsystem requirements. */
		subject subsystem : BoilerFeedwaterPumpingSubsystem;
		require flowReqA : FlowRateRequirement {
			subject = subsystem.pumpLineA.pump;
		}
		require pressureReqA : PressureDeliveryRequirement {
			subject = subsystem.pumpLineA.pump;
		}
		require efficiencyReqA : EnergyEfficiencyRequirement {
			subject = subsystem.pumpLineA.pump;
		}
		require flowReqB : FlowRateRequirement {
			subject = subsystem.pumpLineB.pump;
		}
		require pressureReqB : PressureDeliveryRequirement {
			subject = subsystem.pumpLineB.pump;
		}
		require efficiencyReqB : EnergyEfficiencyRequirement {
			subject = subsystem.pumpLineB.pump;
		}
	}
}
