package 'BoilerFeedwaterPumpingSubsystem' {
	private import ScalarValues::*;
	private import SI::*;
	
	package Definitions {
		attribute def PressureValue :> Real;
		attribute def TemperatureValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def PowerValue :> Real;
		attribute def SpeedValue :> Real;
		attribute def LevelValue :> Real;
		
		item def Feedwater {
			attribute pressure : PressureValue;
			attribute temperature : TemperatureValue;
			attribute flowRate : FlowRateValue;
			attribute density : Real;
		}
		
		enum def PumpStatus {
			enum stopped;
			enum starting;
			enum running;
			enum stopping;
			enum tripped;
		}
		
		port def FeedwaterInPort {
			in item feedwaterIn : Feedwater;
		}
		
		port def FeedwaterOutPort {
			out item feedwaterOut : Feedwater;
		}
		
		port def PowerPort {
			in attribute powerSupply : PowerValue;
			in attribute voltage : Real;
			in attribute frequency : Real;
		}
		
		port def ControlPort {
			in attribute startSignal : Boolean;
			in attribute stopSignal : Boolean;
			in attribute speedCommand : SpeedValue;
			out attribute statusFeedback : PumpStatus;
			out attribute currentSpeed : SpeedValue;
		}
		
		part def Deaerator {
			attribute storageLevel : LevelValue;
			attribute operatingPressure : PressureValue;
			attribute operatingTemperature : TemperatureValue;
			attribute storageCapacity : Real;
			
			port feedwaterOutlet : FeedwaterOutPort;
		}
		
		part def SuctionStrainer {
			attribute meshSize : Real;
			attribute pressureDrop : PressureValue;
			
			port inlet : FeedwaterInPort;
			port outlet : FeedwaterOutPort;
		}
		
		part def BoilerFeedwaterPump {
			attribute pumpIdentifier : String;
			attribute designFlowRate : FlowRateValue;
			attribute designHead : PressureValue;
			attribute designPower : PowerValue;
			attribute pumpEfficiency : Real;
			attribute currentStatus : PumpStatus;
			attribute operatingSpeed : SpeedValue;
			attribute npshRequired : PressureValue;
			
			port suctionPort : FeedwaterInPort;
			port dischargePort : FeedwaterOutPort;
			port electricalPower : PowerPort;
			port controlInterface : ControlPort;
			
			part motor {
				attribute motorRating : PowerValue;
				attribute motorSpeed : SpeedValue;
				attribute motorEfficiency : Real;
			}
			
			part impeller {
				attribute impellerDiameter : Real;
				attribute numberOfVanes : Integer;
			}
			
			part casing {
				attribute pressureRating : PressureValue;
				attribute material : String;
			}
			
			part mechanicalSeal {
				attribute sealType : String;
				attribute flushingRequired : Boolean;
			}
		}
		
		part def CheckValve {
			attribute valveSize : Real;
			attribute crackingPressure : PressureValue;
			
			port inlet : FeedwaterInPort;
			port outlet : FeedwaterOutPort;
		}
		
		part def ControlValve {
			attribute valveSize : Real;
			attribute valvePosition : Real;
			attribute cvCoefficient : Real;
			
			port inlet : FeedwaterInPort;
			port outlet : FeedwaterOutPort;
		}
		
		part def Boiler {
			attribute drumPressure : PressureValue;
			attribute drumLevel : LevelValue;
			attribute steamDemand : FlowRateValue;
			
			port feedwaterInlet : FeedwaterInPort;
		}
		
		part def FlowTransmitter {
			attribute measuredFlow : FlowRateValue;
			attribute accuracy : Real;
			attribute rangeMin : FlowRateValue;
			attribute rangeMax : FlowRateValue;
		}
		
		part def PressureTransmitter {
			attribute measuredPressure : PressureValue;
			attribute accuracy : Real;
			attribute rangeMin : PressureValue;
			attribute rangeMax : PressureValue;
		}
		
		action def StartPumpSequence {
			in targetPump : BoilerFeedwaterPump;
			out startSuccess : Boolean;
			
			first start;
			then action verifyConditions {
				doc /* Check suction pressure, motor ready, no faults */
			}
			then action energizeMotor;
			then action rampUpSpeed;
			then action confirmRunning;
			then done;
		}
		
		action def StopPumpSequence {
			in targetPump : BoilerFeedwaterPump;
			out stopSuccess : Boolean;
			
			first start;
			then action rampDownSpeed;
			then action deenergizeMotor;
			then action confirmStopped;
			then done;
		}
		
		action def PumpFeedwater {
			in feedwaterIn : Feedwater;
			out feedwaterOut : Feedwater;
			
			first start;
			then action drawSuction {
				in suction = feedwaterIn;
				out suctionFlow : Feedwater;
			}
			then action increaseHead {
				in incomingFlow = drawSuction.suctionFlow;
				out pressurizedFlow : Feedwater {
					attribute pressure : PressureValue = incomingFlow.pressure + 12000000.0;
					attribute temperature : TemperatureValue = incomingFlow.temperature + 2.0;
					attribute flowRate : FlowRateValue = incomingFlow.flowRate;
					attribute density : Real = incomingFlow.density;
				}
			}
			then action discharge {
				in dischargeFlow = increaseHead.pressurizedFlow;
				out delivered = dischargeFlow;
			}
			then done;
		}
		
		state def PumpControlStateMachine {
			in attribute startCmd : Boolean;
			in attribute stopCmd : Boolean;
			in attribute resetCmd : Boolean;
			in attribute currentSpd : SpeedValue;
			in attribute targetSpd : SpeedValue;
			in attribute faultDetected : Boolean;
			in attribute faultCleared : Boolean;
			out attribute status : PumpStatus;
			
			entry; then idle;
			
			state idle;
			
			transition idleToStarting
				first idle
				accept startCmd
				if startCmd
				then starting;
			
			state starting;
			
			transition startingToRunning
				first starting
				if currentSpd >= 0.95 * targetSpd
				then running;
			
			state running;
			
			transition runningToStopping
				first running
				accept stopCmd
				if stopCmd
				then stopping;
			
			transition runningToTripped
				first running
				if faultDetected
				then tripped;
			
			state stopping;
			
			transition stoppingToIdle
				first stopping
				if currentSpd <= 0.0
				then idle;
			
			state tripped;
			
			transition trippedToIdle
				first tripped
				accept resetCmd
				if faultCleared
				then idle;
		}
		
		requirement def FlowCapacityRequirement {
			subject pump : BoilerFeedwaterPump;
			
			doc /* The pump shall deliver feedwater at the design flow rate 
			     * under normal operating conditions. */
			
			require constraint {
				pump.designFlowRate >= 150.0 and pump.designFlowRate <= 500.0
			}
		}
		
		requirement def PressureRiseRequirement {
			subject pump : BoilerFeedwaterPump;
			
			doc /* The pump shall develop sufficient head to overcome boiler 
			     * drum pressure plus piping losses. */
			
			require constraint {
				pump.designHead >= 10000000.0
			}
		}
		
		requirement def EfficiencyRequirement {
			subject pump : BoilerFeedwaterPump;
			
			doc /* The pump shall operate at minimum efficiency to reduce 
			     * energy consumption. */
			
			require constraint {
				pump.pumpEfficiency >= 0.78
			}
		}
		
		requirement def NPSHRequirement {
			subject pump : BoilerFeedwaterPump;
			subject deaerator : Deaerator;
			
			doc /* Net Positive Suction Head Available must exceed NPSH Required 
			     * to prevent cavitation. */
			
			require constraint {
				deaerator.operatingPressure >= pump.npshRequired + 50000.0
			}
		}
		
		requirement def RedundancyRequirement {
			subject system : FeedwaterPumpingSystem;
			
			doc /* The system shall provide redundant pumps to ensure continuous 
			     * feedwater supply during maintenance or failure. */
			
			require constraint {
				system.numberOfPumps >= 2
			}
		}
	}
	
	package Usages {
		part feedwaterSystem : FeedwaterPumpingSystem {
			attribute numberOfPumps : Integer = 2;
			
			part deaeratorTank : Deaerator {
				attribute :>> storageLevel = 2.5;
				attribute :>> operatingPressure = 250000.0;
				attribute :>> operatingTemperature = 378.0;
				attribute :>> storageCapacity = 50.0;
			}
			
			part suctionStrainerA : SuctionStrainer {
				attribute :>> meshSize = 0.003;
				attribute :>> pressureDrop = 5000.0;
			}
			
			flow of feedwater : Feedwater
				from deaeratorTank.feedwaterOutlet.feedwaterOut
				to suctionStrainerA.inlet.feedwaterIn;
			
			part pumpA : BoilerFeedwaterPump {
				attribute :>> pumpIdentifier = "BFP-A";
				attribute :>> designFlowRate = 250.0;
				attribute :>> designHead = 12000000.0;
				attribute :>> designPower = 1500000.0;
				attribute :>> pumpEfficiency = 0.82;
				attribute :>> currentStatus = PumpStatus::stopped;
				attribute :>> operatingSpeed = 0.0;
				attribute :>> npshRequired = 150000.0;
				
				part :>> motor {
					attribute :>> motorRating = 1600000.0;
					attribute :>> motorSpeed = 3600.0;
					attribute :>> motorEfficiency = 0.95;
				}
				
				part :>> impeller {
					attribute :>> impellerDiameter = 0.45;
					attribute :>> numberOfVanes = 7;
				}
				
				part :>> casing {
					attribute :>> pressureRating = 15000000.0;
					attribute :>> material = "Stainless Steel 316";
				}
				
				part :>> mechanicalSeal {
					attribute :>> sealType = "Cartridge Type";
					attribute :>> flushingRequired = true;
				}
				
				perform action pumpingAction : PumpFeedwater {
					in feedwaterIn = suctionPort.feedwaterIn;
					out feedwaterOut = dischargePort.feedwaterOut;
				}
			}
			
			flow of feedwater : Feedwater
				from suctionStrainerA.outlet.feedwaterOut
				to pumpA.suctionPort.feedwaterIn;
			
			part checkValveA : CheckValve {
				attribute :>> valveSize = 0.25;
				attribute :>> crackingPressure = 50000.0;
			}
			
			flow of feedwater : Feedwater
				from pumpA.dischargePort.feedwaterOut
				to checkValveA.inlet.feedwaterIn;
			
			part suctionStrainerB : SuctionStrainer {
				attribute :>> meshSize = 0.003;
				attribute :>> pressureDrop = 5000.0;
			}
			
			flow of feedwater : Feedwater
				from deaeratorTank.feedwaterOutlet.feedwaterOut
				to suctionStrainerB.inlet.feedwaterIn;
			
			part pumpB : BoilerFeedwaterPump {
				attribute :>> pumpIdentifier = "BFP-B";
				attribute :>> designFlowRate = 250.0;
				attribute :>> designHead = 12000000.0;
				attribute :>> designPower = 1500000.0;
				attribute :>> pumpEfficiency = 0.82;
				attribute :>> currentStatus = PumpStatus::stopped;
				attribute :>> operatingSpeed = 0.0;
				attribute :>> npshRequired = 150000.0;
				
				part :>> motor {
					attribute :>> motorRating = 1600000.0;
					attribute :>> motorSpeed = 3600.0;
					attribute :>> motorEfficiency = 0.95;
				}
				
				part :>> impeller {
					attribute :>> impellerDiameter = 0.45;
					attribute :>> numberOfVanes = 7;
				}
				
				part :>> casing {
					attribute :>> pressureRating = 15000000.0;
					attribute :>> material = "Stainless Steel 316";
				}
				
				part :>> mechanicalSeal {
					attribute :>> sealType = "Cartridge Type";
					attribute :>> flushingRequired = true;
				}
				
				perform action pumpingAction : PumpFeedwater {
					in feedwaterIn = suctionPort.feedwaterIn;
					out feedwaterOut = dischargePort.feedwaterOut;
				}
			}
			
			flow of feedwater : Feedwater
				from suctionStrainerB.outlet.feedwaterOut
				to pumpB.suctionPort.feedwaterIn;
			
			part checkValveB : CheckValve {
				attribute :>> valveSize = 0.25;
				attribute :>> crackingPressure = 50000.0;
			}
			
			flow of feedwater : Feedwater
				from pumpB.dischargePort.feedwaterOut
				to checkValveB.inlet.feedwaterIn;
			
			part flowControlValve : ControlValve {
				attribute :>> valveSize = 0.30;
				attribute :>> valvePosition = 0.65;
				attribute :>> cvCoefficient = 120.0;
			}
			
			flow of feedwater : Feedwater
				from checkValveA.outlet.feedwaterOut
				to flowControlValve.inlet.feedwaterIn;
			
			flow of feedwater : Feedwater
				from checkValveB.outlet.feedwaterOut
				to flowControlValve.inlet.feedwaterIn;
			
			part steamBoiler : Boiler {
				attribute :>> drumPressure = 10500000.0;
				attribute :>> drumLevel = 1.8;
				attribute :>> steamDemand = 200.0;
			}
			
			flow of feedwater : Feedwater
				from flowControlValve.outlet.feedwaterOut
				to steamBoiler.feedwaterInlet.feedwaterIn;
			
			part dischargeFlowMeter : FlowTransmitter {
				attribute :>> accuracy = 0.5;
				attribute :>> rangeMin = 0.0;
				attribute :>> rangeMax = 600.0;
			}
			
			part dischargePressureMeter : PressureTransmitter {
				attribute :>> accuracy = 0.25;
				attribute :>> rangeMin = 0.0;
				attribute :>> rangeMax = 15000000.0;
			}
			
			perform action startPumpA : StartPumpSequence {
				in targetPump = pumpA;
			}
			
			perform action stopPumpA : StopPumpSequence {
				in targetPump = pumpA;
			}
			
			satisfy flowReqA : FlowCapacityRequirement {
				subject pump = pumpA;
			}
			
			satisfy pressureReqA : PressureRiseRequirement {
				subject pump = pumpA;
			}
			
			satisfy efficiencyReqA : EfficiencyRequirement {
				subject pump = pumpA;
			}
			
			satisfy npshReqA : NPSHRequirement {
				subject pump = pumpA;
				subject deaerator = deaeratorTank;
			}
			
			satisfy redundancyReq : RedundancyRequirement {
				subject system = feedwaterSystem;
			}
		}
		
		part def FeedwaterPumpingSystem {
			attribute numberOfPumps : Integer;
			part deaeratorTank : Deaerator;
			part suctionStrainerA : SuctionStrainer;
			part pumpA : BoilerFeedwaterPump;
			part checkValveA : CheckValve;
			part suctionStrainerB : SuctionStrainer;
			part pumpB : BoilerFeedwaterPump;
			part checkValveB : CheckValve;
			part flowControlValve : ControlValve;
			part steamBoiler : Boiler;
			part dischargeFlowMeter : FlowTransmitter;
			part dischargePressureMeter : PressureTransmitter;
		}
	}
}
