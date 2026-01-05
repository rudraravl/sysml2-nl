package 'Gasoline Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		attribute def VolumeValue :> Real;
		
		attribute def PressureValue :> Real;
		
		attribute def FlowRateValue :> Real;
		
		attribute def PowerValue :> Real;
		
		attribute def TemperatureValue :> Real;
		
		enum def PumpOperatingState {
			enum stopped;
			enum priming;
			enum running;
			enum faulted;
		}
		
		item def Gasoline {
			attribute density : Real = 750.0;
			attribute octaneRating : Real = 87.0;
			attribute volume : VolumeValue;
			attribute temperature : TemperatureValue;
		}
		
		port def FluidPort {
			attribute pressure : PressureValue;
			attribute flowRate : FlowRateValue;
			out item fluid : Gasoline;
		}
		
		port def ElectricalPort {
			attribute voltage : Real;
			attribute current : Real;
			in item power : PowerValue;
		}
		
		port def ControlPort {
			in attribute startCommand : Boolean;
			in attribute stopCommand : Boolean;
			out attribute currentState : PumpOperatingState;
			out attribute alarmStatus : Boolean;
		}
		
		part def Motor {
			port powerInput : ~ElectricalPort;
			attribute ratedPower : PowerValue;
			attribute efficiency : Real = 0.88;
			attribute rotationalSpeed : Real;
			
			perform action operateMotor {
				in electricalPower : PowerValue = powerInput.power;
				out mechanicalPower : PowerValue = electricalPower * efficiency;
				out speed : Real = rotationalSpeed;
			}
		}
		
		part def Impeller {
			attribute diameter : Real = 0.12;
			attribute bladeCount : Integer = 8;
			attribute maxSpeed : Real = 3600.0;
			
			perform action generatePressure {
				in mechanicalPower : PowerValue;
				in speed : Real;
				in inletFluid : Gasoline;
				out pressureRise : PressureValue;
				out outletFluid : Gasoline = inletFluid;
			}
		}
		
		part def GasolinePump {
			port fluidInlet : ~FluidPort;
			port fluidOutlet : FluidPort;
			port electricalConnection : ~ElectricalPort;
			port controlInterface : ControlPort;
			
			attribute maxFlowRate : FlowRateValue = 60.0;
			attribute maxPressure : PressureValue = 5.0;
			attribute operatingState : PumpOperatingState = PumpOperatingState::stopped;
			
			part drivingMotor : Motor {
				attribute :>> ratedPower : PowerValue = 1100.0;
				attribute :>> rotationalSpeed = 3450.0;
			}
			
			part pumpingImpeller : Impeller {
				attribute :>> diameter = 0.12;
				attribute :>> bladeCount = 8;
			}
			
			part casingAssembly {
				part inletSection {
					port inletConnection : ~FluidPort;
				}
				part dischargeSection {
					port dischargeConnection : FluidPort;
				}
				part sealingSystem {
					attribute sealCondition : Boolean = true;
				}
			}
			
			part instrumentationPackage {
				attribute inletPressureSensor : PressureValue;
				attribute dischargePressureSensor : PressureValue;
				attribute flowMeter : FlowRateValue;
				attribute motorTemperatureSensor : TemperatureValue;
				attribute vibrationSensor : Real;
			}
			
			bind fluidInlet = casingAssembly.inletSection.inletConnection;
			bind fluidOutlet = casingAssembly.dischargeSection.dischargeConnection;
			bind electricalConnection = drivingMotor.powerInput;
			
			state pumpStateMachine {
				entry; then stoppedState;
				
				state stoppedState {
					entry assign operatingState = PumpOperatingState::stopped;
					entry assign controlInterface.currentState = PumpOperatingState::stopped;
				}
				
				transition stopped_to_priming
					first stoppedState
					accept controlInterface.startCommand == true
					then primingState;
				
				state primingState {
					entry assign operatingState = PumpOperatingState::priming;
					entry assign controlInterface.currentState = PumpOperatingState::priming;
				}
				
				transition priming_to_running
					first primingState
					accept instrumentationPackage.inletPressureSensor > 0.5
					then runningState;
				
				transition priming_to_faulted
					first primingState
					accept instrumentationPackage.inletPressureSensor <= 0.5
					then faultedState;
				
				state runningState {
					entry assign operatingState = PumpOperatingState::running;
					entry assign controlInterface.currentState = PumpOperatingState::running;
				}
				
				transition running_to_stopped
					first runningState
					accept controlInterface.stopCommand == true
					then stoppedState;
				
				transition running_to_faulted
					first runningState
					accept casingAssembly.sealingSystem.sealCondition == false ||
					       instrumentationPackage.motorTemperatureSensor > 120.0
					then faultedState;
				
				state faultedState {
					entry assign operatingState = PumpOperatingState::faulted;
					entry assign controlInterface.currentState = PumpOperatingState::faulted;
					entry assign controlInterface.alarmStatus = true;
				}
				
				transition faulted_to_stopped
					first faultedState
					accept controlInterface.stopCommand == true
					then stoppedState;
			}
		}
		
		part def SupplyTank {
			port fluidDischarge : FluidPort;
			attribute tankCapacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			item storedGasoline : Gasoline {
				attribute :>> volume = currentLevel;
			}
		}
		
		part def ReceivingVessel {
			port fluidReceiving : ~FluidPort;
			attribute vesselCapacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			item receivedGasoline : Gasoline {
				attribute :>> volume = currentLevel;
			}
		}
		
		part def Piping {
			port inlet : ~FluidPort;
			port outlet : FluidPort;
			attribute pipeLength : Real;
			attribute pipeDiameter : Real;
			attribute frictionLoss : PressureValue;
		}
		
		part def ElectricalSupply {
			port powerOutput : ElectricalPort;
			attribute supplyVoltage : Real = 480.0;
			attribute maxCurrentCapacity : Real = 30.0;
			attribute availablePower : PowerValue = supplyVoltage * maxCurrentCapacity;
		}
		
		part def ControlSystem {
			port pumpControl : ~ControlPort;
			attribute operationMode : PumpOperatingState;
			attribute autoShutdownEnabled : Boolean = true;
			
			perform action managePump {
				out startSignal : Boolean;
				out stopSignal : Boolean;
				in pumpStatus : PumpOperatingState = pumpControl.currentState;
				in alarmCondition : Boolean = pumpControl.alarmStatus;
			}
		}
	}
	
	package Requirements {
		requirement def PumpingSubsystemRequirements {
			doc /* The gasoline pumping subsystem shall reliably transfer gasoline 
			       from a supply tank to a receiving vessel under controlled conditions. */
			
			requirement minimumFlowCapability {
				doc /* The pump shall deliver gasoline at a minimum flow rate of 50 liters per minute. */
				subject pump : Definitions::GasolinePump;
				require constraint {
					pump.maxFlowRate >= 50.0
				}
			}
			
			requirement pressureGeneration {
				doc /* The pump shall generate a minimum discharge pressure of 4.0 bar. */
				subject pump : Definitions::GasolinePump;
				require constraint {
					pump.maxPressure >= 4.0
				}
			}
			
			requirement safetyShutdown {
				doc /* The pump shall automatically enter faulted state if seal integrity is lost. */
				subject pump : Definitions::GasolinePump;
				require constraint {
					!pump.casingAssembly.sealingSystem.sealCondition implies 
					pump.operatingState == Definitions::PumpOperatingState::faulted
				}
			}
			
			requirement primingVerification {
				doc /* The pump shall verify adequate inlet pressure before transitioning to running state. */
				subject pump : Definitions::GasolinePump;
				require constraint {
					pump.operatingState == Definitions::PumpOperatingState::running implies
					pump.instrumentationPackage.inletPressureSensor > 0.5
				}
			}
			
			requirement thermalProtection {
				doc /* The pump shall fault if motor temperature exceeds 120 degrees Celsius. */
				subject pump : Definitions::GasolinePump;
				require constraint {
					pump.instrumentationPackage.motorTemperatureSensor > 120.0 implies
					pump.operatingState == Definitions::PumpOperatingState::faulted
				}
			}
		}
	}
	
	package Usages {
		part gasolinePumpingSubsystem {
			part supplyTank : Definitions::SupplyTank {
				attribute :>> tankCapacity : Definitions::VolumeValue = 10000.0;
				attribute :>> currentLevel : Definitions::VolumeValue = 8500.0;
			}
			
			part suctionPiping : Definitions::Piping {
				attribute :>> pipeLength = 3.0;
				attribute :>> pipeDiameter = 0.075;
				attribute :>> frictionLoss : Definitions::PressureValue = 0.15;
			}
			
			part transferPump : Definitions::GasolinePump {
				attribute :>> maxFlowRate : Definitions::FlowRateValue = 80.0;
				attribute :>> maxPressure : Definitions::PressureValue = 6.0;
			}
			
			part dischargePiping : Definitions::Piping {
				attribute :>> pipeLength = 8.0;
				attribute :>> pipeDiameter = 0.075;
				attribute :>> frictionLoss : Definitions::PressureValue = 0.35;
			}
			
			part receivingVessel : Definitions::ReceivingVessel {
				attribute :>> vesselCapacity : Definitions::VolumeValue = 2000.0;
				attribute :>> currentLevel : Definitions::VolumeValue = 500.0;
			}
			
			part electricalSupply : Definitions::ElectricalSupply {
				attribute :>> supplyVoltage = 480.0;
				attribute :>> maxCurrentCapacity = 35.0;
			}
			
			part controlSystem : Definitions::ControlSystem {
				attribute :>> operationMode = Definitions::PumpOperatingState::running;
				attribute :>> autoShutdownEnabled = true;
			}
			
			flow of gasoline : Definitions::Gasoline
				from supplyTank.fluidDischarge.fluid 
				to suctionPiping.inlet.fluid;
			
			flow of gasoline : Definitions::Gasoline
				from suctionPiping.outlet.fluid 
				to transferPump.fluidInlet.fluid;
			
			flow of gasoline : Definitions::Gasoline
				from transferPump.fluidOutlet.fluid 
				to dischargePiping.inlet.fluid;
			
			flow of gasoline : Definitions::Gasoline
				from dischargePiping.outlet.fluid 
				to receivingVessel.fluidReceiving.fluid;
			
			bind electricalSupply.powerOutput = transferPump.electricalConnection;
			bind controlSystem.pumpControl = transferPump.controlInterface;
			
			satisfy Requirements::PumpingSubsystemRequirements by gasolinePumpingSubsystem;
		}
	}
}
