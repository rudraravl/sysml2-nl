package 'Centrifugal Pumping Subsystem' {
	private import ScalarValues::*;
	
	item def Fluid;
	item def RotationalEnergy;
	item def PressureSignal {
		attribute value : PressureValue;
	}
	item def FlowRateSignal {
		attribute value : VolumeFlowRateValue;
	}
	item def MotorCommand {
		attribute speed : RotationalSpeedValue;
	}
	
	value type PressureValue :> Real { unit = 'bar'; }
	value type VolumeFlowRateValue :> Real { unit = 'L/min'; }
	value type RotationalSpeedValue :> Real { unit = 'rpm'; }
	
	part def SourceReservoir {
		port fluidOut { out fluid : Fluid; }
	}
	
	part def SuctionPiping {
		port fluidIn { in fluid : Fluid; }
		port fluidOut { out fluid : Fluid; }
	}
	
	part def DischargePiping {
		port fluidIn { in fluid : Fluid; }
		port fluidOut { out fluid : Fluid; }
	}
	
	part def ElectricMotor {
		port commandIn { in cmd : MotorCommand; }
		port mechanicalOut { out rotation : RotationalEnergy; }
		attribute currentSpeed : RotationalSpeedValue = 1000;
		
		action motorBehavior {
			accept cmd : MotorCommand via commandIn;
			then send new RotationalEnergy() via mechanicalOut;
		}
	}
	
	part def CentrifugalPump {
		port fluidIn { in fluid : Fluid; }
		port fluidOut { out fluid : Fluid; }
		port mechanicalIn { in rotation : RotationalEnergy; }
		
		action pumpOperation {
			accept energy : RotationalEnergy via mechanicalIn;
			then send new Fluid() via fluidOut;
		}
	}
	
	part def PressureSensor {
		port fluidIn { in fluid : Fluid; }
		port fluidOut { out fluid : Fluid; }
		port signalOut { out signal : PressureSignal; }
		
		action sensingBehavior {
			accept fluid : Fluid via fluidIn;
			then send new Fluid() via fluidOut;
			then send new PressureSignal() via signalOut;
		}
	}
	
	part def FlowMeter {
		port fluidIn { in fluid : Fluid; }
		port fluidOut { out fluid : Fluid; }
		port signalOut { out signal : FlowRateSignal; }
		
		action sensingBehavior {
			accept fluid : Fluid via fluidIn;
			then send new Fluid() via fluidOut;
			then send new FlowRateSignal() via signalOut;
		}
	}
	
	state def ControlBehavior {
		entry; then monitoring;
		state monitoring;
		transition monitoring_to_adjusting
			first monitoring
			accept p : PressureSignal
			then adjusting;
		state adjusting;
		transition adjusting_to_monitoring
			first adjusting
			accept p : PressureSignal
			then monitoring;
	}
	
	part def PumpController {
		port pressureIn { in signal : PressureSignal; }
		port flowIn { in signal : FlowRateSignal; }
		port commandOut { out cmd : MotorCommand; }
		
		attribute targetPressure : PressureValue = 3.5;
		attribute targetFlowRate : VolumeFlowRateValue = 50.0;
		attribute currentCommandSpeed : RotationalSpeedValue = 1500;
		
		state controlBehavior : ControlBehavior;
		
		action controllerBehavior {
			action receivePressure accept p : PressureSignal via pressureIn;
			then action receiveFlow accept f : FlowRateSignal via flowIn;
			then action computeCommand {
				in pressure : PressureSignal = receivePressure.p;
				in flow : FlowRateSignal = receiveFlow.f;
				in targetP : PressureValue = targetPressure;
				in targetF : VolumeFlowRateValue = targetFlowRate;
				out cmd : MotorCommand;
			}
			then send new MotorCommand(speed = currentCommandSpeed) via commandOut;
		}
	}
	
	part def PumpingSubsystem {
		part reservoir : SourceReservoir;
		part suction : SuctionPiping;
		part pump : CentrifugalPump;
		part motor : ElectricMotor;
		part discharge : DischargePiping;
		part pressureSensor : PressureSensor;
		part flowMeter : FlowMeter;
		part controller : PumpController;
		
		flow fluidFlow1 of Fluid from reservoir.fluidOut.fluid to suction.fluidIn.fluid;
		flow fluidFlow2 of Fluid from suction.fluidOut.fluid to pump.fluidIn.fluid;
		flow fluidFlow3 of Fluid from pump.fluidOut.fluid to discharge.fluidIn.fluid;
		flow fluidFlow4 of Fluid from discharge.fluidOut.fluid to pressureSensor.fluidIn.fluid;
		flow fluidFlow5 of Fluid from pressureSensor.fluidOut.fluid to flowMeter.fluidIn.fluid;
		
		flow mechanicalFlow of RotationalEnergy from motor.mechanicalOut.rotation to pump.mechanicalIn.rotation;
		
		flow pressureSignalFlow of PressureSignal from pressureSensor.signalOut.signal to controller.pressureIn.signal;
		flow flowSignalFlow of FlowRateSignal from flowMeter.signalOut.signal to controller.flowIn.signal;
		flow commandFlow of MotorCommand from controller.commandOut.cmd to motor.commandIn.cmd;
	}
	
	part pumpingSubsystem : PumpingSubsystem;
	
	requirement def PumpPerformanceRequirements {
		subject subsystem : PumpingSubsystem;
		
		requirement minFlowRateRequirement {
			doc /* The system must deliver a minimum flow rate of 50 L/min. */
			constraint { subsystem.flowMeter.signalOut.signal.value >= 50.0 }
		}
		
		requirement pressureRangeRequirement {
			doc /* The discharge pressure must be maintained within 2 to 5 bar. */
			constraint { subsystem.pressureSensor.signalOut.signal.value >= 2.0 and subsystem.pressureSensor.signalOut.signal.value <= 5.0 }
		}
		
		requirement energyEfficiencyRequirement {
			doc /* The system must operate with high energy efficiency. */
		}
		
		requirement reliabilityRequirement {
			doc /* The system must have long-term reliability. */
		}
	}
	
	requirement pumpPerformance : PumpPerformanceRequirements {
		subject subsystem :>> pumpingSubsystem;
	}
}
