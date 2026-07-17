package PulsometerPumpingSubsystem {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		
		item def Steam {
			attribute pressure : Real;
			attribute temperature : Real;
			attribute massFlowRate : Real;
		}
		
		item def Water {
			attribute pressure : Real;
			attribute temperature : Real;
			attribute volumeFlowRate : Real;
		}
		
		item def Condensate {
			attribute temperature : Real;
			attribute massFlowRate : Real;
		}
		
		attribute def PressureValue :> Real;
		attribute def TemperatureValue :> Real;
		attribute def VolumeValue :> Real;
		attribute def FlowRateValue :> Real;
		
		port def SteamInletPort {
			in item steamSupply : Steam;
			attribute pressure : PressureValue;
			attribute temperature : TemperatureValue;
		}
		
		port def WaterSuctionPort {
			in item waterSupply : Water;
			attribute pressure : PressureValue;
		}
		
		port def WaterDischargePort {
			out item waterDischarge : Water;
			attribute pressure : PressureValue;
			attribute flowRate : FlowRateValue;
		}
		
		port def CondensateDrainPort {
			out item condensateDrain : Condensate;
		}
		
		part def CheckValve {
			attribute isOpen : Boolean;
			attribute crackingPressure : PressureValue;
			
			port inletPort {
				in item fluidIn : Water;
				attribute pressure : PressureValue;
			}
			
			port outletPort {
				out item fluidOut : Water;
				attribute pressure : PressureValue;
			}
		}
		
		part def SteamControlValve {
			attribute isOpen : Boolean;
			attribute position : Real;
			
			port steamIn : SteamInletPort;
			port steamOut {
				out item steamFlow : Steam;
			}
		}
		
		part def PulsometerChamber {
			attribute chamberVolume : VolumeValue;
			attribute currentWaterLevel : VolumeValue;
			attribute currentPressure : PressureValue;
			attribute currentTemperature : TemperatureValue;
			attribute isFilling : Boolean;
			
			port steamInlet : SteamInletPort;
			port waterInlet : WaterSuctionPort;
			port waterOutlet : WaterDischargePort;
			port condensateOutlet : CondensateDrainPort;
			
			exhibit state chamberState : PulsometerChamberStateMachine;
		}
		
		state def PulsometerChamberStateMachine {
			in attribute chamberVolume : VolumeValue;
			in attribute currentWaterLevel : VolumeValue;
			in attribute currentPressure : PressureValue;
			
			entry; then idle;
			
			state idle {
				doc /* Chamber is idle and ready for operation */
			}
			
			transition idle_to_steamAdmission
				first idle
				then steamAdmission;
			
			state steamAdmission {
				doc /* Steam enters chamber and begins condensing, creating vacuum */
				entry action {
					doc /* Open steam valve, steam condenses on chamber walls */
				}
			}
			
			transition steamAdmission_to_filling
				first steamAdmission
				if currentPressure < 0.3
				then filling;
			
			state filling {
				doc /* Water drawn into chamber by vacuum created from condensing steam */
				entry action {
					doc /* Water flows through inlet check valve due to pressure differential */
				}
			}
			
			transition filling_to_pressurizing
				first filling
				if currentWaterLevel >= chamberVolume * 0.85
				then pressurizing;
			
			state pressurizing {
				doc /* Steam admitted to pressurize chamber and force water out */
				entry action {
					doc /* Steam valve opens, pressure builds in chamber */
				}
			}
			
			transition pressurizing_to_discharging
				first pressurizing
				if currentPressure > 2.5
				then discharging;
			
			state discharging {
				doc /* Pressurized water discharged through outlet check valve */
				entry action {
					doc /* Water forced out through discharge valve by steam pressure */
				}
			}
			
			transition discharging_to_draining
				first discharging
				if currentWaterLevel < chamberVolume * 0.15
				then draining;
			
			state draining {
				doc /* Condensate drained from chamber */
				entry action {
					doc /* Condensate removed through drain port */
				}
			}
			
			transition draining_to_idle
				first draining
				then idle;
		}
		
		part def PulsometerPump {
			
			part chamberA : PulsometerChamber {
				attribute :>> chamberVolume = 75.0;
			}
			
			part chamberB : PulsometerChamber {
				attribute :>> chamberVolume = 75.0;
			}
			
			part suctionCheckValveA : CheckValve {
				attribute :>> crackingPressure = 0.2;
			}
			
			part suctionCheckValveB : CheckValve {
				attribute :>> crackingPressure = 0.2;
			}
			
			part dischargeCheckValveA : CheckValve {
				attribute :>> crackingPressure = 1.5;
			}
			
			part dischargeCheckValveB : CheckValve {
				attribute :>> crackingPressure = 1.5;
			}
			
			part steamValveA : SteamControlValve;
			part steamValveB : SteamControlValve;
			
			port steamSupplyPort : SteamInletPort;
			port waterSuctionPort : WaterSuctionPort;
			port waterDischargePort : WaterDischargePort;
			port condensateDrainPort : CondensateDrainPort;
			
			binding of steamValveA.steamOut.steamFlow = chamberA.steamInlet.steamSupply;
			binding of steamValveB.steamOut.steamFlow = chamberB.steamInlet.steamSupply;
			
			binding of suctionCheckValveA.outletPort.fluidOut = chamberA.waterInlet.waterSupply;
			binding of suctionCheckValveB.outletPort.fluidOut = chamberB.waterInlet.waterSupply;
			
			binding of chamberA.waterOutlet.waterDischarge = dischargeCheckValveA.inletPort.fluidIn;
			binding of chamberB.waterOutlet.waterDischarge = dischargeCheckValveB.inletPort.fluidIn;
			
			perform action pumpOperation : PulsometerPumpOperation;
		}
		
		action def PulsometerPumpOperation {
			in ref chamberA : PulsometerChamber;
			in ref chamberB : PulsometerChamber;
			
			first start;
			then merge operationLoop;
			then decide;
				if chamberA.isFilling then operateChamberB;
				if chamberB.isFilling then operateChamberA;
			
			action operateChamberA {
				doc /* Execute chamber A cycle while chamber B fills */
			}
			then operationLoop;
			
			action operateChamberB {
				doc /* Execute chamber B cycle while chamber A fills */
			}
			then operationLoop;
		}
		
		part def SteamBoiler {
			port steamOutlet {
				out item steamFlow : Steam;
				attribute pressure : PressureValue;
				attribute temperature : TemperatureValue;
			}
			
			attribute boilerPressure : PressureValue;
			attribute steamTemperature : TemperatureValue;
			attribute steamMassFlowRate : Real;
		}
		
		part def WaterSource {
			port waterOutlet : WaterDischargePort;
			attribute sourceLevel : VolumeValue;
			attribute sourcePressure : PressureValue;
		}
		
		part def DischargeTank {
			port waterInlet : WaterSuctionPort;
			attribute tankLevel : VolumeValue;
			attribute tankCapacity : VolumeValue;
			attribute tankPressure : PressureValue;
		}
		
		part def CondensateReceiver {
			port condensateInlet : CondensateDrainPort;
			attribute receiverLevel : VolumeValue;
		}
		
		requirement def PumpPerformanceRequirement {
			doc /* Overall pump performance requirements */
			
			subject pump : PulsometerPump;
			
			require minimumFlowRate : MinimumFlowRateRequirement {
				subject pumpSubject = pump;
			}
			require steamPressureRange : SteamPressureRequirement {
				subject pumpSubject = pump;
			}
			require alternatingOperation : AlternatingOperationRequirement {
				subject pumpSubject = pump;
			}
		}
		
		requirement def MinimumFlowRateRequirement {
			doc /* Pump must deliver minimum discharge flow rate */
			
			subject pumpSubject : PulsometerPump;
			attribute requiredFlowRate : FlowRateValue = 120.0;
			
			require constraint {
				pumpSubject.waterDischargePort.flowRate >= requiredFlowRate
			}
		}
		
		requirement def SteamPressureRequirement {
			doc /* Steam supply must maintain operating pressure range */
			
			subject pumpSubject : PulsometerPump;
			attribute minimumSteamPressure : PressureValue = 3.5;
			attribute maximumSteamPressure : PressureValue = 8.0;
			
			require constraint {
				pumpSubject.steamSupplyPort.pressure >= minimumSteamPressure and
				pumpSubject.steamSupplyPort.pressure <= maximumSteamPressure
			}
		}
		
		requirement def AlternatingOperationRequirement {
			doc /* Chambers must operate in alternating sequence for continuous flow */
			
			subject pumpSubject : PulsometerPump;
			
			require constraint {
				pumpSubject.chamberA.isFilling != pumpSubject.chamberB.isFilling
			}
		}
	}
	
	package Usages {
		
		part pumpingSystem {
			
			part steamBoiler : Definitions::SteamBoiler {
				attribute :>> boilerPressure = 6.0;
				attribute :>> steamTemperature = 165.0;
				attribute :>> steamMassFlowRate = 0.5;
			}
			
			flow of steam : Definitions::Steam
				from steamBoiler.steamOutlet.steamFlow
				to pulsometerPump.steamSupplyPort.steamSupply;
			
			part pulsometerPump : Definitions::PulsometerPump {
				
				binding of steamValveA.steamIn.steamSupply = steamSupplyPort.steamSupply;
				binding of steamValveB.steamIn.steamSupply = steamSupplyPort.steamSupply;
				
				binding of suctionCheckValveA.inletPort.fluidIn = waterSuctionPort.waterSupply;
				binding of suctionCheckValveB.inletPort.fluidIn = waterSuctionPort.waterSupply;
				
				binding of dischargeCheckValveA.outletPort.fluidOut = waterDischargePort.waterDischarge;
				binding of dischargeCheckValveB.outletPort.fluidOut = waterDischargePort.waterDischarge;
			}
			
			part waterSource : Definitions::WaterSource {
				attribute :>> sourceLevel = 5000.0;
				attribute :>> sourcePressure = 1.0;
			}
			
			flow of water : Definitions::Water
				from waterSource.waterOutlet.waterDischarge
				to pulsometerPump.waterSuctionPort.waterSupply;
			
			part dischargeTank : Definitions::DischargeTank {
				attribute :>> tankCapacity = 10000.0;
				attribute :>> tankPressure = 3.0;
			}
			
			flow of water : Definitions::Water
				from pulsometerPump.waterDischargePort.waterDischarge
				to dischargeTank.waterInlet.waterSupply;
			
			part condensateReceiver : Definitions::CondensateReceiver {
				attribute :>> receiverLevel = 0.0;
			}
			
			flow of condensate : Definitions::Condensate
				from pulsometerPump.condensateDrainPort.condensateDrain
				to condensateReceiver.condensateInlet.condensateDrain;
			
			satisfy pumpPerformanceReq : Definitions::PumpPerformanceRequirement {
				subject pump = pulsometerPump;
			}
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import PulsometerPumpingSubsystem::*;

    part testSubject : PulsometerChamber {
        exhibit state chamberState : PulsometerChamberStateMachine;
    }

    action orchestrator {
        action actionProbe : PulsometerPumpOperation {
            // TODO(human): unsupported input type for chamberA: PulsometerChamber (type is not a primitive, enum, extracted payload def, or known value type)
            // TODO(human): unsupported input type for chamberB: PulsometerChamber (type is not a primitive, enum, extracted payload def, or known value type)
        }
        first actionProbe;
    }
}
