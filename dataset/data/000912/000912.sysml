package 'Marine Pumping Subsystem' {
	private import ScalarValues::*;
	
	package Domain {
		attribute def VolumeUnit;
		attribute def PressureUnit;
		attribute def FlowRateUnit;
		attribute def PowerUnit;
		attribute def TemperatureUnit;
		
		value def VolumeValue :> Real;
		
		value def PressureValue :> Real;
		
		value def FlowRateValue :> Real;
		
		value def PowerValue :> Real;
		
		value def TemperatureValue :> Real;
		
		item def SeaWater {
			attribute salinity : Real;
			attribute temperature : TemperatureValue;
			attribute density : Real;
			attribute volume : VolumeValue;
		}
		
		enum def PumpStatus {
			enum stopped;
			enum priming;
			enum running;
			enum faulted;
		}
		
		enum def OperatingMode {
			enum manual;
			enum automatic;
		}
	}
	
	package Definitions {
		private import Domain::*;
		
		port def FluidInletPort {
			in item fluidIn : SeaWater;
			attribute inletPressure : PressureValue;
		}
		
		port def FluidOutletPort {
			out item fluidOut : SeaWater;
			attribute outletPressure : PressureValue;
		}
		
		port def PowerInputPort {
			in attribute voltage : Real;
			in attribute current : Real;
		}
		
		port def ControlPort {
			in attribute speedCommand : Real;
			out attribute actualSpeed : Real;
			out attribute status : PumpStatus;
		}
		
		action def PumpFluid {
			in fluidIn : SeaWater;
			out fluidOut : SeaWater;
			attribute pressureIncrease : PressureValue;
			attribute flowRate : FlowRateValue;
		}
		
		action def PrimeSystem {
			in initialFluid : SeaWater;
			out primedFluid : SeaWater;
		}
		
		part def MarinePump {
			port suctionPort : FluidInletPort;
			port dischargePort : FluidOutletPort;
			port powerPort : PowerInputPort;
			port controlPort : ControlPort;
			
			attribute ratedFlowRate : FlowRateValue;
			attribute ratedDischargePressure : PressureValue;
			attribute maxSuctionPressure : PressureValue;
			attribute ratedPower : PowerValue;
			attribute efficiency : Real;
			attribute impellerSpeed : Real;
			
			perform action pumpingAction : PumpFluid;
			
			state machine pumpController {
				entry; then idle;
				
				state idle {
					entry action setIdleStatus {
						controlPort.status := PumpStatus::stopped;
						impellerSpeed := 0.0;
					}
				}
				
				transition idleToPriming
					first idle
					accept when controlPort.speedCommand > 0.0
					then priming;
				
				state priming {
					entry action setPrimingStatus {
						controlPort.status := PumpStatus::priming;
					}
					do action primingAction : PrimeSystem {
						in initialFluid = suctionPort.fluidIn;
						out primedFluid = dischargePort.fluidOut;
					}
				}
				
				transition primingToRunning
					first priming
					if suctionPort.inletPressure > -0.5
					then running;
				
				transition primingToFault
					first priming
					if suctionPort.inletPressure < -0.8
					then faulted;
				
				state running {
					entry action setRunningStatus {
						controlPort.status := PumpStatus::running;
					}
					do action pumpingAction {
						in fluidIn = suctionPort.fluidIn;
						out fluidOut = dischargePort.fluidOut;
					}
					
					state normalOperation {
						do action updateSpeed {
							impellerSpeed := controlPort.speedCommand;
							controlPort.actualSpeed := impellerSpeed;
						}
					}
					
					state highPressureOperation;
					
					transition normalToHighPressure
						first normalOperation
						if dischargePort.outletPressure > ratedDischargePressure * 1.15
						then highPressureOperation;
					
					transition highPressureToNormal
						first highPressureOperation
						if dischargePort.outletPressure <= ratedDischargePressure * 1.05
						then normalOperation;
				}
				
				transition runningToIdle
					first running
					accept when controlPort.speedCommand == 0.0
					then idle;
				
				transition runningToFault
					first running
					if dischargePort.outletPressure > ratedDischargePressure * 1.5 or
					   suctionPort.inletPressure < maxSuctionPressure
					then faulted;
				
				state faulted {
					entry action setFaultStatus {
						controlPort.status := PumpStatus::faulted;
						impellerSpeed := 0.0;
					}
				}
				
				transition faultToIdle
					first faulted
					accept when controlPort.speedCommand == 0.0
					then idle;
			}
		}
		
		part def SuctionTank {
			port outletPort : FluidOutletPort;
			
			attribute capacity : VolumeValue;
			attribute currentLevel : Real;
			
			item storedFluid : SeaWater {
				attribute :>> volume;
			}
		}
		
		part def DischargeManifold {
			port inletPort : FluidInletPort;
			
			attribute systemPressure : PressureValue;
			attribute requiredFlowRate : FlowRateValue;
		}
		
		part def ElectricalPowerSupply {
			port powerOutput : ~PowerInputPort;
			
			attribute nominalVoltage : Real;
			attribute nominalFrequency : Real;
			attribute maxCurrent : Real;
		}
		
		part def PumpController {
			port pumpControl : ~ControlPort;
			
			attribute operatingMode : OperatingMode;
			attribute targetSpeed : Real;
			attribute flowSetpoint : FlowRateValue;
			
			perform action controlSpeed {
				in desiredFlow : FlowRateValue;
				out speedOutput : Real;
				in feedbackSpeed : Real;
			}
		}
		
		part def SuctionStrainer {
			port inletPort : FluidInletPort;
			port outletPort : FluidOutletPort;
			
			attribute meshSize : Real;
			attribute pressureDrop : PressureValue;
		}
		
		part def DischargeCheckValve {
			port inletPort : FluidInletPort;
			port outletPort : FluidOutletPort;
			
			attribute crackingPressure : PressureValue;
		}
	}
	
	package Requirements {
		private import Definitions::*;
		
		requirement def FlowRateRequirement {
			doc /* The pumping subsystem shall deliver a minimum flow rate of 150 cubic meters per hour at rated conditions. */
			
			subject pump : MarinePump;
			
			require minFlowRate {
				assert constraint {
					pump.ratedFlowRate >= 150.0
				}
			}
		}
		
		requirement def PressureRequirement {
			doc /* The pumping subsystem shall maintain discharge pressure between 4.0 and 7.0 bar during normal operation. */
			
			subject pump : MarinePump;
			
			require pressureRange {
				assert constraint {
					pump.dischargePort.outletPressure >= 4.0 and
					pump.dischargePort.outletPressure <= 7.0
				}
			}
		}
		
		requirement def SuctionRequirement {
			doc /* The pump shall operate with suction pressure not exceeding -0.7 bar to prevent cavitation. */
			
			subject pump : MarinePump;
			
			require maxSuction {
				assert constraint {
					pump.suctionPort.inletPressure >= -0.7
				}
			}
		}
		
		requirement def EfficiencyRequirement {
			doc /* The marine pump shall achieve minimum 78% efficiency at rated operating point. */
			
			subject pump : MarinePump;
			
			require minEfficiency {
				assert constraint {
					pump.efficiency >= 0.78
				}
			}
		}
		
		requirement def ReliabilityRequirement {
			doc /* The pumping subsystem shall operate continuously for 10000 hours between scheduled maintenance. */
		}
	}
	
	package Assembly {
		private import Definitions::*;
		private import Domain::*;
		private import Requirements::*;
		
		part marinePumpingSubsystem {
			
			part suctionTank : SuctionTank {
				attribute :>> capacity = 8000.0;
				attribute :>> currentLevel = 0.75;
				
				item :>> storedFluid {
					attribute :>> salinity = 35.0;
					attribute :>> temperature = 18.0;
					attribute :>> density = 1025.0;
					attribute :>> volume = 6000.0;
				}
			}
			
			part suctionStrainer : SuctionStrainer {
				attribute :>> meshSize = 3.0;
				attribute :>> pressureDrop = 0.05;
			}
			
			flow of seaWater : SeaWater
				from suctionTank.outletPort.fluidOut
				to suctionStrainer.inletPort.fluidIn;
			
			connect suctionTank.outletPort to suctionStrainer.inletPort;
			
			part marinePump : MarinePump {
				attribute :>> ratedFlowRate = 160.0;
				attribute :>> ratedDischargePressure = 5.5;
				attribute :>> maxSuctionPressure = -0.7;
				attribute :>> ratedPower = 30.0;
				attribute :>> efficiency = 0.80;
				attribute :>> impellerSpeed = 0.0;
				
				perform action :>> pumpingAction {
					in :>> fluidIn = suctionPort.fluidIn;
					out :>> fluidOut = dischargePort.fluidOut;
				}
			}
			
			flow of seaWater : SeaWater
				from suctionStrainer.outletPort.fluidOut
				to marinePump.suctionPort.fluidIn;
			
			connect suctionStrainer.outletPort to marinePump.suctionPort;
			
			part dischargeCheckValve : DischargeCheckValve {
				attribute :>> crackingPressure = 0.3;
			}
			
			flow of seaWater : SeaWater
				from marinePump.dischargePort.fluidOut
				to dischargeCheckValve.inletPort.fluidIn;
			
			connect marinePump.dischargePort to dischargeCheckValve.inletPort;
			
			part dischargeManifold : DischargeManifold {
				attribute :>> systemPressure = 5.0;
				attribute :>> requiredFlowRate = 150.0;
			}
			
			flow of seaWater : SeaWater
				from dischargeCheckValve.outletPort.fluidOut
				to dischargeManifold.inletPort.fluidIn;
			
			connect dischargeCheckValve.outletPort to dischargeManifold.inletPort;
			
			part powerSupply : ElectricalPowerSupply {
				attribute :>> nominalVoltage = 480.0;
				attribute :>> nominalFrequency = 60.0;
				attribute :>> maxCurrent = 50.0;
			}
			
			connect powerSupply.powerOutput to marinePump.powerPort;
			
			part controller : PumpController {
				attribute :>> operatingMode = OperatingMode::automatic;
				attribute :>> targetSpeed = 1750.0;
				attribute :>> flowSetpoint = 155.0;
				
				perform action :>> controlSpeed {
					in :>> desiredFlow = flowSetpoint;
					out :>> speedOutput = pumpControl.speedCommand;
					in :>> feedbackSpeed = pumpControl.actualSpeed;
				}
			}
			
			connect controller.pumpControl to marinePump.controlPort;
			
			assert constraint flowBalance {
				marinePump.dischargePort.outletPressure ==
					marinePump.suctionPort.inletPressure +
					marinePump.ratedDischargePressure * (marinePump.impellerSpeed / 1750.0) ** 2
			}
			
			assert constraint powerConsumption {
				marinePump.ratedPower ==
					(marinePump.ratedFlowRate * marinePump.ratedDischargePressure) /
					(marinePump.efficiency * 36.0)
			}
		}
		
		requirement flowReq : FlowRateRequirement {
			subject pump = marinePumpingSubsystem.marinePump;
		}
		
		requirement pressureReq : PressureRequirement {
			subject pump = marinePumpingSubsystem.marinePump;
		}
		
		requirement suctionReq : SuctionRequirement {
			subject pump = marinePumpingSubsystem.marinePump;
		}
		
		requirement efficiencyReq : EfficiencyRequirement {
			subject pump = marinePumpingSubsystem.marinePump;
		}
		
		requirement reliabilityReq : ReliabilityRequirement;
		
		satisfy flowReq by marinePumpingSubsystem.marinePump;
		satisfy pressureReq by marinePumpingSubsystem.marinePump;
		satisfy suctionReq by marinePumpingSubsystem.marinePump;
		satisfy efficiencyReq by marinePumpingSubsystem.marinePump;
		satisfy reliabilityReq by marinePumpingSubsystem;
	}
}
