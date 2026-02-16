package SmartManufacturingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import SequenceFunctions::*;
    
    attribute def ProductionRate :> Real;
    attribute def QualityMetric :> Real;
    attribute def EfficiencyRating :> Real;
    attribute def TemperatureSetting :> ISQ::ThermodynamicTemperatureValue;
    attribute def PressureSetting :> ISQ::PressureValue;
    attribute def VibrationAmplitude :> ISQ::LengthValue;
    attribute def TorqueSetting :> ISQ::TorqueValue;
    
    attribute def StartCommand;
    attribute def StopCommand;
    attribute def EmergencyStop;
    attribute def MaintenanceRequest;
    attribute def QualityAlert;
    
    enum def ProductionStatus {
        idle;
        initializing;
        producing;
        inspecting;
        optimizing;
        maintenance;
        shutdown;
    }
    
    item def RawMaterial {
        attribute materialId : String;
        attribute batchNumber : String;
        attribute mass :> ISQ::mass;
        attribute receivedTime :> ISQ::time;
    }
    
    item def WorkInProgress {
        attribute workpieceId : String;
        attribute processStage : Integer;
        attribute currentQuality : QualityMetric;
    }
    
    item def FinishedProduct {
        attribute productId : String;
        attribute qualityScore : QualityMetric;
        attribute productionTime :> ISQ::time;
        attribute certificationStatus : Boolean;
    }
    
    port def MaterialFlowPort {
        in item materialIn : RawMaterial;
        out item materialOut : WorkInProgress;
    }
    
    port def ProductFlowPort {
        in item wipIn : WorkInProgress;
        out item productOut : FinishedProduct;
    }
    
    port def SensorPort {
        out temperature : TemperatureSetting;
        out pressure : PressureSetting;
        out vibration : VibrationAmplitude;
    }
    
    port def ControlPort {
        in command : String;
        out status : ProductionStatus;
        out feedback : Real;
    }
    
    port def DataPort {
        out productionData : Real[*];
        out qualityData : QualityMetric[*];
        out efficiencyData : EfficiencyRating;
    }
    
    part def SensorModule {
        port sensorOutput : SensorPort;
        
        attribute temperatureReading : TemperatureSetting;
        attribute pressureReading : PressureSetting;
        attribute vibrationReading : VibrationAmplitude;
        attribute samplingRate : ProductionRate;
    }
    
    part def ProcessingStation {
        port materialInput : MaterialFlowPort;
        port materialOutput : MaterialFlowPort;
        port sensorInterface : SensorPort;
        port controlInterface : ControlPort;
        
        attribute stationId : String;
        attribute operatingTemp : TemperatureSetting;
        attribute processingSpeed : ProductionRate;
        attribute toolWear : Real;
    }
    
    part def AssemblyRobot {
        port workInput : MaterialFlowPort;
        port workOutput : MaterialFlowPort;
        port robotControl : ControlPort;
        
        attribute robotId : String;
        attribute gripperTorque : TorqueSetting;
        attribute positionAccuracy : ISQ::LengthValue;
        attribute cycleTime :> ISQ::time;
    }
    
    part def QualityInspectionStation {
        port productInput : ProductFlowPort;
        port productOutput : ProductFlowPort;
        port inspectionControl : ControlPort;
        
        attribute inspectionCriteria : QualityMetric;
        attribute defectDetectionRate : Real;
        attribute throughputRate : ProductionRate;
    }
    
    part def PredictiveMaintenanceModule {
        port sensorData : SensorPort;
        port maintenanceOutput : ControlPort;
        
        attribute failurePredictionHorizon :> ISQ::time;
        attribute maintenanceThreshold : Real;
        attribute equipmentHealth : Real;
    }
    
    part def AnalyticsEngine {
        port dataInput : DataPort;
        
        attribute overallEfficiency : EfficiencyRating;
        attribute qualityTrend : Real;
        attribute productionForecast : ProductionRate;
        attribute energyConsumption :> ISQ::power;
    }
    
    part def AdaptiveController {
        port controlOutput : ControlPort;
        port analyticsInput : DataPort;
        
        attribute optimizationAlgorithm : String;
        attribute adaptationRate : Real;
        attribute targetEfficiency : EfficiencyRating;
    }
    
    action def MonitorProcessParameters {
        in sensorData : SensorPort;
        out currentTemp : TemperatureSetting;
        out currentPressure : PressureSetting;
        out currentVibration : VibrationAmplitude;
    }
    
    action def AnalyzePerformance {
        in temperature : TemperatureSetting;
        in pressure : PressureSetting;
        in vibration : VibrationAmplitude;
        in productionRate : ProductionRate;
        out efficiency : EfficiencyRating;
        out qualityPrediction : QualityMetric;
        out maintenanceNeeded : Boolean;
    }
    
    action def OptimizeParameters {
        in currentEfficiency : EfficiencyRating;
        in qualityPrediction : QualityMetric;
        out optimizedTemp : TemperatureSetting;
        out optimizedPressure : PressureSetting;
        out optimizedRate : ProductionRate;
    }
    
    action def ProcessRawMaterial {
        in material : RawMaterial;
        in processParams : String;
        out workpiece : WorkInProgress;
    }
    
    action def AssembleComponents {
        in workpiece : WorkInProgress;
        in assemblySequence : String;
        out assembledProduct : WorkInProgress;
    }
    
    action def InspectProduct {
        in product : WorkInProgress;
        out qualityScore : QualityMetric;
        out inspectionPassed : Boolean;
    }
    
    action def ScheduleMaintenance {
        in maintenanceType : String;
        in urgency : Real;
        out maintenanceScheduled : Boolean;
        out estimatedDowntime :> ISQ::time;
    }
    
    action def AdaptiveManufacturing {
        in rawMaterialBatch : RawMaterial[*];
        in targetRate : ProductionRate;
        in qualityTarget : QualityMetric;
        out finishedProducts : FinishedProduct[*];
        out achievedEfficiency : EfficiencyRating;
        
        private attribute currentEfficiency : EfficiencyRating := 0.75;
        private attribute producedItems : FinishedProduct[*] := ();
        private attribute wipItems : WorkInProgress[*] := ();
        
        first start;
        then accept startCmd : StartCommand;
        then merge operationLoop;
        
        action monitorSensors : MonitorProcessParameters {
            in sensorData;
            out currentTemp;
            out currentPressure;
            out currentVibration;
        }
        
        then action analyzeData : AnalyzePerformance {
            in temperature = monitorSensors.currentTemp;
            in pressure = monitorSensors.currentPressure;
            in vibration = monitorSensors.currentVibration;
            in productionRate = targetRate;
            out efficiency;
            out qualityPrediction;
            out maintenanceNeeded;
        }
        
        then decide;
            if analyzeData.maintenanceNeeded then performMaintenance;
            else continueProduction;
        
        action performMaintenance : ScheduleMaintenance {
            in maintenanceType = "Predictive";
            in urgency = 0.8;
            out maintenanceScheduled;
            out estimatedDowntime;
        }
        then continueProduction;
        
        action continueProduction;
        then action optimizeProcess : OptimizeParameters {
            in currentEfficiency = analyzeData.efficiency;
            in qualityPrediction = analyzeData.qualityPrediction;
            out optimizedTemp;
            out optimizedPressure;
            out optimizedRate;
        }
        
        then action processingPhase {
            for rawMaterial in rawMaterialBatch {
                action processStep : ProcessRawMaterial {
                    in material = rawMaterial;
                    in processParams = "optimized";
                    out workpiece;
                }
                
                then assign wipItems := wipItems->including(processStep.workpiece);
                
                then action assembleStep : AssembleComponents {
                    in workpiece = processStep.workpiece;
                    in assemblySequence = "standard";
                    out assembledProduct;
                }
                
                then action inspectStep : InspectProduct {
                    in product = assembleStep.assembledProduct;
                    out qualityScore;
                    out inspectionPassed;
                }
                
                then decide;
                    if inspectStep.inspectionPassed then acceptProduct;
                    else rejectProduct;
                
                action acceptProduct;
                then assign producedItems := producedItems->including(inspectStep.product);
                
                action rejectProduct;
            }
        }
        
        then assign currentEfficiency := analyzeData.efficiency;
        then assign finishedProducts := producedItems;
        then assign achievedEfficiency := currentEfficiency;
        
        then decide;
            if currentEfficiency >= 0.70 then operationLoop;
            else evaluateShutdown;
        
        action evaluateShutdown;
        accept stopCmd : StopCommand;
        then done;
    }
    
    state def ManufacturingLifecycle {
        entry; then systemIdle;
        
        state systemIdle {
            entry; 
        }
        accept StartCommand;
        then systemInitializing;
        
        state systemInitializing {
            entry; then loadConfiguration;
            
            state loadConfiguration;
            then calibrateSensors;
            
            state calibrateSensors;
            then verifyConnections;
            
            state verifyConnections;
        }
        then activeProduction;
        
        state activeProduction {
            entry; then monitoring;
            
            state monitoring {
                entry;
            }
            then analyzing;
            
            state analyzing {
                entry;
            }
            then decide;
                if maintenanceRequired then maintenanceMode;
                else processing;
            
            state maintenanceMode {
                entry;
            }
            then processing;
            
            state processing {
                entry;
            }
            then qualityCheck;
            
            state qualityCheck {
                entry;
            }
            then decide;
                if qualityAcceptable then optimization;
                else parameterAdjustment;
            
            state parameterAdjustment {
                entry;
            }
            then monitoring;
            
            state optimization {
                entry;
            }
            then monitoring;
        }
        
        accept StopCommand;
        then systemShutdown;
        
        state systemShutdown {
            entry; then safeStop;
            
            state safeStop;
            then dataArchival;
            
            state dataArchival;
        }
        then done;
    }
    
    part def SmartManufacturingSystem {
        part processingStations : ProcessingStation[4];
        part assemblyRobots : AssemblyRobot[2];
        part sensors : SensorModule[6];
        part qualityInspection : QualityInspectionStation;
        part predictiveMaintenance : PredictiveMaintenanceModule;
        part analytics : AnalyticsEngine;
        part adaptiveControl : AdaptiveController;
    }
    
    part smartFactory : SmartManufacturingSystem {
        
        connection sensorToStation1 : SensorPort
            connect sensors[1].sensorOutput to processingStations[1].sensorInterface;
        
        connection sensorToStation2 : SensorPort
            connect sensors[2].sensorOutput to processingStations[2].sensorInterface;
        
        connection station1ToRobot : MaterialFlowPort
            connect processingStations[1].materialOutput to assemblyRobots[1].workInput;
        
        connection robotToInspection : MaterialFlowPort
            connect assemblyRobots[1].workOutput to qualityInspection.productInput;
        
        connection sensorToMaintenance : SensorPort
            connect sensors[3].sensorOutput to predictiveMaintenance.sensorData;
        
        perform state manufacturingState : ManufacturingLifecycle;
        
        perform action manufacturing : AdaptiveManufacturing[*] ordered;
    }
    
    requirement def ProductionEfficiencyRequirement {
        doc /* The smart manufacturing system shall maintain production efficiency above the specified threshold during normal operations. */
        
        subject factory : SmartManufacturingSystem;
        
        attribute minEfficiency : EfficiencyRating;
        
        require constraint {
            factory.analytics.overallEfficiency >= minEfficiency
        }
    }
    
    requirement def QualityAssuranceRequirement {
        doc /* All finished products shall meet or exceed the minimum quality score threshold. */
        
        subject inspection : QualityInspectionStation;
        
        attribute minQualityScore : QualityMetric;
        
        require constraint {
            inspection.inspectionCriteria >= minQualityScore
        }
    }
    
    requirement def PredictiveMaintenanceRequirement {
        doc /* The system shall predict equipment failures and schedule maintenance with sufficient advance notice to minimize unplanned downtime. */
        
        subject maintenance : PredictiveMaintenanceModule;
        
        attribute minPredictionHorizon :> ISQ::time;
        
        require constraint {
            maintenance.failurePredictionHorizon >= minPredictionHorizon
        }
    }
    
    requirement def AdaptiveOptimizationRequirement {
        doc /* The system shall continuously optimize production parameters to maximize efficiency while maintaining quality standards. */
        
        subject controller : AdaptiveController;
        
        require constraint {
            controller.targetEfficiency >= 0.85
        }
    }
    
    requirement <'SMF-MAIN-001'> smartManufacturingMission {
        doc /* The smart manufacturing system shall autonomously orchestrate production processes through continuous monitoring, 
             real-time analytics, predictive maintenance, and adaptive optimization to maximize operational efficiency, 
             ensure consistent product quality, and minimize downtime while responding dynamically to changing conditions. */
        
        subject smartFactory;
        
        assume constraint validMaterialSupply {
            doc /* Raw materials are available and meet specification requirements. */
        }
        
        assume constraint calibratedEquipment {
            doc /* All sensors, actuators, and processing equipment are properly calibrated and operational. */
        }
        
        assume constraint networkConnectivity {
            doc /* Communication network between system components is reliable and secure. */
        }
        
        require productionEfficiency : ProductionEfficiencyRequirement {
            subject = smartFactory;
            minEfficiency = 0.85;
        }
        
        require qualityAssurance : QualityAssuranceRequirement {
            subject = smartFactory.qualityInspection;
            minQualityScore = 95.0;
        }
        
        require predictiveMaintenance : PredictiveMaintenanceRequirement {
            subject = smartFactory.predictiveMaintenance;
            minPredictionHorizon = 24.0;
        }
        
        require adaptiveOptimization : AdaptiveOptimizationRequirement {
            subject = smartFactory.adaptiveControl;
        }
    }
}
