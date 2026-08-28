package 'Industrial Slurry Pumping Subsystem' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ScalarValues::String;

	package Definitions {
		attribute def Pressure :> Real {
			unit = 'bar';
		}
		attribute def FlowRate :> Real {
			unit = 'm3/h';
		}
		attribute def Temperature :> Real {
			unit = 'degC';
		}
		attribute def Vibration :> Real {
			unit = 'mm/s';
		}
		attribute def SolidsContent :> Real {
			unit = '%';
		}

		item def Slurry {
			attribute solidsConcentration : SolidsContent;
			attribute density : Real;
			attribute viscosity : Real;
			attribute abrasiveness : Real;
		}

		port def SlurryOutPort {
			out item slurry : Slurry;
		}
		port def SlurryInPort {
			in item slurry : Slurry;
		}
		port def PressureSensorOutPort {
			out attribute pressure : Pressure;
		}
		port def FlowSensorOutPort {
			out attribute flowRate : FlowRate;
		}

		part def SupplyTank {
			port slurryOut : SlurryOutPort;
			attribute solidsContent : SolidsContent = 50;
			attribute capacity : Real;
		}

		part def DischargeTank {
			port slurryIn : SlurryInPort;
			attribute currentLevel : Real;
			attribute capacity : Real;
		}

		part def Pipe {
			port slurryIn : SlurryInPort;
			port slurryOut : SlurryOutPort;
		}

		part def ControlValve {
			port slurryIn : SlurryInPort;
			port slurryOut : SlurryOutPort;
			attribute isOpen : Boolean = true;
		}

		part def PressureSensor {
			port pressureOut : PressureSensorOutPort;
			attribute measuredPressure : Pressure;
		}

		part def FlowSensor {
			port flowOut : FlowSensorOutPort;
			attribute measuredFlowRate : FlowRate;
		}

		action def MonitorPumpHealth {
			in vibration : Vibration;
			in temperature : Temperature;
			in inletPressure : Pressure;
			in outletPressure : Pressure;
			in flowRate : FlowRate;
			out healthStatus : Boolean;
		}

		state machine def PumpStates {
			state stopped;
			state starting;
			state operating;
			state faulted;

			transition from stopped to starting;
			transition from starting to operating;
			transition from operating to faulted;
			transition from faulted to stopped;
			transition from operating to stopped;
		}

		part def HighDensitySolidsPump {
			port suctionPort : SlurryInPort;
			port dischargePort : SlurryOutPort;

			attribute vibration : Vibration;
			attribute pumpTemperature : Temperature;
			attribute inletPressure : Pressure;
			attribute outletPressure : Pressure;
			attribute flowRate : FlowRate;
			attribute healthStatus : Boolean;

			perform action monitorHealth : MonitorPumpHealth {
				in vibration = self.vibration;
				in temperature = self.pumpTemperature;
				in inletPressure = self.inletPressure;
				in outletPressure = self.outletPressure;
				in flowRate = self.flowRate;
				out healthStatus = self.healthStatus;
			}

			exhibit state : PumpStates;
		}

		interface def SlurryInterface {
			end supplier : SlurryOutPort;
			end consumer : SlurryInPort;
		}

		requirement def MinFlowRateRequirement {
			doc /* The system shall maintain a minimum slurry flow rate during normal operation. */
			subject pump : HighDensitySolidsPump;
			attribute minFlow : FlowRate = 10.0;
			constraint { pump.flowRate >= minFlow }
		}

		requirement def HighDischargePressureRequirement {
			doc /* The pump shall achieve a high discharge pressure to transport high-density slurry. */
			subject pump : HighDensitySolidsPump;
			attribute minPressure : Pressure = 50.0;
			constraint { pump.outletPressure >= minPressure }
		}

		requirement def SafetyConstraintsRequirement {
			doc /* The system shall adhere to critical safety constraints to prevent over-pressurization and equipment damage. */
			subject pump : HighDensitySolidsPump;
			attribute maxVibration : Vibration = 10.0;
			attribute maxTemperature : Temperature = 80.0;
			attribute maxPressure : Pressure = 100.0;
			constraint { pump.vibration <= maxVibration }
			constraint { pump.pumpTemperature <= maxTemperature }
			constraint { pump.outletPressure <= maxPressure }
		}

		requirement def SolidsContentRangeRequirement {
			doc /* The slurry solids content shall be between 35% and 70% for proper pump operation. */
			subject tank : SupplyTank;
			constraint { tank.solidsContent >= 35.0 and tank.solidsContent <= 70.0 }
		}

		requirement def PumpingSystemSpecification {
			doc /* Overall pumping system requirements group */
			subject system : HighDensitySolidsPump;
			require minFlow : MinFlowRateRequirement;
			require highPressure : HighDischargePressureRequirement;
			require safety : SafetyConstraintsRequirement;
		}
	}

	package Usages {
		part context {
			part supplyTank : Definitions::SupplyTank;
			part suctionPipe : Definitions::Pipe;
			part suctionValve : Definitions::ControlValve;
			part pump : Definitions::HighDensitySolidsPump;
			part dischargePipe : Definitions::Pipe;
			part dischargeValve : Definitions::ControlValve;
			part deliveryPipe : Definitions::Pipe;
			part dischargeTank : Definitions::DischargeTank;

			part inletPressureSensor : Definitions::PressureSensor;
			part outletPressureSensor : Definitions::PressureSensor;
			part flowSensor : Definitions::FlowSensor;

			interface tankToSuctionPipe : Definitions::SlurryInterface connect
				supplier ::> supplyTank.slurryOut to
				consumer ::> suctionPipe.slurryIn;
			interface suctionPipeToValve : Definitions::SlurryInterface connect
				supplier ::> suctionPipe.slurryOut to
				consumer ::> suctionValve.slurryIn;
			interface suctionValveToPump : Definitions::SlurryInterface connect
				supplier ::> suctionValve.slurryOut to
				consumer ::> pump.suctionPort;
			interface pumpToDischargePipe : Definitions::SlurryInterface connect
				supplier ::> pump.dischargePort to
				consumer ::> dischargePipe.slurryIn;
			interface dischargePipeToValve : Definitions::SlurryInterface connect
				supplier ::> dischargePipe.slurryOut to
				consumer ::> dischargeValve.slurryIn;
			interface dischargeValveToDeliveryPipe : Definitions::SlurryInterface connect
				supplier ::> dischargeValve.slurryOut to
				consumer ::> deliveryPipe.slurryIn;
			interface deliveryPipeToDischargeTank : Definitions::SlurryInterface connect
				supplier ::> deliveryPipe.slurryOut to
				consumer ::> dischargeTank.slurryIn;

			flow of slurry : Definitions::Slurry
				from supplyTank.slurryOut.slurry to suctionPipe.slurryIn.slurry;
			flow of slurry : Definitions::Slurry
				from suctionPipe.slurryOut.slurry to suctionValve.slurryIn.slurry;
			flow of slurry : Definitions::Slurry
				from suctionValve.slurryOut.slurry to pump.suctionPort.slurry;
			flow of slurry : Definitions::Slurry
				from pump.dischargePort.slurry to dischargePipe.slurryIn.slurry;
			flow of slurry : Definitions::Slurry
				from dischargePipe.slurryOut.slurry to dischargeValve.slurryIn.slurry;
			flow of slurry : Definitions::Slurry
				from dischargeValve.slurryOut.slurry to deliveryPipe.slurryIn.slurry;
			flow of slurry : Definitions::Slurry
				from deliveryPipe.slurryOut.slurry to dischargeTank.slurryIn.slurry;

			bind inletPressureSensor.pressureOut.pressure = pump.inletPressure;
			bind outletPressureSensor.pressureOut.pressure = pump.outletPressure;
			bind flowSensor.flowOut.flowRate = pump.flowRate;

			require minFlowReq : Definitions::MinFlowRateRequirement {
				subject = pump;
			}
			require highPressureReq : Definitions::HighDischargePressureRequirement {
				subject = pump;
			}
			require safetyReq : Definitions::SafetyConstraintsRequirement {
				subject = pump;
			}
			require solidsRangeReq : Definitions::SolidsContentRangeRequirement {
				subject = supplyTank;
			}
		}
	}
}
