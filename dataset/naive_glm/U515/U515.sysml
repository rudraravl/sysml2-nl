package Honeywagon {
    import SI::*;
    
    value type Volume :> Real { unit 'L'; }
    value type Pressure :> Real { unit 'kPa'; }
    value type FlowRate :> Real { unit 'L/min'; }
    value type Length :> Real { unit 'm'; }
    value type Mass :> Real { unit 'kg'; }
    
    item def LiquidWaste;
    item def FreshWater;
    
    port def WasteFlowPort {
        in item waste: LiquidWaste;
        attr flowRate: FlowRate;
    }
    
    port def WaterFlowPort {
        out item water: FreshWater;
        attr flowRate: FlowRate;
    }
    
    port def PowerPort {
        attr torque: Real;
        attr speed: Real;
    }
    
    port def CommandPort {
        in attr command: String;
        out attr status: String;
    }
    
    requirement def VehicleRequirements {
        subject vehicle: Honeywagon;
        
        requirement CapacityRequirement {
            doc /* The main tank must hold at least 5000 L */
            constraint { vehicle.mainTank.capacity >= 5000 [L] }
        }
        
        requirement WaterCapacityRequirement {
            doc /* The fresh water reservoir must hold at least 500 L */
            constraint { vehicle.waterReservoir.capacity >= 500 [L] }
        }
        
        requirement VacuumPressureRequirement {
            doc /* The vacuum pump must generate at least 80 kPa of vacuum */
            constraint { vehicle.vacuumPump.maxVacuum >= 80 [kPa] }
        }
    }
    
    part def TruckChassis {
        port powerOut: PowerPort;
        attr maxPayload: Mass = 8000 [kg];
    }
    
    part def MainStorageTank {
        port wasteIn: WasteFlowPort;
        port wasteOut: WasteFlowPort;
        port levelSensor: CommandPort;
        attr capacity: Volume = 5000 [L];
        attr currentLevel: Volume;
    }
    
    part def WaterReservoir {
        port waterOut: WaterFlowPort;
        attr capacity: Volume = 500 [L];
        attr currentLevel: Volume;
    }
    
    part def VacuumPump {
        port powerIn: PowerPort;
        port vacuumIn: WasteFlowPort;
        port pumpOut: WasteFlowPort;
        port control: CommandPort;
        attr maxVacuum: Pressure = 85 [kPa];
        attr isRunning: Boolean;
    }
    
    part def SuctionHose {
        port operatorEnd: WasteFlowPort;
        port pumpEnd: WasteFlowPort;
        attr length: Length = 10 [m];
        attr diameter: Length = 0.1 [m];
    }
    
    part def DischargeValve {
        port tankSide: WasteFlowPort;
        port dischargeSide: WasteFlowPort;
        port control: CommandPort;
        attr isOpen: Boolean;
    }
    
    part def ControlStation {
        port pumpControl: CommandPort;
        port valveControl: CommandPort;
        port tankSensor: CommandPort;
        attr currentMode: String;
    }
    
    part def Honeywagon {
        part chassis: TruckChassis;
        part mainTank: MainStorageTank;
        part waterReservoir: WaterReservoir;
        part vacuumPump: VacuumPump;
        part suctionHose: SuctionHose;
        part dischargeValve: DischargeValve;
        part controlStation: ControlStation;
        
        connection powerConnection connect chassis.powerOut to vacuumPump.powerIn;
        connection hoseToPump connect suctionHose.pumpEnd to vacuumPump.vacuumIn;
        connection pumpToTank connect vacuumPump.pumpOut to mainTank.wasteIn;
        connection tankToValve connect mainTank.wasteOut to dischargeValve.tankSide;
        
        connection controlToPump connect controlStation.pumpControl to vacuumPump.control;
        connection controlToValve connect controlStation.valveControl to dischargeValve.control;
        connection tankToControl connect mainTank.levelSensor to controlStation.tankSensor;
        
        state machine OperationalModes {
            entry action { controlStation.currentMode = "idle"; }
            
            state idle {
                entry action { 
                    vacuumPump.isRunning = false; 
                    dischargeValve.isOpen = false; 
                }
            }
            state collecting {
                entry action { 
                    vacuumPump.isRunning = true; 
                    dischargeValve.isOpen = false; 
                }
            }
            state transporting {
                entry action { 
                    vacuumPump.isRunning = false; 
                    dischargeValve.isOpen = false; 
                }
            }
            state discharging {
                entry action { 
                    vacuumPump.isRunning = false; 
                    dischargeValve.isOpen = true; 
                }
            }
            state waterDispensing {
                entry action { 
                    vacuumPump.isRunning = false; 
                    dischargeValve.isOpen = false; 
                }
            }
            
            transition from idle to collecting when controlStation.currentMode == "collecting";
            transition from collecting to transporting when controlStation.currentMode == "transporting";
            transition from transporting to discharging when controlStation.currentMode == "discharging";
            transition from discharging to waterDispensing when controlStation.currentMode == "waterDispensing";
            transition from waterDispensing to idle when controlStation.currentMode == "idle";
            transition from idle to waterDispensing when controlStation.currentMode == "waterDispensing";
            transition from waterDispensing to transporting when controlStation.currentMode == "transporting";
            transition from collecting to idle when controlStation.currentMode == "idle";
        }
    }
}
