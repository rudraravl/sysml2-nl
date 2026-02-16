package 'Air Driven Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package ItemDefinitions {
		item def Fluid {
			attribute volume : VolumeValue;
			attribute pressure : PressureValue;
			attribute temperature : ThermodynamicTemperatureValue;
			attribute flowRate : VolumeFlowValue;
		}
		
		item def CompressedAir {
			attribute pressure : PressureValue;
			attribute temperature : ThermodynamicTemperatureValue;
			attribute flowRate : VolumeFlowValue;
		}
	}
	
	package PortDefinitions {
		import ItemDefinitions::*;
		
		enum def ControlCommand {
			enum start;
			enum stop;
			enum regulate;
		}
		
		port def FluidInletPort {
			in item fluidIn : Fluid;
		}
		
		port def FluidOutletPort {
			out item fluidOut : Fluid;
		}
		
		port def AirSupplyPort {
			in item airIn : CompressedAir;
		}
		
		port def AirExhaustPort {
			out item airOut : CompressedAir;
		}
		
		port def ControlSignalPort {
			in attribute commandSignal : ControlCommand;
		}
	}
	
	package ComponentDefinitions {
		import ItemDefinitions::*;
		import PortDefinitions::*;
		
		part def AirCompressor {
			port airOutlet : AirExhaustPort;
			
			attribute supplyPressure : PressureValue = 700000[Pa];
			attribute supplyFlowRate : VolumeFlowValue = 150[L/min];
			
			bind airOutlet.airOut.pressure = supplyPressure;
			bind airOutlet.airOut.flowRate = supplyFlowRate;
		}
		
		part def FluidReservoir {
			port fluidOutlet : FluidOutletPort;
			
			attribute capacity : VolumeValue = 100[L];
			attribute currentLevel : VolumeValue;
			attribute ambientPressure : PressureValue = 101325[Pa];
			
			item storedFluid : Fluid {
				attribute :>> volume = currentLevel;
				attribute :>> pressure = ambientPressure;
			}
			
			bind fluidOutlet.fluidOut = storedFluid;
		}
		
		part def FluidReceiver {
			port fluidInlet : FluidInletPort;
			
			attribute capacity : VolumeValue = 80[L];
			attribute currentLevel : VolumeValue = 0[L];
			
			item receivedFluid : Fluid {
				attribute :>> volume = currentLevel;
			}
		}
		
		part def PressureRegulator {
			port airInlet : AirSupplyPort;
			port airOutlet : AirExhaustPort;
			
			attribute setPointPressure : PressureValue = 600000[Pa];
			attribute regulatedPressure : PressureValue;
			
			assert constraint {
				regulatedPressure <= setPointPressure
			}
			
			bind airOutlet.airOut.pressure = regulatedPressure;
		}
		
		part def CheckValve {
			port fluidInlet : FluidInletPort;
			port fluidOutlet : FluidOutletPort;
			
			attribute crackingPressure : PressureValue = 5000[Pa];
			attribute reverseLeakage : VolumeFlowValue = 0.01[L/min];
			
			assert constraint {
				fluidInlet.fluidIn.pressure >= crackingPressure implies
				fluidOutlet.fluidOut.flowRate > 0[L/min]
			}
		}
		
		part def AirDrivenPump {
			port airInlet : AirSupplyPort;
			port airExhaust : AirExhaustPort;
			port fluidInlet : FluidInletPort;
			port fluidOutlet : FluidOutletPort;
			port controlPort : ControlSignalPort;
			
			attribute maxDischargePressure : PressureValue = 500000[Pa];
			attribute ratedFlowRate : VolumeFlowValue = 80[L/min];
			attribute efficiency : Real = 0.72;
			attribute cycleRate : Real = 60.0;
			attribute strokeVolume : VolumeValue = 1.33[L];
			attribute currentFlowRate : VolumeFlowValue;
			
			perform action pumpingCycle : PumpingCycle;
			
			exhibit state pumpController : PumpStateMachine;
			
			assert constraint flowRateRelation {
				fluidOutlet.fluidOut.flowRate == 
					(airInlet.airIn.pressure / 100000[Pa]) * efficiency * ratedFlowRate
			}
			
			assert constraint pressureLimit {
				fluidOutlet.fluidOut.pressure <= maxDischargePressure
			}
		}
		
		part def PressureSensor {
			port sensingPort : FluidInletPort;
			
			attribute measuredPressure : PressureValue;
			attribute accuracy : Real = 0.98;
			
			bind measuredPressure = sensingPort.fluidIn.pressure * accuracy;
		}
		
		part def SystemController {
			port sensorInput : FluidInletPort;
			port controlOutput : ~ControlSignalPort;
			
			attribute targetPressure : PressureValue = 400000[Pa];
			attribute hysteresis : PressureValue = 50000[Pa];
			attribute currentCommand : ControlCommand = ControlCommand::stop;
			
			perform action controlLogic : ControlLogic;
			
			exhibit state controlStateMachine : ControlStateMachine;
			
			bind controlOutput.commandSignal = currentCommand;
		}
		
		action def PumpingCycle {
			in driveAir : CompressedAir;
			in intakeFluid : Fluid;
			out dischargeFluid : Fluid;
			out exhaustAir : CompressedAir;
			
			action intakeStroke {
				in air : CompressedAir = driveAir;
				out fluid : Fluid;
			}
			
			then action compressionStroke {
				in fluid : Fluid = intakeStroke.fluid;
				in air : CompressedAir = driveAir;
				out pressurizedFluid : Fluid = dischargeFluid;
			}
			
			then action exhaustStroke {
				out air : CompressedAir = exhaustAir;
			}
		}
		
		action def ControlLogic {
			in measuredPressure : PressureValue;
			in targetPressure : PressureValue;
			in hysteresis : PressureValue;
			out command : ControlCommand;
			
			assert constraint {
				measuredPressure < (targetPressure - hysteresis) implies
				command == ControlCommand::start
			}
			
			assert constraint {
				measuredPressure > (targetPressure + hysteresis) implies
				command == ControlCommand::stop
			}
		}
		
		state def PumpStateMachine {
			entry; then idle;
			
			state idle;
			
			state priming;
			
			state pumping {
				state normalOperation;
				
				state highPressure;
			}
			
			state stopping;
			
			state fault;
			
			transition idle_to_priming
				first idle
				accept at controlPort when controlPort.commandSignal == ControlCommand::start
				then priming;
			
			transition priming_to_pumping
				first priming
				if fluidOutlet.fluidOut.flowRate >= ratedFlowRate * 0.5
				then pumping;
			
			transition pumping_to_normalOperation
				first pumping
				then normalOperation;
			
			transition normalOperation_to_highPressure
				first normalOperation
				if fluidOutlet.fluidOut.pressure >= maxDischargePressure * 0.85
				then highPressure;
			
			transition highPressure_to_normalOperation
				first highPressure
				if fluidOutlet.fluidOut.pressure < maxDischargePressure * 0.75
				then normalOperation;
			
			transition pumping_to_stopping
				first pumping
				accept at controlPort when controlPort.commandSignal == ControlCommand::stop
				then stopping;
			
			transition stopping_to_idle
				first stopping
				if fluidOutlet.fluidOut.flowRate <= ratedFlowRate * 0.05
				then idle;
			
			transition to_fault
				first pumping
				if fluidOutlet.fluidOut.pressure >= maxDischargePressure
				then fault;
			
			transition fault_to_idle
				first fault
				accept ResetCommand
				then idle;
		}
		
		state def ControlStateMachine {
			entry; then monitoring;
			
			state monitoring;
			
			state activating {
				do action sendStartCommand {
					assign currentCommand = ControlCommand::start;
				}
			}
			
			state deactivating {
				do action sendStopCommand {
					assign currentCommand = ControlCommand::stop;
				}
			}
			
			transition monitoring_to_activating
				first monitoring
				if sensorInput.fluidIn.pressure < (targetPressure - hysteresis)
				then activating;
			
			transition activating_to_monitoring
				first activating
				then monitoring;
			
			transition monitoring_to_deactivating
				first monitoring
				if sensorInput.fluidIn.pressure > (targetPressure + hysteresis)
				then deactivating;
			
			transition deactivating_to_monitoring
				first deactivating
				then monitoring;
		}
	}
	
	package RequirementDefinitions {
		import ComponentDefinitions::*;
		
		requirement def FlowRateRequirement {
			doc /* The pumping subsystem shall deliver a minimum flow rate of 75 liters per minute. */
			
			attribute minFlowRate : VolumeFlowValue = 75[L/min];
			
			subject pump : AirDrivenPump;
			
			require constraint {
				pump.ratedFlowRate >= minFlowRate
			}
		}
		
		requirement def PressureRequirement {
			doc /* The pumping subsystem shall maintain discharge pressure between 350 kPa and 450 kPa. */
			
			attribute minPressure : PressureValue = 350000[Pa];
			attribute maxPressure : PressureValue = 450000[Pa];
			
			subject system : PumpingSubsystemAssembly;
			
			require constraint {
				system.receiver.fluidInlet.fluidIn.pressure >= minPressure and
				system.receiver.fluidInlet.fluidIn.pressure <= maxPressure
			}
		}
		
		requirement def EfficiencyRequirement {
			doc /* The air-driven pump shall operate at minimum 70% efficiency. */
			
			attribute minEfficiency : Real = 0.70;
			
			subject pump : AirDrivenPump;
			
			require constraint {
				pump.efficiency >= minEfficiency
			}
		}
		
		requirement def AirSupplyRequirement {
			doc /* The air compressor shall provide minimum 600 kPa supply pressure. */
			
			attribute minSupplyPressure : PressureValue = 600000[Pa];
			
			subject compressor : AirCompressor;
			
			require constraint {
				compressor.supplyPressure >= minSupplyPressure
			}
		}
		
		requirement def SystemRequirements {
			doc /* Top-level requirements for the air-driven pumping subsystem. */
			
			subject system : PumpingSubsystemAssembly;
			
			require flowReq : FlowRateRequirement;
			require pressureReq : PressureRequirement;
			require efficiencyReq : EfficiencyRequirement;
			require airSupplyReq : AirSupplyRequirement;
		}
	}
	
	package Assembly {
		import ComponentDefinitions::*;
		import ItemDefinitions::*;
		
		part def PumpingSubsystemAssembly {
			part compressor : AirCompressor;
			part regulator : PressureRegulator;
			part reservoir : FluidReservoir;
			part pump : AirDrivenPump;
			part checkValve : CheckValve;
			part receiver : FluidReceiver;
			part pressureSensor : PressureSensor;
			part controller : SystemController;
		}
		
		part pumpingSubsystem : PumpingSubsystemAssembly {
			
			part :>> compressor {
				attribute :>> supplyPressure = 700000[Pa];
				attribute :>> supplyFlowRate = 150[L/min];
			}
			
			part :>> regulator {
				attribute :>> setPointPressure = 600000[Pa];
				attribute :>> regulatedPressure = 600000[Pa];
			}
			
			part :>> reservoir {
				attribute :>> capacity = 100[L];
				attribute :>> currentLevel = 75[L];
			}
			
			part :>> pump {
				attribute :>> maxDischargePressure = 500000[Pa];
				attribute :>> ratedFlowRate = 80[L/min];
				attribute :>> efficiency = 0.72;
			}
			
			part :>> checkValve {
				attribute :>> crackingPressure = 5000[Pa];
			}
			
			part :>> receiver {
				attribute :>> capacity = 80[L];
			}
			
			part :>> pressureSensor {
				attribute :>> accuracy = 0.98;
			}
			
			part :>> controller {
				attribute :>> targetPressure = 400000[Pa];
				attribute :>> hysteresis = 50000[Pa];
			}
			
			flow airSupply of air : CompressedAir
				from compressor.airOutlet.airOut to regulator.airInlet.airIn;
			
			flow regulatedAir of air : CompressedAir
				from regulator.airOutlet.airOut to pump.airInlet.airIn;
			
			flow fluidIntake of fluid : Fluid
				from reservoir.fluidOutlet.fluidOut to pump.fluidInlet.fluidIn;
			
			flow pumpedFluid of fluid : Fluid
				from pump.fluidOutlet.fluidOut to checkValve.fluidInlet.fluidIn;
			
			flow deliveredFluid of fluid : Fluid
				from checkValve.fluidOutlet.fluidOut to receiver.fluidInlet.fluidIn;
			
			bind pressureSensor.sensingPort.fluidIn = receiver.fluidInlet.fluidIn;
			
			connect controller.sensorInput to pressureSensor.sensingPort;
			
			connect controller.controlOutput to pump.controlPort;
			
			perform action systemOperation : SystemOperation;
		}
		
		action def SystemOperation {
			action supplyAir {
				out compressedAir : CompressedAir;
			}
			
			then action regulateAir {
				in rawAir : CompressedAir = supplyAir.compressedAir;
				out regulatedAir : CompressedAir;
			}
			
			then action pumpFluid {
				in driveAir : CompressedAir = regulateAir.regulatedAir;
				in sourceFluid : Fluid;
				out pumpedFluid : Fluid;
			}
			
			then action deliverFluid {
				in fluid : Fluid = pumpFluid.pumpedFluid;
				out deliveredFluid : Fluid;
			}
			
			then action monitorPressure {
				in fluid : Fluid = deliverFluid.deliveredFluid;
				out pressureReading : PressureValue;
			}
			
			then action controlPump {
				in reading : PressureValue = monitorPressure.pressureReading;
				out command : ControlCommand;
			}
		}
	}
	
	package Verification {
		import Assembly::*;
		import RequirementDefinitions::*;
		
		requirement systemRequirements : SystemRequirements {
			subject pumpingSubsystem;
			
			requirement :>> flowReq {
				subject pumpingSubsystem.pump;
			}
			
			requirement :>> pressureReq {
				subject pumpingSubsystem;
			}
			
			requirement :>> efficiencyReq {
				subject pumpingSubsystem.pump;
			}
			
			requirement :>> airSupplyReq {
				subject pumpingSubsystem.compressor;
			}
		}
		
		satisfy systemRequirements by pumpingSubsystem;
	}
}
