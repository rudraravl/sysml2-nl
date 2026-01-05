package 'Downton Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : TemperatureValue;
		}
		
		port def FluidPort {
			attribute pressure : PressureValue;
			attribute flowRate : VolumeFlowRateValue;
			out item fluid : Fluid;
		}
		
		port def PowerPort {
			in attribute voltage : ElectricPotentialValue;
			in attribute current : ElectricCurrentValue;
			attribute power : PowerValue;
		}
		
		port def ControlPort {
			in attribute commandSpeed : AngularVelocityValue;
			out attribute actualSpeed : AngularVelocityValue;
			out attribute status : PumpStatus;
		}
		
		port def SensorDataPort {
			out attribute sensorValue : Real;
			out attribute timestamp : String;
		}
		
		enum def PumpStatus {
			enum stopped;
			enum starting;
			enum running;
			enum stopping;
			enum fault;
		}
		
		enum def ControlMode {
			enum constantSpeed;
			enum constantFlow;
			enum constantPressure;
		}
		
		part def DowntonPump {
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			port powerPort : PowerPort;
			port controlPort : ControlPort;
			
			attribute ratedFlowRate : VolumeFlowRateValue;
			attribute ratedPressure : PressureValue;
			attribute efficiency : Real;
			attribute currentSpeed : AngularVelocityValue;
			attribute maxSpeed : AngularVelocityValue;
			
			part impeller {
				attribute diameter : LengthValue;
				attribute bladeCount : Integer;
			}
			
			part motor {
				attribute ratedPower : PowerValue;
				attribute voltage : ElectricPotentialValue;
			}
			
			part casing {
				attribute material : String;
				attribute maxPressureRating : PressureValue;
			}
			
			part shaft {
				attribute diameter : LengthValue;
				attribute material : String;
			}
			
			part sealAssembly {
				attribute sealType : String;
				attribute leakageRate : VolumeFlowRateValue;
			}
			
			perform action pumpingAction : PumpFluid {
				in inletPressure = inletPort.pressure;
				in commandedSpeed = controlPort.commandSpeed;
				out outletPressure = outletPort.pressure;
				out actualFlowRate = outletPort.flowRate;
				in fluidIn = inletPort.fluid;
				out fluidOut = outletPort.fluid;
			}
			
			exhibit state pumpStates : PumpOperatingStates;
		}
		
		part def FluidReservoir {
			port outletPort : FluidPort;
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			attribute minLevel : VolumeValue;
			
			item storedFluid : Fluid {
				attribute volume : VolumeValue;
			}
			
			assert constraint { currentLevel >= minLevel }
		}
		
		part def PressureVessel {
			port inletPort : ~FluidPort;
			attribute capacity : VolumeValue;
			attribute designPressure : PressureValue;
			attribute currentPressure : PressureValue;
			
			item containedFluid : Fluid {
				attribute volume : VolumeValue;
			}
			
			assert constraint { currentPressure <= designPressure }
		}
		
		part def FlowSensor {
			port measurementPort : ~FluidPort;
			port dataPort : SensorDataPort;
			attribute measuredFlowRate : VolumeFlowRateValue;
			attribute accuracy : Real;
		}
		
		part def PressureSensor {
			port measurementPort : ~FluidPort;
			port dataPort : SensorDataPort;
			attribute measuredPressure : PressureValue;
			attribute accuracy : Real;
		}
		
		part def PumpController {
			port controlOut : ~ControlPort;
			port flowSensorIn : ~SensorDataPort;
			port pressureSensorIn : ~SensorDataPort;
			port powerControl : ~PowerPort;
			
			attribute targetFlowRate : VolumeFlowRateValue;
			attribute targetPressure : PressureValue;
			attribute controlMode : ControlMode;
			
			perform action controlPump : ControlPump {
				in targetFlow = targetFlowRate;
				in measuredFlow = flowSensorIn.sensorValue;
				in measuredPressure = pressureSensorIn.sensorValue;
				out speedCommand = controlOut.commandSpeed;
			}
		}
		
		part def PipeSegment {
			port inlet : ~FluidPort;
			port outlet : FluidPort;
			attribute length : LengthValue;
			attribute diameter : LengthValue;
			attribute roughness : LengthValue;
		}
		
		part def Valve {
			port inlet : ~FluidPort;
			port outlet : FluidPort;
			attribute position : Real;
			attribute maxFlowCoefficient : Real;
		}
		
		action def PumpFluid {
			in attribute inletPressure : PressureValue;
			in attribute commandedSpeed : AngularVelocityValue;
			out attribute outletPressure : PressureValue;
			out attribute actualFlowRate : VolumeFlowRateValue;
			in item fluidIn : Fluid;
			out item fluidOut : Fluid;
		}
		
		action def ControlPump {
			in attribute targetFlow : VolumeFlowRateValue;
			in attribute measuredFlow : Real;
			in attribute measuredPressure : Real;
			out attribute speedCommand : AngularVelocityValue;
		}
		
		state def PumpOperatingStates {
			entry; then idle;
			
			state idle;
			state startup;
			state operational {
				state normalOperation;
				state reducedFlow;
				
				transition first normalOperation;
				transition reducedFlow_transition
					first normalOperation
					accept flowReduction
					then reducedFlow;
				transition normal_transition
					first reducedFlow
					accept flowIncrease
					then normalOperation;
			}
			state shutdown;
			state faulted;
			
			transition start_transition
				first idle
				accept startCommand
				then startup;
			
			transition run_transition
				first startup
				accept speedAchieved
				then operational;
			
			transition stop_transition
				first operational
				accept stopCommand
				then shutdown;
			
			transition stopped_transition
				first shutdown
				accept speedZero
				then idle;
			
			transition fault_transition
				first operational
				accept faultDetected
				then faulted;
			
			transition reset_transition
				first faulted
				accept faultReset
				then idle;
		}
	}
	
	package Requirements {
		requirement def PumpingSystemRequirements {
			subject pumpingSystem : PumpingSubsystem;
			
			require flowRateRequirement {
				doc /* The system shall deliver a minimum flow rate of 100 liters per minute. */
				assume pumpingSystem.downtonPump.ratedFlowRate >= 100.0 [L/min];
			}
			
			require pressureRequirement {
				doc /* The system shall maintain outlet pressure of at least 5 bar. */
				assume pumpingSystem.outletPressureSensor.measuredPressure >= 5.0 [bar];
			}
			
			require efficiencyRequirement {
				doc /* The pump shall operate at minimum 75% efficiency at rated conditions. */
				assume pumpingSystem.downtonPump.efficiency >= 0.75;
			}
			
			require reliabilityRequirement {
				doc /* The system shall detect and respond to fault conditions within 1 second. */
			}
		}
	}
	
	package Usages {
		part def PumpingSubsystem {
			part sourceReservoir : FluidReservoir;
			part suctionPipe : PipeSegment;
			part suctionValve : Valve;
			part inletFlowSensor : FlowSensor;
			part downtonPump : DowntonPump;
			part dischargePipe : PipeSegment;
			part outletPressureSensor : PressureSensor;
			part outletFlowSensor : FlowSensor;
			part dischargeValve : Valve;
			part destinationVessel : PressureVessel;
			part controller : PumpController;
		}
		
		part pumpingSubsystem : PumpingSubsystem {
			
			part :>> sourceReservoir {
				attribute :>> capacity = 1000.0 [L];
				attribute :>> currentLevel = 750.0 [L];
				attribute :>> minLevel = 100.0 [L];
				
				item :>> storedFluid {
					attribute :>> volume = 750.0 [L];
					attribute :>> density = 1000.0;
					attribute :>> viscosity = 0.001;
					attribute :>> temperature = 293.15 [K];
				}
			}
			
			part :>> suctionPipe {
				attribute :>> length = 2.0 [m];
				attribute :>> diameter = 0.05 [m];
				attribute :>> roughness = 0.000045 [m];
			}
			
			part :>> suctionValve {
				attribute :>> position = 1.0;
				attribute :>> maxFlowCoefficient = 50.0;
			}
			
			part :>> inletFlowSensor {
				attribute :>> accuracy = 0.02;
			}
			
			part :>> downtonPump {
				attribute :>> ratedFlowRate = 120.0 [L/min];
				attribute :>> ratedPressure = 6.0 [bar];
				attribute :>> efficiency = 0.78;
				attribute :>> currentSpeed = 0.0 [rpm];
				attribute :>> maxSpeed = 3000.0 [rpm];
				
				part :>> impeller {
					attribute :>> diameter = 0.15 [m];
					attribute :>> bladeCount = 6;
				}
				
				part :>> motor {
					attribute :>> ratedPower = 2.2 [kW];
					attribute :>> voltage = 400.0 [V];
				}
				
				part :>> casing {
					attribute :>> material = "Cast Iron";
					attribute :>> maxPressureRating = 10.0 [bar];
				}
				
				part :>> shaft {
					attribute :>> diameter = 0.025 [m];
					attribute :>> material = "Stainless Steel 316";
				}
				
				part :>> sealAssembly {
					attribute :>> sealType = "Mechanical Seal";
					attribute :>> leakageRate = 0.001 [L/min];
				}
			}
			
			part :>> dischargePipe {
				attribute :>> length = 5.0 [m];
				attribute :>> diameter = 0.04 [m];
				attribute :>> roughness = 0.000045 [m];
			}
			
			part :>> outletPressureSensor {
				attribute :>> accuracy = 0.01;
			}
			
			part :>> outletFlowSensor {
				attribute :>> accuracy = 0.02;
			}
			
			part :>> dischargeValve {
				attribute :>> position = 0.8;
				attribute :>> maxFlowCoefficient = 45.0;
			}
			
			part :>> destinationVessel {
				attribute :>> capacity = 500.0 [L];
				attribute :>> designPressure = 10.0 [bar];
				attribute :>> currentPressure = 5.5 [bar];
				
				item :>> containedFluid {
					attribute :>> volume = 200.0 [L];
					attribute :>> density = 1000.0;
					attribute :>> viscosity = 0.001;
					attribute :>> temperature = 295.15 [K];
				}
			}
			
			part :>> controller {
				attribute :>> targetFlowRate = 100.0 [L/min];
				attribute :>> targetPressure = 5.5 [bar];
				attribute :>> controlMode = ControlMode::constantFlow;
			}
			
			flow of fluid : Fluid
				from sourceReservoir.outletPort.fluid
				to suctionPipe.inlet.fluid;
			
			flow of fluid : Fluid
				from suctionPipe.outlet.fluid
				to suctionValve.inlet.fluid;
			
			flow of fluid : Fluid
				from suctionValve.outlet.fluid
				to inletFlowSensor.measurementPort.fluid;
			
			flow of fluid : Fluid
				from inletFlowSensor.measurementPort.fluid
				to downtonPump.inletPort.fluid;
			
			flow of fluid : Fluid
				from downtonPump.outletPort.fluid
				to dischargePipe.inlet.fluid;
			
			flow of fluid : Fluid
				from dischargePipe.outlet.fluid
				to outletPressureSensor.measurementPort.fluid;
			
			flow of fluid : Fluid
				from outletPressureSensor.measurementPort.fluid
				to outletFlowSensor.measurementPort.fluid;
			
			flow of fluid : Fluid
				from outletFlowSensor.measurementPort.fluid
				to dischargeValve.inlet.fluid;
			
			flow of fluid : Fluid
				from dischargeValve.outlet.fluid
				to destinationVessel.inletPort.fluid;
			
			connect controller.controlOut to downtonPump.controlPort;
			connect controller.flowSensorIn to outletFlowSensor.dataPort;
			connect controller.pressureSensorIn to outletPressureSensor.dataPort;
			connect controller.powerControl to downtonPump.powerPort;
		}
		
		requirement systemRequirements : Requirements::PumpingSystemRequirements {
			subject system = pumpingSubsystem;
		}
		
		satisfy systemRequirements by pumpingSubsystem;
	}
}
