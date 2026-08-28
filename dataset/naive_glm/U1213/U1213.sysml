package SmartAdaptiveManufacturingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----

    value def TemperatureValue :> Real { unit 'C'; }
    value def PressureValue :> Real { unit 'bar'; }
    value def VibrationValue :> Real { unit 'mm/s'; }
    value def SpeedValue :> Real { unit 'rpm'; }
    value def TorqueValue :> Real { unit 'N*m'; }
    value def EfficiencyValue :> Real { unit '%'; }
    value def ProductionRateValue :> Real { unit 'units/h'; }
    value def DimensionlessValue :> Real { unit '1'; }

    // ---- Items ----

    item def RawMaterial {
        attribute materialId : String;
        attribute batchNumber : String;
        attribute mass : MassValue;
    }

    item def PartiallyFinishedItem {
        attribute itemId : String;
        attribute stage : String;
        attribute temperature : TemperatureValue;
    }

    item def FinishedProduct {
        attribute serialNumber : String;
        attribute qualityGrade : String;
        attribute pass : Boolean;
    }

    item def SensorData {
        attribute sensorId : String;
        attribute timestamp : DateTime;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute vibration : VibrationValue;
    }

    item def ProductionMetrics {
        attribute throughput : ProductionRateValue;
        attribute defectRate : EfficiencyValue;
        attribute oee : EfficiencyValue;
    }

    item def MaintenanceAlert {
        attribute equipmentId : String;
        attribute severity : String;
        attribute predictedFailureTime : DateTime;
        attribute recommendedAction : String;
    }

    item def ControlCommand {
        attribute targetStationId : String;
        attribute newSpeed : SpeedValue;
        attribute newTemperature : TemperatureValue;
        attribute newTorque : TorqueValue;
    }

    // ---- Port Definitions ----

    port def MaterialInPort { in item : RawMaterial; }
    port def PartialItemInPort { in item : PartiallyFinishedItem; }
    port def PartialItemOutPort { out item : PartiallyFinishedItem; }
    port def ProductOutPort { out item : FinishedProduct; }
    port def ProductInPort { in item : FinishedProduct; }

    port def SensorDataOutPort { out item : SensorData; }
    port def SensorDataInPort { in item : SensorData; }

    port def MetricsOutPort { out item : ProductionMetrics; }
    port def MetricsInPort { in item : ProductionMetrics; }

    port def AlertOutPort { out item : MaintenanceAlert; }
    port def AlertInPort { in item : MaintenanceAlert; }

    port def CommandOutPort { out item : ControlCommand; }
    port def CommandInPort { in item : ControlCommand; }

    // ---- Parts ----

    part def ProcessingStation {
        attribute stationId : String;
        port materialIn : MaterialInPort;
        port partialOut : PartialItemOutPort;
        port sensorOut : SensorDataOutPort;
        port commandIn : CommandInPort;

        attribute currentSpeed : SpeedValue = 1500;
        attribute currentTemperature : TemperatureValue = 75.0;
        attribute currentPressure : PressureValue = 2.5;
        attribute currentVibration : VibrationValue = 1.2;

        action def ProcessMaterial {
            in material : RawMaterial;
            out partial : PartiallyFinishedItem;
        }

        perform processMaterial : ProcessMaterial;

        action def EmitSensorData {
            out data : SensorData;
        }

        perform emitSensorData : EmitSensorData;

        action def ApplyControlCommand {
            in command : ControlCommand;
        }

        perform applyCommand : ApplyControlCommand;
    }

    part def AssemblyRobot {
        attribute robotId : String;
        port partialIn : PartialItemInPort;
        port partialOut : PartialItemOutPort;
        port sensorOut : SensorDataOutPort;
        port commandIn : CommandInPort;

        attribute currentTorque : TorqueValue = 12.0;
        attribute currentSpeed : SpeedValue = 800;
        attribute currentVibration : VibrationValue = 0.8;

        action def AssembleComponents {
            in partials : PartiallyFinishedItem[2..*];
            out assembled : PartiallyFinishedItem;
        }

        perform assemble : AssembleComponents;
    }

    part def QualityInspectionStation {
        attribute stationId : String;
        port productIn : PartialItemInPort;
        port productOut : ProductOutPort;
        port sensorOut : SensorDataOutPort;
        port metricsOut : MetricsOutPort;

        action def InspectProduct {
            in item : PartiallyFinishedItem;
            out product : FinishedProduct;
        }

        perform inspect : InspectProduct;
    }

    part def SensorModule {
        attribute sensorId : String;
        attribute location : String;
        port dataOut : SensorDataOutPort;

        action def Measure {
            out data : SensorData;
        }

        perform measure : Measure;
    }

    part def AnalyticsEngine {
        port sensorDataIn : SensorDataInPort;
        port metricsIn : MetricsInPort;
        port metricsOut : MetricsOutPort;

        attribute calculatedOEE : EfficiencyValue = 0.0;
        attribute forecastedRate : ProductionRateValue = 0.0;
        attribute qualityTrend : DimensionlessValue = 0.0;

        action def AnalyzeData {
            in sensorData : SensorData;
            in metrics : ProductionMetrics;
            out updatedMetrics : ProductionMetrics;
        }

        perform analyze : AnalyzeData;
    }

    part def PredictiveMaintenanceModule {
        port sensorDataIn : SensorDataInPort;
        port alertOut : AlertOutPort;

        attribute equipmentHealth : DimensionlessValue = 1.0;
        attribute predictedFailures : MaintenanceAlert[*];

        action def PredictFailure {
            in sensorData : SensorData;
            out alert : MaintenanceAlert;
        }

        perform predict : PredictFailure;
    }

    part def AdaptiveController {
        port metricsIn : MetricsInPort;
        port alertIn : AlertInPort;
        port commandOut : CommandOutPort;

        attribute optimizationActive : Boolean = true;
        attribute targetOEE : EfficiencyValue = 90.0;
        attribute targetQuality : EfficiencyValue = 99.0;

        action def ComputeControlCommand {
            in metrics : ProductionMetrics;
            in alert : MaintenanceAlert;
            out command : ControlCommand;
        }

        perform compute : ComputeControlCommand;
    }

    // ---- System ----

    part def SmartManufacturingSystem {

        port rawMaterialIn : MaterialInPort;
        port finishedProductOut : ProductOutPort;

        part processingStations : ProcessingStation[3] {
            part station1 : ProcessingStation { stationId = "PS-1"; }
            part station2 : ProcessingStation { stationId = "PS-2"; }
            part station3 : ProcessingStation { stationId = "PS-3"; }
        }

        part assemblyRobots : AssemblyRobot[2] {
            part robot1 : AssemblyRobot { robotId = "AR-1"; }
            part robot2 : AssemblyRobot { robotId = "AR-2"; }
        }

        part inspectionStation : QualityInspectionStation {
            stationId = "QI-1";
        }

        part sensors : SensorModule[8];

        part analyticsEngine : AnalyticsEngine;
        part maintenanceModule : PredictiveMaintenanceModule;
        part adaptiveController : AdaptiveController;

        // Connections - material flow
        connection rawToStation1 : RawMaterial connect rawMaterialIn to processingStations.station1.materialIn;
        connection station1ToStation2 : PartiallyFinishedItem connect processingStations.station1.partialOut to processingStations.station2.materialIn;
        connection station2ToStation3 : PartiallyFinishedItem connect processingStations.station2.partialOut to processingStations.station3.materialIn;
        connection station3ToRobot1 : PartiallyFinishedItem connect processingStations.station3.partialOut to assemblyRobots.robot1.partialIn;
        connection robot1ToRobot2 : PartiallyFinishedItem connect assemblyRobots.robot1.partialOut to assemblyRobots.robot2.partialIn;
        connection robot2ToInspection : PartiallyFinishedItem connect assemblyRobots.robot2.partialOut to inspectionStation.productIn;
        connection inspectionToOut : FinishedProduct connect inspectionStation.productOut to finishedProductOut;

        // Connections - sensor data flow
        connection station1SensorData : SensorData connect processingStations.station1.sensorOut to analyticsEngine.sensorDataIn;
        connection station2SensorData : SensorData connect processingStations.station2.sensorOut to analyticsEngine.sensorDataIn;
        connection station3SensorData : SensorData connect processingStations.station3.sensorOut to analyticsEngine.sensorDataIn;
        connection robot1SensorData : SensorData connect assemblyRobots.robot1.sensorOut to analyticsEngine.sensorDataIn;
        connection robot2SensorData : SensorData connect assemblyRobots.robot2.sensorOut to analyticsEngine.sensorDataIn;
        connection inspectionSensorData : SensorData connect inspectionStation.sensorOut to analyticsEngine.sensorDataIn;

        connection station1SensorToMaintenance : SensorData connect processingStations.station1.sensorOut to maintenanceModule.sensorDataIn;
        connection station2SensorToMaintenance : SensorData connect processingStations.station2.sensorOut to maintenanceModule.sensorDataIn;
        connection station3SensorToMaintenance : SensorData connect processingStations.station3.sensorOut to maintenanceModule.sensorDataIn;
        connection robot1SensorToMaintenance : SensorData connect assemblyRobots.robot1.sensorOut to maintenanceModule.sensorDataIn;
        connection robot2SensorToMaintenance : SensorData connect assemblyRobots.robot2.sensorOut to maintenanceModule.sensorDataIn;

        // Connections - metrics flow
        connection inspectionMetrics : ProductionMetrics connect inspectionStation.metricsOut to analyticsEngine.metricsIn;
        connection analyticsMetricsToController : ProductionMetrics connect analyticsEngine.metricsOut to adaptiveController.metricsIn;

        // Connections - alert flow
        connection alertToController : MaintenanceAlert connect maintenanceModule.alertOut to adaptiveController.alertIn;

        // Connections - control commands
        connection commandToStation1 : ControlCommand connect adaptiveController.commandOut to processingStations.station1.commandIn;
        connection commandToStation2 : ControlCommand connect adaptiveController.commandOut to processingStations.station2.commandIn;
        connection commandToStation3 : ControlCommand connect adaptiveController.commandOut to processingStations.station3.commandIn;
        connection commandToRobot1 : ControlCommand connect adaptiveController.commandOut to assemblyRobots.robot1.commandIn;
        connection commandToRobot2 : ControlCommand connect adaptiveController.commandOut to assemblyRobots.robot2.commandIn;

        // ---- Lifecycle State Machine ----

        attribute startCommandReceived : Boolean = false;
        attribute maintenanceAlertActive : Boolean = false;
        attribute currentOEE : EfficiencyValue = 0.0;
        attribute currentQuality : EfficiencyValue = 0.0;

        state def ManufacturingLifecycle {

            entry action {
                startCommandReceived = false;
            }

            state idle {
                entry action {
                    currentOEE = 0.0;
                    currentQuality = 0.0;
                }
                transition idle_to_initializing
                    first idle
                    then initializing
                    when startCommandReceived == true;
            }

            state initializing {
                entry action {
                    // Calibrate sensors and stations
                    processingStations.station1.currentSpeed = 1500;
                    processingStations.station2.currentSpeed = 1500;
                    processingStations.station3.currentSpeed = 1500;
                    assemblyRobots.robot1.currentTorque = 12.0;
                    assemblyRobots.robot2.currentTorque = 12.0;
                }
                do action {
                    // Perform calibration sequence
                }
                transition initializing_to_producing
                    first initializing
                    then producing;
            }

            state producing {

                entry action {
                    maintenanceAlertActive = false;
                }

                parallel monitoring {
                    state collectingSensorData {
                        do action {
                            // Continuously collect sensor data from all stations
                        }
                    }
                }

                parallel analysis {
                    state analyzingData {
                        do action {
                            // AnalyticsEngine processes sensor data and metrics
                            // PredictiveMaintenanceModule evaluates equipment health
                        }
                    }
                }

                parallel processing {
                    state manufacturingGoods {
                        do action {
                            // Processing stations transform raw materials
                            // Assembly robots assemble components
                        }
                    }
                }

                parallel qualityControl {
                    state inspectingProducts {
                        do action {
                            // QualityInspectionStation verifies finished products
                        }
                    }
                }

                transition producing_to_optimizing
                    first producing
                    then optimizing
                    when currentOEE < adaptiveController.targetOEE;

                transition producing_to_alerting
                    first producing
                    then maintenanceAlerted
                    when maintenanceAlertActive == true;

                transition producing_to_idle
                    first producing
                    then idle
                    when startCommandReceived == false;
            }

            state optimizing {
                entry action {
                    // AdaptiveController computes new parameters
                    // Commands dispatched to stations and robots
                }
                do action {
                    // Apply optimized speed, temperature, torque settings
                }
                transition optimizing_to_producing
                    first optimizing
                    then producing;
            }

            state maintenanceAlerted {
                entry action {
                    // Maintenance alert triggered by predictive module
                }
                do action {
                    // Schedule maintenance proactively
                    // Reduce load on affected equipment
                }
                transition maintenanceAlerted_to_producing
                    first maintenanceAlerted
                    then producing
                    when maintenanceAlertActive == false;
            }

            transition final_to_idle
                first maintenanceAlerted
                then idle
                when startCommandReceived == false;
        }

        exhibit behavior lifecycle : ManufacturingLifecycle;
    }

    // ---- Requirements ----

    requirement def ProductionLineRequirement {
        subject : SmartManufacturingSystem;
        objective {
            doc "The system shall autonomously produce finished goods from raw materials through processing, assembly, and inspection."
        }
    }

    requirement def QualityControlRequirement {
        subject : SmartManufacturingSystem;
        attribute minQualityGrade : EfficiencyValue = 99.0;
        objective {
            doc "The system shall inspect all finished products and maintain a quality rate of at least 99%."
        }
    }

    requirement def RealTimeOptimizationRequirement {
        subject : SmartManufacturingSystem;
        attribute targetOEE : EfficiencyValue = 90.0;
        objective {
            doc "The AdaptiveController shall continuously adjust processing station and robot parameters to maintain OEE at or above 90%."
        }
    }

    requirement def PredictiveMaintenanceRequirement {
        subject : SmartManufacturingSystem;
        objective {
            doc "The Predictive Maintenance Module shall anticipate equipment failures based on sensor data and issue maintenance alerts before unplanned downtime occurs."
        }
    }

    requirement def AutonomousOperationRequirement {
        subject : SmartManufacturingSystem;
        objective {
            doc "The system shall operate autonomously through idle, initialization, production, optimization, and maintenance alert states without human intervention."
        }
    }

    requirement def SensorMonitoringRequirement {
        subject : SmartManufacturingSystem;
        attribute sensorCountMin : Integer = 8;
        objective {
            doc "The system shall deploy sensor modules throughout the production line measuring temperature, pressure, and vibration of equipment."
        }
    }

    requirement productionLineReq : ProductionLineRequirement {
        subject = SmartManufacturingSystem;
    }

    requirement qualityControlReq : QualityControlRequirement {
        subject = SmartManufacturingSystem;
    }

    requirement optimizationReq : RealTimeOptimizationRequirement {
        subject = SmartManufacturingSystem;
    }

    requirement maintenanceReq : PredictiveMaintenanceRequirement {
        subject = SmartManufacturingSystem;
    }

    requirement autonomousReq : AutonomousOperationRequirement {
        subject = SmartManufacturingSystem;
    }

    requirement sensorReq : SensorMonitoringRequirement {
        subject = SmartManufacturingSystem;
    }

    satisfaction satisfyProductionLine : productionLineReq by SmartManufacturingSystem;
    satisfaction satisfyQualityControl : qualityControlReq by SmartManufacturingSystem;
    satisfaction satisfyOptimization : optimizationReq by SmartManufacturingSystem;
    satisfaction satisfyMaintenance : maintenanceReq by SmartManufacturingSystem;
    satisfaction satisfyAutonomous : autonomousReq by SmartManufacturingSystem;
    satisfaction satisfySensing : sensorReq by SmartManufacturingSystem;

}
