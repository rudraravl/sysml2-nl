package 'Slurry Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Slurry {
			attribute density : Real;
			attribute viscosity : Real;
			attribute solidContent : Real;
			attribute temperature : Real;
			attribute volume : Real;
		}
		
		port def SlurryInletPort {
			in item slurryIn : Slurry;
			attribute inletPressure : Real;
			attribute flowRate : Real;
		}
		
		port def SlurryOutletPort {
			out item slurryOut : Slurry;
			attribute outletPressure : Real;
			attribute flowRate : Real;
		}
		
		port def PowerPort {
			in attribute electricalPower : Real;
			attribute voltage : Real;
			attribute current : Real;
		}
		
		port def ControlPort {
			in attribute commandedSpeed : Real;
			out attribute actualSpeed : Real;
			out attribute operatingStatus : OperatingStatus;
		}
		
		enum def OperatingStatus {
			enum stopped;
			enum starting;
			enum running;
			enum stopping;
			enum faulted;
		}
		
		part def SlurryPump {
			port inletPort : SlurryInletPort;
			port outletPort : SlurryOutletPort;
			port powerPort : PowerPort;
			port controlPort : ControlPort;
			
			attribute ratedFlowRate : Real;
			attribute ratedHead : Real;
			attribute ratedPower : Real;
			attribute efficiency : Real;
			attribute impellerDiameter : Real;
			attribute maxSolidContent : Real;
			attribute operatingHours : Real;
			
			perform action pumpOperation : PumpSlurry {
				in slurryIn = inletPort.slurryIn;
				out slurryOut = outletPort.slurryOut;
				in powerIn = powerPort.electricalPower;
				in commandSpeed = controlPort.commandedSpeed;
			}
			
			exhibit state pumpStateMachine : SlurryPumpStateMachine;
		}
		
		part def SourceTank {
			port outletPort : SlurryOutletPort;
			
			attribute capacity : Real;
			attribute currentLevel : Real;
			
			item storedSlurry : Slurry {
				attribute :>> volume;
			}
		}
		
		part def DestinationTank {
			port inletPort : SlurryInletPort;
			
			attribute capacity : Real;
			attribute currentLevel : Real;
			
			item storedSlurry : Slurry {
				attribute :>> volume;
			}
		}
		
		part def PipingSection {
			port inPort : SlurryInletPort;
			port outPort : SlurryOutletPort;
			
			attribute length : Real;
			attribute diameter : Real;
			attribute material : String;
			attribute roughness : Real;
		}
		
		part def FlowMeter {
			port inPort : SlurryInletPort;
			port outPort : SlurryOutletPort;
			
			attribute measuredFlowRate : Real;
			attribute accuracy : Real;
		}
		
		part def PressureSensor {
			attribute measuredPressure : Real;
			attribute accuracy : Real;
		}
		
		part def MotorController {
			port controlPort : ControlPort;
			port powerInPort : PowerPort;
			port powerOutPort : PowerPort;
			
			attribute maxOutputPower : Real;
			attribute controlMode : String;
		}
		
		part def PowerSupply {
			port powerOutPort : PowerPort;
			
			attribute ratedVoltage : Real;
			attribute ratedCurrent : Real;
			attribute frequency : Real;
		}
		
		action def PumpSlurry {
			in slurryIn : Slurry;
			out slurryOut : Slurry;
			in powerIn : Real;
			in commandSpeed : Real;
			
			action calculateFlowRate {
				in speed : Real = commandSpeed;
				out flowRate : Real;
			}
			
			action transferSlurry {
				in slurry : Slurry = slurryIn;
				in flow : Real = calculateFlowRate.flowRate;
				out transferredSlurry : Slurry = slurryOut;
			}
			
			first start;
			then calculateFlowRate;
			then transferSlurry;
			then done;
		}
		
		state def SlurryPumpStateMachine {
			entry; then idle;
			
			state idle;
			
			transition idle_to_starting
				first idle
				accept StartCommand
				then starting;
			
			state starting;
			
			transition starting_to_running
				first starting
				if true
				then running;
			
			state running;
			
			transition running_to_stopping
				first running
				accept StopCommand
				then stopping;
			
			transition running_to_faulted
				first running
				accept FaultDetected
				then faulted;
			
			state stopping;
			
			transition stopping_to_idle
				first stopping
				if true
				then idle;
			
			state faulted;
			
			transition faulted_to_idle
				first faulted
				accept ResetCommand
				then idle;
		}
		
		interface def SlurryFlowInterface {
			end port source : SlurryOutletPort;
			end port destination : SlurryInletPort;
			
			connect source.slurryOut to destination.slurryIn;
		}
		
		interface def PowerInterface {
			end port supply : PowerPort;
			end port load : PowerPort;
		}
	}
	
	package Usages {
		part slurryPumpingSystem {
			part sourceTank : SourceTank {
				attribute :>> capacity = 50.0;
				attribute :>> currentLevel = 0.75;
				
				item :>> storedSlurry {
					attribute :>> density = 1450.0;
					attribute :>> viscosity = 0.05;
					attribute :>> solidContent = 0.35;
					attribute :>> temperature = 298.15;
					attribute :>> volume = sourceTank.capacity * sourceTank.currentLevel;
				}
			}
			
			part suctionPiping : PipingSection {
				attribute :>> length = 15.0;
				attribute :>> diameter = 0.3;
				attribute :>> material = "Hardened Steel";
				attribute :>> roughness = 0.00015;
			}
			
			part suctionFlowMeter : FlowMeter {
				attribute :>> accuracy = 0.02;
			}
			
			part suctionPressureSensor : PressureSensor {
				attribute :>> accuracy = 0.01;
			}
			
			part slurryPump : SlurryPump {
				attribute :>> ratedFlowRate = 200.0;
				attribute :>> ratedHead = 50.0;
				attribute :>> ratedPower = 75.0;
				attribute :>> efficiency = 0.72;
				attribute :>> impellerDiameter = 0.45;
				attribute :>> maxSolidContent = 0.45;
				attribute :>> operatingHours = 0.0;
			}
			
			part dischargePiping : PipingSection {
				attribute :>> length = 25.0;
				attribute :>> diameter = 0.25;
				attribute :>> material = "Hardened Steel";
				attribute :>> roughness = 0.00015;
			}
			
			part dischargeFlowMeter : FlowMeter {
				attribute :>> accuracy = 0.02;
			}
			
			part dischargePressureSensor : PressureSensor {
				attribute :>> accuracy = 0.01;
			}
			
			part destinationTank : DestinationTank {
				attribute :>> capacity = 75.0;
				attribute :>> currentLevel = 0.25;
				
				item :>> storedSlurry {
					attribute :>> density = 1450.0;
					attribute :>> viscosity = 0.05;
					attribute :>> solidContent = 0.35;
					attribute :>> temperature = 298.15;
					attribute :>> volume = destinationTank.capacity * destinationTank.currentLevel;
				}
			}
			
			part powerSupply : PowerSupply {
				attribute :>> ratedVoltage = 480.0;
				attribute :>> ratedCurrent = 150.0;
				attribute :>> frequency = 60.0;
			}
			
			part motorController : MotorController {
				attribute :>> maxOutputPower = 90.0;
				attribute :>> controlMode = "Variable Frequency Drive";
			}
			
			interface suctionFlow : SlurryFlowInterface 
				connect source ::> sourceTank.outletPort 
				to destination ::> suctionPiping.inPort;
			
			flow of slurry : Slurry 
				from suctionPiping.outPort.slurryOut 
				to suctionFlowMeter.inPort.slurryIn;
			
			flow of slurry : Slurry 
				from suctionFlowMeter.outPort.slurryOut 
				to slurryPump.inletPort.slurryIn;
			
			flow of slurry : Slurry 
				from slurryPump.outletPort.slurryOut 
				to dischargePiping.inPort.slurryIn;
			
			flow of slurry : Slurry 
				from dischargePiping.outPort.slurryOut 
				to dischargeFlowMeter.inPort.slurryIn;
			
			flow of slurry : Slurry 
				from dischargeFlowMeter.outPort.slurryOut 
				to destinationTank.inletPort.slurryIn;
			
			interface powerToController : PowerInterface 
				connect supply ::> powerSupply.powerOutPort 
				to load ::> motorController.powerInPort;
			
			interface powerToPump : PowerInterface 
				connect supply ::> motorController.powerOutPort 
				to load ::> slurryPump.powerPort;
			
			bind suctionPressureSensor.measuredPressure = slurryPump.inletPort.inletPressure;
			bind dischargePressureSensor.measuredPressure = slurryPump.outletPort.outletPressure;
		}
	}
	
	package Requirements {
		requirement pumpingSystemRequirements {
			doc /* The slurry pumping subsystem shall move fluid from source to destination. */
			
			requirement functionalRequirements {
				doc /* Functional requirements for the pumping subsystem. */
				
				requirement flowRateRequirement {
					doc /* The system shall maintain a flow rate of 200 m³/h ± 5%. */
					subject slurryPump : SlurryPump;
					
					require constraint {
						slurryPump.outletPort.flowRate >= 190.0 and
						slurryPump.outletPort.flowRate <= 210.0
					}
				}
				
				requirement headRequirement {
					doc /* The pump shall provide minimum 50 m of head. */
					subject slurryPump : SlurryPump;
					
					require constraint {
						slurryPump.ratedHead >= 50.0
					}
				}
				
				requirement solidContentRequirement {
					doc /* The system shall handle slurry with up to 45% solid content. */
					subject slurryPump : SlurryPump;
					
					require constraint {
						slurryPump.maxSolidContent >= 0.45
					}
				}
			}
			
			requirement performanceRequirements {
				doc /* Performance requirements for the pumping subsystem. */
				
				requirement efficiencyRequirement {
					doc /* The pump shall operate at minimum 70% efficiency. */
					subject slurryPump : SlurryPump;
					
					require constraint {
						slurryPump.efficiency >= 0.70
					}
				}
				
				requirement powerRequirement {
					doc /* The system shall not exceed 90 kW power consumption. */
					subject slurryPump : SlurryPump;
					
					require constraint {
						slurryPump.powerPort.electricalPower <= 90.0
					}
				}
			}
			
			requirement reliabilityRequirements {
				doc /* Reliability requirements for the pumping subsystem. */
				
				requirement continuousOperationRequirement {
					doc /* The system shall operate continuously for 8000 hours between maintenance. */
					subject slurryPump : SlurryPump;
					
					require constraint {
						slurryPump.operatingHours <= 8000.0
					}
				}
			}
			
			requirement safetyRequirements {
				doc /* Safety requirements for the pumping subsystem. */
				
				requirement faultDetectionRequirement {
					doc /* The system shall detect and respond to fault conditions. */
					subject slurryPump : SlurryPump;
					
					require constraint {
						slurryPump.controlPort.operatingStatus == OperatingStatus::faulted implies
						slurryPump.controlPort.actualSpeed == 0.0
					}
				}
			}
		}
	}
}
