package IrrigationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def SoilMoisturePercentage :> Real;
    attribute def WaterPressureLevel :> Real;
    attribute def FlowRateValue :> Real;
    
    value def MoistureThreshold :> SoilMoisturePercentage {
        doc /* Minimum soil moisture percentage below which irrigation is required */
    }
    
    value def TargetMoisture :> SoilMoisturePercentage {
        doc /* Optimal soil moisture percentage for healthy plant growth */
    }
    
    item def Water {
        attribute volume :> VolumeValue;
        attribute flowRate :> VolumeFlowRateValue;
        attribute pressure :> PressureValue;
        attribute temperature :> ThermodynamicTemperatureValue;
    }
    
    port def WaterSupplyPort {
        out item waterSupply : Water;
    }
    
    port def WaterDeliveryPort {
        in item waterInput : Water;
    }
    
    port def SensorDataPort {
        out moistureReading : SoilMoisturePercentage;
        out temperatureReading : ThermodynamicTemperatureValue;
    }
    
    port def ControlCommandPort {
        in command : ValveControlCommand;
    }
    
    attribute def ValveControlCommand {
        attribute targetPosition : ValvePositionState;
        attribute flowControl : FlowRateValue;
    }
    
    enum def ValvePositionState {
        fullyOpen;
        partiallyOpen;
        fullyClosed;
    }
    
    enum def PumpOperationMode {
        off;
        lowSpeed;
        mediumSpeed;
        highSpeed;
    }
    
    part def MoistureSensor {
        port dataOutput : SensorDataPort;
        attribute samplingInterval :> DurationValue;
        attribute accuracy : Real;
        
        action def MeasureSoilConditions {
            out currentMoisture : SoilMoisturePercentage;
            out ambientTemperature : ThermodynamicTemperatureValue;
        }
    }
    
    part def ControlValve {
        port commandInput : ControlCommandPort;
        port waterInlet : WaterSupplyPort;
        port waterOutlet : WaterDeliveryPort;
        
        attribute position : ValvePositionState := ValvePositionState::fullyClosed;
        attribute maxFlowCapacity :> VolumeFlowRateValue;
        
        action def AdjustValvePosition {
            in controlCommand : ValveControlCommand;
            out actualPosition : ValvePositionState;
            out resultingFlowRate : VolumeFlowRateValue;
        }
    }
    
    part def WaterPump {
        port waterIntake : WaterSupplyPort;
        port waterDischarge : WaterDeliveryPort;
        
        attribute operatingMode : PumpOperationMode := PumpOperationMode::off;
        attribute ratedPressure :> PressureValue;
        attribute ratedFlowRate :> VolumeFlowRateValue;
        attribute powerConsumption :> PowerValue;
        
        action def OperatePump {
            in mode : PumpOperationMode;
            in requiredPressure : PressureValue;
            out deliveredFlow : VolumeFlowRateValue;
            out outputPressure : PressureValue;
        }
    }
    
    part def WaterReservoir {
        port outlet : WaterSupplyPort;
        
        attribute totalCapacity :> VolumeValue;
        attribute currentLevel :> VolumeValue;
        attribute minimumLevel :> VolumeValue;
    }
    
    part def SprinklerHead {
        port waterInput : WaterDeliveryPort;
        
        attribute coverageRadius :> LengthValue;
        attribute coverageArea :> AreaValue;
        attribute sprayAngle : Real;
        attribute distributionPattern : SprayDistributionPattern;
    }
    
    enum def SprayDistributionPattern {
        uniform;
        circular;
        rectangular;
        sector;
    }
    
    part def IrrigationController {
        port sensorDataInput : SensorDataPort;
        port valveCommandOutput : ControlCommandPort;
        
        attribute lowerMoistureThreshold : MoistureThreshold := 30.0;
        attribute upperMoistureThreshold : TargetMoisture := 65.0;
        attribute hysteresisMargin : Real := 5.0;
        
        action def ProcessSensorData {
            in moistureLevel : SoilMoisturePercentage;
            in temperature : ThermodynamicTemperatureValue;
            out irrigationRequired : Boolean;
            out recommendedFlowRate : VolumeFlowRateValue;
        }
        
        action def GenerateControlCommand {
            in irrigationNeeded : Boolean;
            in targetFlowRate : VolumeFlowRateValue;
            out valveCommand : ValveControlCommand;
        }
    }
    
    action def MonitorSoilConditions {
        out soilMoisture : SoilMoisturePercentage;
        out soilTemperature : ThermodynamicTemperatureValue;
    }
    
    action def EvaluateIrrigationRequirement {
        in currentMoisture : SoilMoisturePercentage;
        in lowerThreshold : MoistureThreshold;
        in upperThreshold : TargetMoisture;
        out needsIrrigation : Boolean;
        out targetFlowRate : VolumeFlowRateValue;
    }
    
    action def ActivateWaterDelivery {
        in flowRate : VolumeFlowRateValue;
        out pumpMode : PumpOperationMode;
        out valveCommand : ValveControlCommand;
    }
    
    action def DistributeWater {
        in waterSupply : Water;
        in targetFlowRate : VolumeFlowRateValue;
        out irrigatedArea : AreaValue;
        out waterDelivered : VolumeValue;
    }
    
    action def VerifyMoistureTarget {
        in currentMoisture : SoilMoisturePercentage;
        in targetMoisture : TargetMoisture;
        in hysteresis : Real;
        out targetAchieved : Boolean;
    }
    
    action def DeactivateWaterDelivery {
        out pumpShutdown : PumpOperationMode;
        out valveClose : ValveControlCommand;
    }
    
    action def AutomatedIrrigationCycle {
        first start;
        then merge continuousMonitoring;
        
        then action monitor : MonitorSoilConditions {
            out soilMoisture : SoilMoisturePercentage;
            out soilTemperature : ThermodynamicTemperatureValue;
        }
        
        then action evaluate : EvaluateIrrigationRequirement {
            in currentMoisture = monitor.soilMoisture;
            in lowerThreshold : MoistureThreshold;
            in upperThreshold : TargetMoisture;
            out needsIrrigation : Boolean;
            out targetFlowRate : VolumeFlowRateValue;
        }
        
        then decide;
            if evaluate.needsIrrigation then activate;
            if not evaluate.needsIrrigation then continuousMonitoring;
        
        action activate : ActivateWaterDelivery {
            in flowRate = evaluate.targetFlowRate;
            out pumpMode : PumpOperationMode;
            out valveCommand : ValveControlCommand;
        }
        
        then action distribute : DistributeWater {
            in waterSupply : Water;
            in targetFlowRate = evaluate.targetFlowRate;
            out irrigatedArea : AreaValue;
            out waterDelivered : VolumeValue;
        }
        
        then action verify : VerifyMoistureTarget {
            in currentMoisture : SoilMoisturePercentage;
            in targetMoisture : TargetMoisture;
            in hysteresis : Real;
            out targetAchieved : Boolean;
        }
        
        then decide;
            if verify.targetAchieved then deactivate;
            if not verify.targetAchieved then distribute;
        
        action deactivate : DeactivateWaterDelivery {
            out pumpShutdown : PumpOperationMode;
            out valveClose : ValveControlCommand;
        }
        
        then continuousMonitoring;
    }
    
    part irrigationSystem {
        doc /* 
            Automated irrigation system that continuously monitors soil moisture levels
            and delivers water to agricultural fields or landscaped areas to maintain
            optimal growing conditions while conserving water resources.
        */
        
        perform action irrigationOperation[*] ordered references AutomatedIrrigationCycle;
        
        part waterReservoir : WaterReservoir {
            attribute totalCapacity = 10000.0;
            attribute currentLevel = 8500.0;
            attribute minimumLevel = 1000.0;
        }
        
        part mainPump : WaterPump {
            attribute ratedPressure = 400000.0;
            attribute ratedFlowRate = 150.0;
            attribute powerConsumption = 5500.0;
            perform irrigationOperation.activate;
        }
        
        part primaryValve : ControlValve {
            attribute maxFlowCapacity = 200.0;
            perform irrigationOperation.activate;
            perform irrigationOperation.deactivate;
        }
        
        part systemController : IrrigationController {
            attribute lowerMoistureThreshold = 32.0;
            attribute upperMoistureThreshold = 68.0;
            attribute hysteresisMargin = 3.0;
            perform irrigationOperation.evaluate;
        }
        
        part fieldSensor1 : MoistureSensor {
            attribute samplingInterval = 300.0;
            attribute accuracy = 2.5;
            perform irrigationOperation.monitor;
        }
        
        part fieldSensor2 : MoistureSensor {
            attribute samplingInterval = 300.0;
            attribute accuracy = 2.5;
            perform irrigationOperation.monitor;
        }
        
        part fieldSensor3 : MoistureSensor {
            attribute samplingInterval = 300.0;
            attribute accuracy = 2.5;
            perform irrigationOperation.monitor;
        }
        
        part sprinklerZone1 : SprinklerHead {
            attribute coverageRadius = 12.0;
            attribute coverageArea = 452.0;
            attribute sprayAngle = 180.0;
            attribute distributionPattern = SprayDistributionPattern::sector;
            perform irrigationOperation.distribute;
        }
        
        part sprinklerZone2 : SprinklerHead {
            attribute coverageRadius = 12.0;
            attribute coverageArea = 452.0;
            attribute sprayAngle = 180.0;
            attribute distributionPattern = SprayDistributionPattern::sector;
            perform irrigationOperation.distribute;
        }
        
        part sprinklerZone3 : SprinklerHead {
            attribute coverageRadius = 15.0;
            attribute coverageArea = 707.0;
            attribute sprayAngle = 360.0;
            attribute distributionPattern = SprayDistributionPattern::circular;
            perform irrigationOperation.distribute;
        }
        
        part sprinklerZone4 : SprinklerHead {
            attribute coverageRadius = 15.0;
            attribute coverageArea = 707.0;
            attribute sprayAngle = 360.0;
            attribute distributionPattern = SprayDistributionPattern::circular;
            perform irrigationOperation.distribute;
        }
        
        connect waterReservoir.outlet to mainPump.waterIntake;
        connect mainPump.waterDischarge to primaryValve.waterInlet;
        connect primaryValve.waterOutlet to sprinklerZone1.waterInput;
        connect primaryValve.waterOutlet to sprinklerZone2.waterInput;
        connect primaryValve.waterOutlet to sprinklerZone3.waterInput;
        connect primaryValve.waterOutlet to sprinklerZone4.waterInput;
        
        connect fieldSensor1.dataOutput to systemController.sensorDataInput;
        connect fieldSensor2.dataOutput to systemController.sensorDataInput;
        connect fieldSensor3.dataOutput to systemController.sensorDataInput;
        connect systemController.valveCommandOutput to primaryValve.commandInput;
    }
    
    requirement def MoistureMaintenanceRequirement {
        doc /* 
            The irrigation system shall maintain soil moisture levels within the specified
            optimal range to support healthy plant growth and maximize water efficiency.
        */
        
        subject irrigationSystem;
    }
    
    requirement def WaterConservationRequirement {
        doc /* 
            The irrigation system shall minimize water consumption by operating only
            when soil moisture falls below the lower threshold and stopping when the
            upper threshold is achieved.
        */
    }
    
    requirement def SystemReliabilityRequirement {
        doc /* 
            The irrigation system shall operate reliably with adequate water reserves
            and proper operating pressures to ensure consistent water delivery.
        */
    }
    
    requirement def CoverageRequirement {
        doc /* 
            The irrigation system shall provide adequate water distribution coverage
            across all designated irrigation zones.
        */
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import IrrigationSystem::*;

    action orchestrator {
        attribute testFlowRate : VolumeFlowRateValue;
        action activateProbe : ActivateWaterDelivery {
            in flowRate = testFlowRate;
        }
        first activateProbe;
    }
}
