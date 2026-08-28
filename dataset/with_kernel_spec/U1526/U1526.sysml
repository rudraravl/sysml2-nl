package 'Water Distribution System' {
    private import ScalarValues::*;
    
    attribute def Liter :> Real;
    attribute def Bar :> Real;
    attribute def Percentage :> Real;
    attribute def Celsius :> Real;
    attribute def NTU :> Real;
    attribute def pH :> Real;
    
    item def Water;
    item def LevelData { attribute level : Percentage; }
    item def QualityData { attribute ph : pH; attribute turbidity : NTU; attribute temp : Celsius; }
    item def ValveCommand { attribute open : Boolean; }
    
    port def WaterInPort { in item water : Water; }
    port def WaterOutPort { out item water : Water; }
    port def CommandInPort { in item command : ValveCommand; }
    port def CommandOutPort { out item command : ValveCommand; }
    port def LevelDataInPort { in item data : LevelData; }
    port def LevelDataOutPort { out item data : LevelData; }
    port def QualityDataInPort { in item data : QualityData; }
    port def QualityDataOutPort { out item data : QualityData; }
    
    part def PressureRegulator {
        attribute targetPressure : Bar;
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
    }
    
    part def FlowValve {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port controlIn : CommandInPort;
        attribute isOpen : Boolean = false;
        
        state def ValveBehavior {
            initial state closed;
            state open;
            transition from closed to open when controlIn.command.open == true;
            transition from open to closed when controlIn.command.open == false;
        }
    }
    
    part def StorageTank {
        attribute capacity : Liter = 100000;
        attribute minLevel : Percentage = 5;
        attribute maxLevel : Percentage = 95;
        attribute targetLevel : Percentage = 80;
        port inlet : WaterInPort;
        port outlet : WaterOutPort;
        port levelSensorPort : WaterOutPort;
        port qualityMonitorPort : WaterOutPort;
    }
    
    part def LevelSensor {
        port waterIn : WaterInPort;
        port dataOut : LevelDataOutPort;
    }
    
    part def QualityMonitor {
        port waterIn : WaterInPort;
        port dataOut : QualityDataOutPort;
    }
    
    part def SystemController {
        port levelDataIn : LevelDataInPort;
        port qualityDataIn : QualityDataInPort;
        port inletValveControl : CommandOutPort;
        port outletValveControl : CommandOutPort;
        attribute status : String;
        attribute targetLevel : Percentage = 80;
        attribute maxLevel : Percentage = 95;
        attribute minLevel : Percentage = 5;
        
        state def ControlBehavior {
            initial state normal {
                entry { status = 'normal'; }
            }
            state filling {
                entry { status = 'filling'; }
            }
            state draining {
                entry { status = 'draining'; }
            }
            state full {
                entry { status = 'full'; }
            }
            
            transition from normal to filling when levelDataIn.data.level < targetLevel;
            transition from filling to normal when levelDataIn.data.level >= targetLevel;
            transition from normal to draining when levelDataIn.data.level > maxLevel;
            transition from draining to normal when levelDataIn.data.level <= targetLevel;
            transition from normal to full when levelDataIn.data.level >= maxLevel;
            transition from full to draining when levelDataIn.data.level < maxLevel;
        }
    }
    
    part def WaterDistributionSystem {
        part storageTank : StorageTank;
        part inletRegulator : PressureRegulator { attribute targetPressure = 4; }
        part inletValve : FlowValve;
        part outletValve : FlowValve;
        part outletRegulator : PressureRegulator { attribute targetPressure = 3; }
        part levelSensor : LevelSensor;
        part qualityMonitor : QualityMonitor;
        part controller : SystemController;
        
        connection waterInletFlow : inletRegulator.waterOut to inletValve.waterIn;
        connection waterTankInlet : inletValve.waterOut to storageTank.inlet;
        connection waterTankOutlet : storageTank.outlet to outletValve.waterIn;
        connection waterOutletFlow : outletValve.waterOut to outletRegulator.waterIn;
        
        connection tankToLevelSensor : storageTank.levelSensorPort to levelSensor.waterIn;
        connection tankToQualityMonitor : storageTank.qualityMonitorPort to qualityMonitor.waterIn;
        
        connection levelDataFlow : levelSensor.dataOut to controller.levelDataIn;
        connection qualityDataFlow : qualityMonitor.dataOut to controller.qualityDataIn;
        
        connection inletValveControlFlow : controller.inletValveControl to inletValve.controlIn;
        connection outletValveControlFlow : controller.outletValveControl to outletValve.controlIn;
    }
    
    requirement def SafeOperation {
        subject tank : StorageTank;
        constraint { tank.minLevel == 5 and tank.maxLevel == 95; }
    }
    
    requirement def AutomatedControl {
        subject controller : SystemController;
        constraint { controller.status == 'filling' or controller.status == 'draining' or controller.status == 'normal' or controller.status == 'full'; }
    }
    
    requirement def TankCapacity {
        subject tank : StorageTank;
        constraint { tank.capacity == 100000; }
    }
    
    requirement def PressureRegulation {
        subject system : WaterDistributionSystem;
        constraint { system.inletRegulator.targetPressure == 4 and system.outletRegulator.targetPressure == 3; }
    }
}
