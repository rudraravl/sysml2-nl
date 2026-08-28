package 'Smart Adaptive Manufacturing System' {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def StartCommand;
	attribute def StopCommand;
	attribute def EmergencyStop;
	attribute def CalibrationComplete;
	attribute def MaintenanceRequest;
	attribute def ReturnToNormal;
	attribute def ResetComplete;
	attribute def OptimizationTrigger;

	attribute def StationId :> String;
	attribute def ComponentId :> String;

	value def TemperatureValue :> Real;
	value def PressureValue :> Real;
	value def VibrationValue :> Real;
	value def SpeedValue :> Real;
	value def TorqueValue :> Real;
	value def EfficiencyValue :> Real;
	value def ProductionRateValue :> Real;
	value def DurationValue :> Real;

	item def SensorReading {
		attribute stationId : StationId;
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
		attribute vibration : VibrationValue;
	}

	item def ProductionMetrics {
		attribute throughput : ProductionRateValue;
		attribute efficiency : EfficiencyValue;
		attribute qualityYield : EfficiencyValue;
		attribute defectRate : EfficiencyValue;
	}

	item def HealthReport {
		attribute componentId : ComponentId;
		attribute healthScore : EfficiencyValue;
		attribute remainingUsefulLife : DurationValue;
		attribute riskLevel : Integer;
	}

	item def ControlAdjustment {
		attribute targetStation : StationId;
		attribute speedSetting : SpeedValue;
		attribute temperatureSetting : TemperatureValue;
		attribute torqueSetting : TorqueValue;
	}

	item def MaintenanceAlert {
		attribute componentId : ComponentId;
		attribute severity : Integer;
		attribute recommendedAction : String;
	}

	item def RawMaterial;
	item def ProcessedPart;
	item def AssembledProduct;
	item def ConformingProduct :> AssembledProduct;
	item def NonConformingProduct :> AssembledProduct;

	action def 'Initialize System';
	action def 'Calibrate Sensors';
	action def 'Perform Safety Checks';
	action def 'Monitor Operation';
	action def 'Execute Production Cycle';
	action def 'Process Raw Material' {
		in material : RawMaterial;
		out processedPart : ProcessedPart;
	}
	action def 'Assemble Components' {
		in processedPart : ProcessedPart;
		out product : AssembledProduct;
	}
	action def 'Inspect Product' {
		in product : AssembledProduct;
		out conforming : ConformingProduct;
		out nonConforming : NonConformingProduct;
	}
	action def 'Sense Operational Parameters' {
		out reading : SensorReading;
	}
	action def 'Analyze Production Data' {
		in readings : SensorReading;
		out metrics : ProductionMetrics;
	}
	action def 'Predict Equipment Health' {
		in readings : SensorReading;
		out report : HealthReport;
		out alert : MaintenanceAlert;
	}
	action def 'Adjust Process Parameters' {
		in metrics : ProductionMetrics;
		in report : HealthReport;
		out adjustment : ControlAdjustment;
	}
	action def 'Execute Maintenance' {
		in alert : MaintenanceAlert;
	}

	part def ProcessingStation {
		port materialInPort { in material : RawMaterial; }
		port partOutPort { out processedPart : ProcessedPart; }
		port controlInPort { in adjustment : ControlAdjustment; }
		port sensorDataPort { out reading : SensorReading; }
		attribute stationId : StationId;
		attribute targetTemperature : TemperatureValue;
		attribute targetPressure : PressureValue;
		perform action 'process material' : 'Process Raw Material';
	}

	part def AssemblyRobot {
		port partInPort { in processedPart : ProcessedPart; }
		port productOutPort { out product : AssembledProduct; }
		port controlInPort { in adjustment : ControlAdjustment; }
		port sensorDataPort { out reading : SensorReading; }
		attribute robotId : StationId;
		attribute targetSpeed : SpeedValue;
		attribute targetTorque : TorqueValue;
		perform action 'assemble' : 'Assemble Components';
	}

	part def QualityInspectionStation {
		port productInPort { in product : AssembledProduct; }
		port conformingOutPort { out product : ConformingProduct; }
		port nonConformingOutPort { out product : NonConformingProduct; }
		port sensorDataPort { out reading : SensorReading; }
		attribute inspectionId : StationId;
		perform action 'inspect' : 'Inspect Product';
	}

	part def SensorModule {
		port readingOutPort { out reading : SensorReading; }
		attribute stationId : StationId;
		attribute samplingRate : Real;
		perform action 'sense' : 'Sense Operational Parameters';
	}

	part def AnalyticsEngine {
		port sensorDataInPort { in reading : SensorReading; }
		port metricsOutPort { out metrics : ProductionMetrics; }
		attribute calculationInterval : DurationValue;
		attribute currentEfficiency : EfficiencyValue;
		attribute currentQuality : EfficiencyValue;
		perform action 'analyze' : 'Analyze Production Data';
	}

	part def PredictiveMaintenanceModule {
		port sensorDataInPort { in reading : SensorReading; }
		port healthOutPort { out report : HealthReport; }
		port alertOutPort { out alert : MaintenanceAlert; }
		attribute warningThreshold : EfficiencyValue;
		attribute criticalThreshold : EfficiencyValue;
		attribute currentHealthScore : EfficiencyValue;
		perform action 'predict' : 'Predict Equipment Health';
	}

	part def AdaptiveController {
		port metricsInPort { in metrics : ProductionMetrics; }
		port healthInPort { in report : HealthReport; }
		port alertInPort { in alert : MaintenanceAlert; }
		port adjustmentOutPort { out adjustment : ControlAdjustment; }
		attribute optimizationTarget : EfficiencyValue;
		attribute qualityTarget : EfficiencyValue;
		perform action 'adjust' : 'Adjust Process Parameters';
	}

	part def SmartManufacturingSystem {
		port materialInPort { in material : RawMaterial; }
		port productOutPort { out product : ConformingProduct; }

		part station1 : ProcessingStation {
			attribute stationId = "PS-01";
			attribute targetTemperature = 350.0;
			attribute targetPressure = 1500000.0;
		}
		part station2 : ProcessingStation {
			attribute stationId = "PS-02";
			attribute targetTemperature = 280.0;
			attribute targetPressure = 1200000.0;
		}
		part robot1 : AssemblyRobot {
			attribute robotId = "AR-01";
			attribute targetSpeed = 0.5;
			attribute targetTorque = 25.0;
		}
		part robot2 : AssemblyRobot {
			attribute robotId = "AR-02";
			attribute targetSpeed = 0.5;
			attribute targetTorque = 25.0;
		}
		part qualityStation : QualityInspectionStation {
			attribute inspectionId = "QS-01";
		}
		part sensor1 : SensorModule {
			attribute stationId = "PS-01";
			attribute samplingRate = 10.0;
		}
		part sensor2 : SensorModule {
			attribute stationId = "PS-02";
			attribute samplingRate = 10.0;
		}
		part sensor3 : SensorModule {
			attribute stationId = "AR-01";
			attribute samplingRate = 20.0;
		}
		part sensor4 : SensorModule {
			attribute stationId = "AR-02";
			attribute samplingRate = 20.0;
		}
		part sensor5 : SensorModule {
			attribute stationId = "QS-01";
			attribute samplingRate = 5.0;
		}
		part analytics : AnalyticsEngine {
			attribute calculationInterval = 1.0;
			attribute currentEfficiency = 85.0;
			attribute currentQuality = 98.0;
		}
		part maintenanceModule : PredictiveMaintenanceModule {
			attribute warningThreshold = 70.0;
			attribute criticalThreshold = 30.0;
			attribute currentHealthScore = 95.0;
		}
		part controller : AdaptiveController {
			attribute optimizationTarget = 85.0;
			attribute qualityTarget = 98.0;
		}

		flow rawMaterialFlow1 of RawMaterial
			from materialInPort.material to station1.materialInPort.material;
		flow rawMaterialFlow2 of RawMaterial
			from materialInPort.material to station2.materialInPort.material;
		flow partFlow1 of ProcessedPart
			from station1.partOutPort.processedPart to robot1.partInPort.processedPart;
		flow partFlow2 of ProcessedPart
			from station2.partOutPort.processedPart to robot2.partInPort.processedPart;
		flow productFlow1 of AssembledProduct
			from robot1.productOutPort.product to qualityStation.productInPort.product;
		flow productFlow2 of AssembledProduct
			from robot2.productOutPort.product to qualityStation.productInPort.product;
		flow conformingProductFlow of ConformingProduct
			from qualityStation.conformingOutPort.product to productOutPort.product;

		flow sensorFlowA1 of SensorReading
			from sensor1.readingOutPort.reading to analytics.sensorDataInPort.reading;
		flow sensorFlowA2 of SensorReading
			from sensor2.readingOutPort.reading to analytics.sensorDataInPort.reading;
		flow sensorFlowA3 of SensorReading
			from sensor3.readingOutPort.reading to analytics.sensorDataInPort.reading;
		flow sensorFlowA4 of SensorReading
			from sensor4.readingOutPort.reading to analytics.sensorDataInPort.reading;
		flow sensorFlowA5 of SensorReading
			from sensor5.readingOutPort.reading to analytics.sensorDataInPort.reading;

		flow sensorFlowM1 of SensorReading
			from sensor1.readingOutPort.reading to maintenanceModule.sensorDataInPort.reading;
		flow sensorFlowM2 of SensorReading
			from sensor2.readingOutPort.reading to maintenanceModule.sensorDataInPort.reading;
		flow sensorFlowM3 of SensorReading
			from sensor3.readingOutPort.reading to maintenanceModule.sensorDataInPort.reading;
		flow sensorFlowM4 of SensorReading
			from sensor4.readingOutPort.reading to maintenanceModule.sensorDataInPort.reading;
		flow sensorFlowM5 of SensorReading
			from sensor5.readingOutPort.reading to maintenanceModule.sensorDataInPort.reading;

		flow stationSensorFlow1 of SensorReading
			from station1.sensorDataPort.reading to analytics.sensorDataInPort.reading;
		flow stationSensorFlow2 of SensorReading
			from station2.sensorDataPort.reading to analytics.sensorDataInPort.reading;
		flow stationSensorFlow3 of SensorReading
			from robot1.sensorDataPort.reading to analytics.sensorDataInPort.reading;
		flow stationSensorFlow4 of SensorReading
			from robot2.sensorDataPort.reading to analytics.sensorDataInPort.reading;
		flow stationSensorFlow5 of SensorReading
			from qualityStation.sensorDataPort.reading to analytics.sensorDataInPort.reading;

		flow stationHealthFlow1 of SensorReading
			from station1.sensorDataPort.reading to maintenanceModule.sensorDataInPort.reading;
		flow stationHealthFlow2 of SensorReading
			from station2.sensorDataPort.reading to maintenanceModule.sensorDataInPort.reading;
		flow stationHealthFlow3 of SensorReading
			from robot1.sensorDataPort.reading to maintenanceModule.sensorDataInPort.reading;
		flow stationHealthFlow4 of SensorReading
			from robot2.sensorDataPort.reading to maintenanceModule.sensorDataInPort.reading;
		flow stationHealthFlow5 of SensorReading
			from qualityStation.sensorDataPort.reading to maintenanceModule.sensorDataInPort.reading;

		flow metricsFlow of ProductionMetrics
			from analytics.metricsOutPort.metrics to controller.metricsInPort.metrics;
		flow healthFlow of HealthReport
			from maintenanceModule.healthOutPort.report to controller.healthInPort.report;
		flow alertFlow of MaintenanceAlert
			from maintenanceModule.alertOutPort.alert to controller.alertInPort.alert;

		flow controlFlow1 of ControlAdjustment
			from controller.adjustmentOutPort.adjustment to station1.controlInPort.adjustment;
		flow controlFlow2 of ControlAdjustment
			from controller.adjustmentOutPort.adjustment to station2.controlInPort.adjustment;
		flow controlFlow3 of ControlAdjustment
			from controller.adjustmentOutPort.adjustment to robot1.controlInPort.adjustment;
		flow controlFlow4 of ControlAdjustment
			from controller.adjustmentOutPort.adjustment to robot2.controlInPort.adjustment;

		action 'initialize system' : 'Initialize System';
		action 'calibrate sensors' : 'Calibrate Sensors';
		action 'perform safety checks' : 'Perform Safety Checks';
		action 'monitor operation' : 'Monitor Operation';
		action 'execute production cycle' : 'Execute Production Cycle';

		exhibit state 'system states' parallel {
			state 'operational states' {
				entry; then idle;
				state idle;
				accept StartCommand
					then initializing;
				state initializing {
					do 'initialize system';
				}
				accept ResetComplete
					then calibrating;
				state calibrating {
					do 'calibrate sensors';
				}
				accept CalibrationComplete
					then active;
				state active {
					entry 'monitor operation';
					do 'execute production cycle';
					exit 'perform safety checks';
				}
				accept StopCommand
					then idle;
			}
			state 'health states' {
				entry; then normal;
				state normal;
				accept when maintenanceModule.currentHealthScore < maintenanceModule.warningThreshold
					do send new MaintenanceRequest() to controller
					then warning;
				state warning;
				accept when maintenanceModule.currentHealthScore < maintenanceModule.criticalThreshold
					then degraded;
				accept ReturnToNormal
					then normal;
				state degraded;
				accept EmergencyStop
					then faulted;
				accept ReturnToNormal
					then normal;
				state faulted;
				accept ResetComplete
					then normal;
			}
			state 'production cycle states' {
				entry; then monitoring;
				state monitoring {
					do 'monitor operation';
				}
				accept OptimizationTrigger
					then analyzing;
				state analyzing;
				accept when analytics.currentEfficiency < controller.optimizationTarget
					then adjusting;
				accept when analytics.currentQuality < controller.qualityTarget
					then adjusting;
				state adjusting;
				accept when analytics.currentEfficiency >= controller.optimizationTarget
					then monitoring;
			}
		}
	}

	requirement def 'Production Throughput' {
		doc /* The system shall sustain a minimum production throughput of 100 units per hour during active operation. */
	}
	requirement def 'Quality Threshold' {
		doc /* The system shall maintain a quality yield of at least 98 percent conforming products. */
	}
	requirement def 'System Availability' {
		doc /* The system shall achieve 99.5 percent uptime over a 30-day operational window and recover autonomously from faults. */
	}
	requirement def 'Autonomous Operation' {
		doc /* The system shall operate without operator intervention during the active production phase. */
	}
	requirement def 'Predictive Maintenance Capability' {
		doc /* The system shall predict equipment failures and schedule maintenance proactively before unplanned downtime occurs. */
	}
	requirement def 'Adaptive Control' {
		doc /* The adaptive controller shall continuously adjust station parameters based on real-time analytics and health data. */
	}

	part 'manufacturing system' : SmartManufacturingSystem;
}
