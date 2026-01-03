package 'Pulsometer Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		attribute def Pressure :> Real;
		attribute def Temperature :> Real;
		attribute def FlowRate :> Real;
		attribute def Volume :> Real;
		attribute def Time :> Real;
		
		item def Fluid {
			attribute temperature : Temperature;
			attribute pressure : Pressure;
			attribute volume : Volume;
		}
		
		item def Water :> Fluid;
		item def Steam :> Fluid;
		item def Condensate :> Fluid;
		
		port def FluidInPort {
			attribute inletPressure : Pressure;
			in item fluidIn : Fluid;
		}
		
		port def FluidOutPort {
			attribute outletPressure : Pressure;
			out item fluidOut : Fluid;
		}
		
		port def SteamInPort {
			attribute steamPressure : Pressure;
			attribute steamTemperature : Temperature;
			in item steamIn : Steam;
		}
		
		port def CondensateOutPort {
			out item condensateOut : Condensate;
		}
		
		part def CheckValve {
			attribute crackingPressure : Pressure;
			attribute isOpen : Boolean;
			port valveIn : FluidInPort;
			port valveOut : FluidOutPort;
		}
		
		action def ExpelFluid {
			out discharged : Fluid;
		}
		
		action def IntakeFluid {
			in source : Fluid;
		}
		
		part def PulsometerChamber {
			attribute chamberVolume : Volume;
			attribute currentPressure : Pressure;
			attribute fluidLevel : Real;
			attribute isFilling : Boolean;
			attribute isDischarging : Boolean;
			
			port fluidInlet : FluidInPort;
			port fluidOutlet : FluidOutPort;
			port steamInlet : SteamInPort;
			port condensateDrain : CondensateOutPort;
			
			action def ChamberOperation {
				first start;
				then idle;
				
				state idle;
				
				then steamAdmission;
				state steamAdmission {
					entry assign currentPressure = steamInlet.steamPressure;
					entry assign isDischarging = true;
				}
				
				then discharging;
				state discharging {
					do expelFluid : ExpelFluid;
				}
				
				then steamCondensation;
				state steamCondensation {
					entry assign currentPressure = 0.3 * currentPressure;
				}
				
				then filling;
				state filling {
					entry assign isFilling = true;
					do intakeFluid : IntakeFluid;
				}
				
				then idle;
				then done;
			}
			
			perform chamberOp : ChamberOperation;
		}
		
		part def PulsometerPump {
			attribute designFlowRate : FlowRate;
			attribute maxDischargePressure : Pressure;
			attribute cycleTime : Time;
			attribute steamConsumption : FlowRate;
			
			port suctionPort : FluidInPort;
			port dischargePort : FluidOutPort;
			port steamSupplyPort : SteamInPort;
			port condensateReturnPort : CondensateOutPort;
			
			part chamberA : PulsometerChamber {
				attribute :>> chamberVolume = 0.05;
			}
			
			part chamberB : PulsometerChamber {
				attribute :>> chamberVolume = 0.05;
			}
			
			part suctionCheckA : CheckValve;
			part suctionCheckB : CheckValve;
			part dischargeCheckA : CheckValve;
			part dischargeCheckB : CheckValve;
			
			flow from suctionPort.fluidIn to suctionCheckA.valveIn.fluidIn;
			flow from suctionPort.fluidIn to suctionCheckB.valveIn.fluidIn;
			
			flow from suctionCheckA.valveOut.fluidOut to chamberA.fluidInlet.fluidIn;
			flow from suctionCheckB.valveOut.fluidOut to chamberB.fluidInlet.fluidIn;
			
			flow from chamberA.fluidOutlet.fluidOut to dischargeCheckA.valveIn.fluidIn;
			flow from chamberB.fluidOutlet.fluidOut to dischargeCheckB.valveIn.fluidIn;
			
			flow from dischargeCheckA.valveOut.fluidOut to dischargePort.fluidOut;
			flow from dischargeCheckB.valveOut.fluidOut to dischargePort.fluidOut;
			
			flow from steamSupplyPort.steamIn to chamberA.steamInlet.steamIn;
			flow from steamSupplyPort.steamIn to chamberB.steamInlet.steamIn;
			
			flow from chamberA.condensateDrain.condensateOut to condensateReturnPort.condensateOut;
			flow from chamberB.condensateDrain.condensateOut to condensateReturnPort.condensateOut;
			
			action def AlternatingPumpCycle {
				in suctionFluid : Fluid;
				in steamInput : Steam;
				out dischargeFluid : Fluid;
				
				first start;
				then merge cycleControl;
				
				then action operateChamberA {
					action admitSteamA;
					then action dischargeA;
				}
				
				then action operateChamberB {
					action admitSteamB;
					then action dischargeB;
				}
				
				then cycleControl;
				then done;
			}
			
			perform action pumpOperation : AlternatingPumpCycle {
				in suctionFluid = suctionPort.fluidIn;
				in steamInput = steamSupplyPort.steamIn;
				out dischargeFluid = dischargePort.fluidOut;
			}
		}
		
		part def SourceReservoir {
			attribute waterLevel : Real;
			attribute sourcePressure : Pressure;
			port outlet : FluidOutPort;
		}
		
		part def DeliveryTank {
			attribute waterLevel : Real;
			attribute tankPressure : Pressure;
			port inlet : FluidInPort;
		}
		
		part def SteamBoiler {
			attribute boilerPressure : Pressure;
			attribute boilerTemperature : Temperature;
			port steamOutlet : SteamInPort;
		}
		
		part def CondensateTank {
			attribute condensateLevel : Real;
			port condensateInlet : CondensateOutPort;
		}
		
		requirement def FlowCapacityRequirement {
			subject pump : PulsometerPump;
			doc /* The pump shall deliver minimum specified flow rate */
			
			attribute minFlowRate : FlowRate;
			
			require constraint {
				pump.designFlowRate >= minFlowRate
			}
		}
		
		requirement def DischargePressureRequirement {
			subject pump : PulsometerPump;
			doc /* The pump shall achieve required discharge pressure */
			
			attribute requiredPressure : Pressure;
			
			require constraint {
				pump.maxDischargePressure >= requiredPressure
			}
		}
		
		requirement def AlternatingOperationRequirement {
			subject pump : PulsometerPump;
			doc /* Chambers shall operate in alternating sequence */
			
			require constraint {
				pump.chamberA.isFilling xor pump.chamberB.isFilling
			}
		}
		
		requirement def SteamEfficiencyRequirement {
			subject pump : PulsometerPump;
			doc /* Steam consumption shall not exceed design limit */
			
			attribute maxSteamConsumption : FlowRate;
			
			require constraint {
				pump.steamConsumption <= maxSteamConsumption
			}
		}
	}
	
	package Usages {
		part pulsometerSystem {
			part sourceReservoir : Definitions::SourceReservoir {
				attribute :>> waterLevel = 0.5;
				attribute :>> sourcePressure = 101325.0;
			}
			
			part steamBoiler : Definitions::SteamBoiler {
				attribute :>> boilerPressure = 500000.0;
				attribute :>> boilerTemperature = 425.0;
			}
			
			part pump : Definitions::PulsometerPump {
				attribute :>> designFlowRate = 2.0;
				attribute :>> maxDischargePressure = 300000.0;
				attribute :>> cycleTime = 30.0;
				attribute :>> steamConsumption = 12.0;
				
				part :>> chamberA {
					attribute :>> currentPressure = 101325.0;
					attribute :>> fluidLevel = 0.0;
					attribute :>> isFilling = true;
					attribute :>> isDischarging = false;
				}
				
				part :>> chamberB {
					attribute :>> currentPressure = 101325.0;
					attribute :>> fluidLevel = 0.0;
					attribute :>> isFilling = false;
					attribute :>> isDischarging = true;
				}
				
				part :>> suctionCheckA {
					attribute :>> crackingPressure = 5000.0;
					attribute :>> isOpen = false;
				}
				
				part :>> suctionCheckB {
					attribute :>> crackingPressure = 5000.0;
					attribute :>> isOpen = false;
				}
				
				part :>> dischargeCheckA {
					attribute :>> crackingPressure = 10000.0;
					attribute :>> isOpen = false;
				}
				
				part :>> dischargeCheckB {
					attribute :>> crackingPressure = 10000.0;
					attribute :>> isOpen = false;
				}
			}
			
			part deliveryTank : Definitions::DeliveryTank {
				attribute :>> waterLevel = 0.0;
				attribute :>> tankPressure = 200000.0;
			}
			
			part condensateTank : Definitions::CondensateTank {
				attribute :>> condensateLevel = 0.0;
			}
			
			flow of water : Definitions::Water
				from sourceReservoir.outlet.fluidOut
				to pump.suctionPort.fluidIn;
			
			flow of steam : Definitions::Steam
				from steamBoiler.steamOutlet.steamIn
				to pump.steamSupplyPort.steamIn;
			
			flow of dischargedWater : Definitions::Water
				from pump.dischargePort.fluidOut
				to deliveryTank.inlet.fluidIn;
			
			flow of condensate : Definitions::Condensate
				from pump.condensateReturnPort.condensateOut
				to condensateTank.condensateInlet.condensateOut;
			
			satisfy flowReq : Definitions::FlowCapacityRequirement by pump {
				attribute :>> minFlowRate = 1.5;
			}
			
			satisfy pressureReq : Definitions::DischargePressureRequirement by pump {
				attribute :>> requiredPressure = 250000.0;
			}
			
			satisfy alternatingReq : Definitions::AlternatingOperationRequirement by pump;
			
			satisfy efficiencyReq : Definitions::SteamEfficiencyRequirement by pump {
				attribute :>> maxSteamConsumption = 15.0;
			}
		}
	}
}
