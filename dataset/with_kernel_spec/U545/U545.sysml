package 'Pulsometer Pumping System' {
	private import ISQ::*;
	private import ScalarValues::*;
	
	alias Pressure for ISQ::PressureValue;
	alias Volume for ISQ::VolumeValue;
	alias Temperature for ISQ::TemperatureValue;
	
	item def Water {
		attribute pressure : Pressure;
		attribute temperature : Temperature;
	}
	item def Steam {
		attribute pressure : Pressure;
		attribute temperature : Temperature;
	}
	item def Condensate :> Water;
	
	port def WaterInPort {
		in item water : Water;
	}
	port def WaterOutPort {
		out item water : Water;
	}
	port def SteamInPort {
		in item steam : Steam;
	}
	port def SteamOutPort {
		out item steam : Steam;
	}
	port def CondensateInPort {
		in item condensate : Condensate;
	}
	port def CondensateOutPort {
		out item condensate : Condensate;
	}
	
	action def AdmitSteamAction;
	action def PushWaterAction;
	action def CondenseSteamAction;
	action def FillChamberAction;
	action def ActivateChamberAAction;
	action def ActivateChamberBAction;
	
	part def SteamBoiler {
		port steamOut : SteamOutPort;
		attribute pressure : Pressure;
	}
	part def SourceReservoir {
		port waterOut : WaterOutPort;
		attribute volume : Volume;
	}
	part def DeliveryTank {
		port waterIn : WaterInPort;
		attribute capacity : Volume;
		attribute pressure : Pressure;
	}
	part def CondensateTank {
		port condensateIn : CondensateInPort;
		attribute capacity : Volume;
	}
	part def CheckValve {
		port valveIn : WaterInPort;
		port valveOut : WaterOutPort;
	}
	
	part def Chamber {
		port steamIn : SteamInPort;
		port suctionIn : WaterInPort;
		port dischargeOut : WaterOutPort;
		port condensateOut : CondensateOutPort;
		
		attribute capacity : Volume;
		attribute isFull : Boolean = false;
		attribute isPressurized : Boolean = false;
		attribute isEmpty : Boolean = false;
		attribute isVacuum : Boolean = false;
		
		state machine {
			state Admission {
				entry action admit : AdmitSteamAction;
			}
			state Discharging {
				entry action discharge : PushWaterAction;
			}
			state Condensation {
				entry action condense : CondenseSteamAction;
			}
			state Filling {
				entry action fill : FillChamberAction;
			}
			
			first start then Admission;
			transition Admission -> Discharging when isPressurized;
			transition Discharging -> Condensation when isEmpty;
			transition Condensation -> Filling when isVacuum;
			transition Filling -> Admission when isFull;
		}
	}
	
	part def PulsometerPump {
		port steamInput : SteamInPort;
		port waterSuction : WaterInPort;
		port waterDischarge : WaterOutPort;
		port condensateOutput : CondensateOutPort;
		
		part chamberA : Chamber;
		part chamberB : Chamber;
		part suctionValveA : CheckValve;
		part dischargeValveA : CheckValve;
		part suctionValveB : CheckValve;
		part dischargeValveB : CheckValve;
		
		bind steamInput = chamberA.steamIn;
		bind steamInput = chamberB.steamIn;
		bind waterSuction = suctionValveA.valveIn;
		bind waterSuction = suctionValveB.valveIn;
		connect suctionValveA.valveOut to chamberA.suctionIn;
		connect suctionValveB.valveOut to chamberB.suctionIn;
		connect chamberA.dischargeOut to dischargeValveA.valveIn;
		connect chamberB.dischargeOut to dischargeValveB.valveIn;
		bind dischargeValveA.valveOut = waterDischarge;
		bind dischargeValveB.valveOut = waterDischarge;
		bind chamberA.condensateOut = condensateOutput;
		bind chamberB.condensateOut = condensateOutput;
		
		state machine {
			state ChamberADischargePhase {
				entry action activateA : ActivateChamberAAction;
			}
			state ChamberBVacuumPhase {
				entry action activateB : ActivateChamberBAction;
			}
			
			first start then ChamberADischargePhase;
			transition ChamberADischargePhase -> ChamberBVacuumPhase when chamberA.isEmpty;
			transition ChamberBVacuumPhase -> ChamberADischargePhase when chamberB.isEmpty;
		}
	}
	
	part def PulsometerSystem {
		part boiler : SteamBoiler;
		part sourceReservoir : SourceReservoir;
		part deliveryTank : DeliveryTank;
		part condensateTank : CondensateTank;
		part pump : PulsometerPump;
		
		connect boiler.steamOut to pump.steamInput;
		connect sourceReservoir.waterOut to pump.waterSuction;
		connect pump.waterDischarge to deliveryTank.waterIn;
		connect pump.condensateOutput to condensateTank.condensateIn;
	}
	
	part system : PulsometerSystem;
	
	requirement def PulsometerPumpRequirement {
		subject pump : PulsometerPump;
		doc /* The pump shall move water from the source reservoir to the delivery tank using the direct force of steam. */
	}
	requirement def AlternatingOperationRequirement {
		subject pump : PulsometerPump;
		doc /* The pump shall operate its two chambers in alternating cycles to provide continuous flow. */
	}
	requirement def CheckValveRequirement {
		subject pump : PulsometerPump;
		doc /* The system shall use check valves to ensure water flows only from the source, into the chambers, and out to the delivery tank. */
	}
	requirement def NoComplexMovingPartsRequirement {
		subject pump : PulsometerPump;
		doc /* The pump shall not use complex moving parts such as pistons or turbines. */
	}
}
