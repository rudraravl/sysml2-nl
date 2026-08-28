package 'Honeywagon Sanitation Vehicle' {
	private import ScalarValues::*;
	
	package Definitions {
		item def LiquidWaste;
		item def FreshWater;
		
		attribute def Volume :> Real;
		attribute def Pressure :> Real;
		attribute def Torque :> Real;
		
		port def WasteInPort {
			in item waste : LiquidWaste;
		}
		port def WasteOutPort {
			out item waste : LiquidWaste;
		}
		port def WaterOutPort {
			out item water : FreshWater;
		}
		port def WaterInPort {
			in item water : FreshWater;
		}
		port def PowerPort {
			out torque : Torque;
		}
		
		part def TruckChassis {
			part drivetrain;
			part engine {
				port powerOut : PowerPort;
			}
		}
		
		part def WasteTank {
			attribute capacity : Volume;
			attribute currentLevel : Volume = 0;
			port wasteIn : WasteInPort;
			port wasteOut : WasteOutPort;
			item storedWaste : LiquidWaste;
		}
		
		part def WaterReservoir {
			attribute capacity : Volume;
			attribute currentLevel : Volume = 0;
			port waterOut : WaterOutPort;
			item storedWater : FreshWater;
		}
		
		part def VacuumPump {
			port powerIn : ~PowerPort;
			port wasteIn : WasteInPort;
			port wasteOut : WasteOutPort;
			attribute maxPressure : Pressure;
		}
		
		part def SuctionHose {
			port end1 : WasteInPort;
			port end2 : WasteOutPort;
		}
		
		part def DischargeValve {
			port inlet : WasteInPort;
			port outlet : WasteOutPort;
			attribute isOpen : Boolean = false;
		}
		
		part def OperatorStation {
			attribute displayedWasteLevel : Volume;
			attribute displayedWaterLevel : Volume;
		}
		
		action def CollectWaste {
			in waste : LiquidWaste;
		}
		action def DischargeWaste {
			out waste : LiquidWaste;
		}
		action def DispenseWater {
			out water : FreshWater;
		}
		
		state def OperationalMode {
			state idle;
			state collecting;
			state transporting;
			state discharging;
			state waterDispensing;
			transition from idle to collecting;
			transition from collecting to transporting;
			transition from transporting to discharging;
			transition from discharging to waterDispensing;
			transition from waterDispensing to idle;
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part honeywagon {
			part chassis : TruckChassis;
			part wasteTank : WasteTank {
				attribute redefines capacity = 5000;
			}
			part waterReservoir : WaterReservoir {
				attribute redefines capacity = 1000;
			}
			part vacuumPump : VacuumPump {
				attribute redefines maxPressure = 1.5;
			}
			part suctionHose : SuctionHose;
			part dischargeValve : DischargeValve;
			part operatorStation : OperatorStation;
			
			part externalDisposal {
				port wasteIn : WasteInPort;
			}
			part externalFacility {
				port waterIn : WaterInPort;
			}
			
			interface connect chassis.engine.powerOut to vacuumPump.powerIn;
			interface connect suctionHose.end2 to vacuumPump.wasteIn;
			interface connect vacuumPump.wasteOut to wasteTank.wasteIn;
			interface connect wasteTank.wasteOut to dischargeValve.inlet;
			interface connect dischargeValve.outlet to externalDisposal.wasteIn;
			interface connect waterReservoir.waterOut to externalFacility.waterIn;
			
			perform opMode : OperationalMode;
			
			action collectWaste : CollectWaste {
				in waste = suctionHose.end1.waste;
			}
			action dischargeWaste : DischargeWaste {
				out waste = dischargeValve.outlet.waste;
			}
			action dispenseWater : DispenseWater {
				out water = waterReservoir.waterOut.water;
			}
		}
	}
	
	package Requirements {
		private import Definitions::*;
		
		requirement def CapacityRequirement {
			attribute minWasteCapacity : Volume;
			attribute minWaterCapacity : Volume;
		}
		requirement def SafetyRequirement {
			attribute maxOperatingPressure : Pressure;
		}
		
		requirement honeywagonCapacity : CapacityRequirement {
			attribute redefines minWasteCapacity = 4000;
			attribute redefines minWaterCapacity = 800;
		}
		requirement honeywagonSafety : SafetyRequirement {
			attribute redefines maxOperatingPressure = 1.5;
		}
	}
}
