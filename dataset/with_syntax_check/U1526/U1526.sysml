package WaterStorageSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def VolumeFlowRateValue :> ISQ::VolumeFlowValue {
        attribute :>> num : Real;
    }
    
    attribute def PressureValue :> ISQ::PressureValue {
        attribute :>> num : Real;
    }
    
    attribute def WaterQuality {
        attribute pH : Real;
        attribute turbidity : Real;
        attribute temperature : TemperatureValue;
    }
    
    enum def TankStatusKind {
        empty;
        filling;
        normal;
        draining;
        full;
        alarm;
    }
    
    item def Water {
        attribute quality : WaterQuality;
    }
    
    port def WaterFlowPort {
        in item water : Water;
        attribute flowRate : VolumeFlowRateValue;
        attribute pressure : PressureValue;
    }
    
    port def SensorPort {
        out attribute levelReading : Real;
        out attribute qualityReading : WaterQuality;
    }
    
    port def ControlPort {
        in attribute fillCommand : Boolean;
        in attribute drainCommand : Boolean;
        out attribute status : TankStatusKind;
    }
    
    part def LevelSensor {
        attribute measuredLevel : Real;
        attribute accuracy : Real = 0.5;
        
        port output : SensorPort;
        
        action def MeasureLevel {
            out level : Real;
        }
    }
    
    part def QualityMonitor {
        attribute currentQuality : WaterQuality;
        
        port output : SensorPort;
        
        action def MonitorQuality {
            out quality : WaterQuality;
        }
    }
    
    part def FlowValve {
        attribute position : Real;
        attribute maxFlowRate : VolumeFlowRateValue;
        
        port inlet : WaterFlowPort;
        port outlet : WaterFlowPort;
    }
    
    part def PressureRegulator {
        attribute targetPressure : PressureValue;
        attribute currentPressure : PressureValue;
        
        port inlet : WaterFlowPort;
        port outlet : WaterFlowPort;
        
        assert constraint pressureControl {
            outlet.pressure.num <= targetPressure.num
        }
    }
    
    part def StorageTank {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute fillLevel : Real;
        attribute minSafeLevel : Real = 5.0;
        attribute maxSafeLevel : Real = 95.0;
        
        port inlet : WaterFlowPort;
        port outlet : WaterFlowPort;
        
        assert constraint volumeLimit {
            currentVolume <= capacity
        }
        
        assert constraint levelBounds {
            fillLevel >= 0.0 and fillLevel <= 100.0
        }
        
        assert constraint safeOperatingRange {
            fillLevel >= minSafeLevel and fillLevel <= maxSafeLevel
        }
    }
    
    part def SystemController {
        attribute operatingMode : TankStatusKind;
        attribute targetLevel : Real = 80.0;
        
        port sensorInput : SensorPort;
        port controlOutput : ControlPort;
        
        action def EvaluateLevel {
            in currentLevel : Real;
            in minLevel : Real;
            in maxLevel : Real;
            out needsFilling : Boolean;
            out needsDraining : Boolean;
            out isNormal : Boolean;
        }
        
        action def CommandValves {
            in fillNeeded : Boolean;
            in drainNeeded : Boolean;
            out inletValvePosition : Real;
            out outletValvePosition : Real;
        }
    }
    
    action def MonitorAndControl {
        first start;
        then merge controlLoop;
        
        then action evaluateStatus : SystemController::EvaluateLevel {
            in currentLevel : Real;
            in minLevel : Real;
            in maxLevel : Real;
            out needsFilling : Boolean;
            out needsDraining : Boolean;
            out isNormal : Boolean;
        }
        
        then decide;
            if evaluateStatus.needsFilling then fillOperation;
            if evaluateStatus.needsDraining then drainOperation;
            if evaluateStatus.isNormal then maintainOperation;
        
        action fillOperation : SystemController::CommandValves {
            in fillNeeded = true;
            in drainNeeded = false;
            out inletValvePosition : Real;
            out outletValvePosition : Real;
        }
        then controlLoop;
        
        action drainOperation : SystemController::CommandValves {
            in fillNeeded = false;
            in drainNeeded = true;
            out inletValvePosition : Real;
            out outletValvePosition : Real;
        }
        then controlLoop;
        
        action maintainOperation : SystemController::CommandValves {
            in fillNeeded = false;
            in drainNeeded = false;
            out inletValvePosition : Real;
            out outletValvePosition : Real;
        }
        then controlLoop;
    }
    
    part waterStorageSystem {
        doc /* A water storage system designed to receive, store, and distribute water 
             * while maintaining safe operating levels and water quality. The system 
             * automatically manages filling and draining operations to ensure continuous 
             * availability and prevent overflow or dry conditions.
             */
        
        attribute systemCapacity : VolumeValue = 100000.0 [L];
        attribute operationalStatus : TankStatusKind;
        
        part mainTank : StorageTank {
            attribute :>> capacity = waterStorageSystem.systemCapacity;
            attribute :>> currentVolume : VolumeValue = 50000.0 [L];
            attribute :>> fillLevel = (currentVolume.num / capacity.num) * 100.0;
        }
        
        part levelSensor : LevelSensor {
            attribute :>> measuredLevel = mainTank.fillLevel;
        }
        
        part qualityMonitor : QualityMonitor {
            attribute :>> currentQuality : WaterQuality {
                attribute :>> pH = 7.2;
                attribute :>> turbidity = 0.5;
                attribute :>> temperature : TemperatureValue = 15.0 [Celsius];
            }
        }
        
        part inletValve : FlowValve {
            attribute :>> maxFlowRate : VolumeFlowRateValue = 1000.0;
        }
        
        part outletValve : FlowValve {
            attribute :>> maxFlowRate : VolumeFlowRateValue = 800.0;
        }
        
        part inletRegulator : PressureRegulator {
            attribute :>> targetPressure : PressureValue = 4.0;
        }
        
        part outletRegulator : PressureRegulator {
            attribute :>> targetPressure : PressureValue = 3.0;
        }
        
        part controller : SystemController {
            attribute :>> operatingMode = waterStorageSystem.operationalStatus;
            attribute :>> targetLevel = 80.0;
        }
        
        port supplyInlet : WaterFlowPort;
        port distributionOutlet : WaterFlowPort;
        
        connection inletPath connect supplyInlet to inletRegulator.inlet;
        connection regulatedInlet connect inletRegulator.outlet to inletValve.inlet;
        connection tankInlet connect inletValve.outlet to mainTank.inlet;
        connection tankOutlet connect mainTank.outlet to outletValve.inlet;
        connection regulatedOutlet connect outletValve.outlet to outletRegulator.inlet;
        connection outletPath connect outletRegulator.outlet to distributionOutlet;
        
        connection levelMonitoring connect levelSensor.output to controller.sensorInput;
        connection qualityMonitoring connect qualityMonitor.output to controller.sensorInput;
        
        perform action systemOperation : MonitorAndControl;
    }
    
    package Requirements {
        requirement <'REQ-WS-001'> primaryFunction {
            doc /* The water storage system shall receive water from a supply source, 
                 * store it safely, and distribute it on demand while maintaining water 
                 * quality and preventing overflow or depletion.
                 */
            subject system :> waterStorageSystem;
        }
        
        requirement <'REQ-WS-002'> storageCapacity {
            doc /* The system shall provide a minimum storage capacity of 100000 liters. */
            subject tank :> waterStorageSystem.mainTank;
            assert constraint {
                tank.capacity.num >= 100000.0
            }
        }
        
        requirement <'REQ-WS-003'> levelControl {
            doc /* The system shall maintain water level between 5% and 95% of total 
                 * capacity during normal operation to prevent structural damage and 
                 * ensure availability.
                 */
            subject tank :> waterStorageSystem.mainTank;
            assert constraint {
                tank.fillLevel >= tank.minSafeLevel and 
                tank.fillLevel <= tank.maxSafeLevel
            }
        }
        
        requirement <'REQ-WS-004'> inletFlowRate {
            doc /* The system shall support an inlet flow rate of at least 1000 liters 
                 * per minute to enable rapid filling.
                 */
            subject valve :> waterStorageSystem.inletValve;
            assert constraint {
                valve.maxFlowRate.num >= 1000.0
            }
        }
        
        requirement <'REQ-WS-005'> pressureRegulation {
            doc /* The system shall regulate inlet pressure to 4 bar and outlet pressure 
                 * to 3 bar to protect infrastructure and ensure safe distribution.
                 */
            subject inletReg :> waterStorageSystem.inletRegulator;
            subject outletReg :> waterStorageSystem.outletRegulator;
            assert constraint {
                inletReg.targetPressure.num == 4.0 and 
                outletReg.targetPressure.num == 3.0
            }
        }
        
        requirement <'REQ-WS-006'> waterQualityMonitoring {
            doc /* The system shall continuously monitor water quality parameters including 
                 * pH, turbidity, and temperature.
                 */
            subject monitor :> waterStorageSystem.qualityMonitor;
        }
        
        requirement <'REQ-WS-007'> automaticControl {
            doc /* The system shall automatically control filling and draining operations 
                 * based on level sensor feedback without manual intervention.
                 */
            subject controller :> waterStorageSystem.controller;
        }
        
        requirement <'REQ-WS-008'> overflowPrevention {
            doc /* The system shall prevent tank overflow by closing inlet valves when 
                 * water level reaches 95% of capacity.
                 */
            subject system :> waterStorageSystem;
        }
        
        satisfy primaryFunction by waterStorageSystem;
        satisfy storageCapacity by waterStorageSystem.mainTank;
        satisfy levelControl by waterStorageSystem.controller;
        satisfy inletFlowRate by waterStorageSystem.inletValve;
        satisfy pressureRegulation by waterStorageSystem.inletRegulator;
        satisfy waterQualityMonitoring by waterStorageSystem.qualityMonitor;
        satisfy automaticControl by waterStorageSystem.systemOperation;
        satisfy overflowPrevention by waterStorageSystem;
    }
}
