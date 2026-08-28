package VehicleManufacturingPlant {
	import ScalarValues::*;
	import ISQ::*;
	
	// ===== Value Types =====
	
	item def SteelSheet {
		attribute thickness : MassDensity;
		attribute area : Area;
		attribute mass : Mass;
	}
	
	item def Powertrain {
		attribute engineType : String;
		attribute power : Power;
		attribute torque : Torque;
		attribute mass : Mass;
	}
	
	item def BodyPanel {
		attribute panelType : String;
		attribute length : Length;
		attribute width : Length;
		attribute mass : Mass;
	}
	
	item def VehicleChassis {
		attribute weldPointsCount : Integer;
		attribute mass : Mass;
	}
	
	item def PaintedBody {
		attribute colorCode : String;
		attribute coatThickness : Length;
	}
	
	item def AssembledVehicle {
		attribute vin : String;
		attribute colorCode : String;
		attribute totalMass : Mass;
	}
	
	item def FinishedVehicle {
		attribute vin : String;
		attribute qualityScore : Real;
	}
	
	item def ProductionOrder {
		attribute orderId : String;
		attribute modelType : String;
		attribute targetColor : String;
		attribute quantity : Integer;
	}
	
	// ===== Requirements =====
	
	requirement def ProductionTargetRequirement {
		doc ## The plant must meet defined daily production targets.
		subject thePlant : VehicleManufacturingPlant;
		requirement dailyProductionRate : Real = 400 [units: "vehicle/day"];
		requirement minQualityScore : Real = 0.95;
		requirement minEfficiency : Real = 0.85;
	}
	
	requirement def QualityApprovalRequirement {
		doc ## Vehicles must meet the minimum quality score to be shipped.
		subject theVehicle : FinishedVehicle;
		requirement thresholdQuality : Real = 0.95;
		constraint { theVehicle.qualityScore >= 0.95 }
	}
	
	requirement def StampingThroughputRequirement {
		doc ## Each press must produce a minimum number of panels per hour.
		subject thePress : StampingPress;
		requirement minPanelsPerHour : Real = 80 [units: "panel/h"];
	}
	
	requirement def PaintBoothRequirement {
		doc ## Paint booths must maintain controlled environment conditions.
		subject theBooth : PaintBooth;
		requirement temperatureRange : TemperatureInterval = (18..25) [K];
		requirement humidityRange : Real = (30..55) [%];
	}
	
	requirement def PlantOperationalRequirement {
		doc ## The plant must operate in well-defined states.
		subject thePlant : VehicleManufacturingPlant;
		requirement shiftDuration : Time = 8 [h];
		requirement maintenanceCycle : Time = 720 [h];
	}
	
	// ===== Common Definitions =====
	
	part def ProductionLinePort {
		port in item flow materialIn : Any;
		port out item flow materialOut : Any;
	}
	
	port def MaterialPort {
		in item material : Any;
		out item processedMaterial : Any;
	}
	
	item flow def MaterialFlow {
		end : MaterialPort;
	}
	
	// ===== Stamping Department =====
	
	part def StampingPress {
		attribute pressId : String;
		attribute maxForce : Force = 2000 [kN];
		attribute strokeRate : Real = 60 [1/min];
		attribute throughput : Real = 80 [units: "panel/h"];
		
		port in item flow steelIn : SteelSheet;
		port out item flow panelOut : BodyPanel;
		
		action stampSheet {
			in sheet : SteelSheet;
			out panel : BodyPanel;
		}
	}
	
	part def StampingDepartment {
		attribute departmentId : String = "STAMPING-01";
		attribute pressCount : Integer = 6;
		attribute capacity : Real = 480 [units: "panel/h"];
		
		port in item flow steelIn : SteelSheet;
		port out item flow panelsOut : BodyPanel;
		
		part presses : StampingPress[pressCount];
	}
	
	// ===== Welding Department =====
	
	part def RoboticWelder {
		attribute welderId : String;
		attribute armCount : Integer = 6;
		attribute weldRate : Real = 40 [units: "weld/min"];
		attribute maxPayload : Mass = 500 [kg];
		
		port in item flow panelsIn : BodyPanel;
		port out item flow chassisOut : VehicleChassis;
		
		action weldPanels {
			in panels : BodyPanel;
			out chassis : VehicleChassis;
		}
	}
	
	part def WeldingDepartment {
		attribute departmentId : String = "WELDING-01";
		attribute welderCount : Integer = 8;
		attribute chassisCapacity : Real = 60 [units: "chassis/h"];
		
		port in item flow panelsIn : BodyPanel;
		port out item flow chassisOut : VehicleChassis;
		
		part welders : RoboticWelder[welderCount];
	}
	
	// ===== Painting Department =====
	
	part def PaintBooth {
		attribute boothId : String;
		attribute colorCode : String;
		attribute boothTemperature : Temperature = 20 [°C];
		attribute humidity : Real = 45 [%];
		attribute cureTime : Time = 0.5 [h];
		
		port in item flow chassisIn : VehicleChassis;
		port out item flow paintedOut : PaintedBody;
		
		action sprayPaint {
			in chassis : VehicleChassis;
			out painted : PaintedBody;
		}
		
		action curePaint {
			in painted : PaintedBody;
			out cured : PaintedBody;
		}
	}
	
	part def PaintingDepartment {
		attribute departmentId : String = "PAINTING-01";
		attribute boothCount : Integer = 4;
		attribute throughput : Real = 50 [units: "body/h"];
		
		port in item flow chassisIn : VehicleChassis;
		port out item flow paintedOut : PaintedBody;
		
		part booths : PaintBooth[boothCount];
	}
	
	// ===== Final Assembly Department =====
	
	part def AssemblyStation {
		attribute stationId : String;
		attribute cycleTime : Time = 0.1 [h];
		attribute workersPerStation : Integer = 4;
		
		port in item flow bodyIn : PaintedBody;
		port in item flow powertrainIn : Powertrain;
		port out item flow vehicleOut : AssembledVehicle;
		
		action installPowertrain {
			in body : PaintedBody;
			in powertrain : Powertrain;
			out vehicle : AssembledVehicle;
		}
		
		action installComponents {
			in vehicle : AssembledVehicle;
			out completed : AssembledVehicle;
		}
	}
	
	part def FinalAssemblyDepartment {
		attribute departmentId : String = "ASSEMBLY-01";
		attribute stationCount : Integer = 10;
		attribute throughput : Real = 40 [units: "vehicle/h"];
		
		port in item flow paintedIn : PaintedBody;
		port in item flow powertrainIn : Powertrain;
		port out item flow assembledOut : AssembledVehicle;
		
		part stations : AssemblyStation[stationCount];
	}
	
	// ===== Quality Testing Facility =====
	
	part def QualityTestRig {
		attribute rigId : String;
		attribute testDuration : Time = 0.2 [h];
		attribute passThreshold : Real = 0.95;
		
		port in item flow vehicleIn : AssembledVehicle;
		port out item flow testedOut : FinishedVehicle;
		
		action runDiagnostics {
			in vehicle : AssembledVehicle;
			out score : Real;
		}
		
		action evaluateQuality {
			in vehicle : AssembledVehicle;
			in score : Real;
			out result : FinishedVehicle;
		}
	}
	
	part def QualityTestingFacility {
		attribute departmentId : String = "QUALITY-01";
		attribute rigCount : Integer = 5;
		attribute minQualityScore : Real = 0.95;
		
		port in item flow vehicleIn : AssembledVehicle;
		port out item flow approvedOut : FinishedVehicle;
		port out item flow rejectedOut : FinishedVehicle;
		
		part testRigs : QualityTestRig[rigCount];
	}
	
	// ===== Plant Control System =====
	
	part def PlantControlSystem {
		attribute systemId : String = "PLC-MAIN";
		attribute operationalState : String;
		
		port in item flow ordersIn : ProductionOrder;
		port out item flow productionReport : Any;
		
		state machine OperationalStateMachine {
			state Offline {
				entry { operationalState = "offline"; }
			}
			state Maintenance {
				entry { operationalState = "maintenance"; }
			}
			state Operational {
				entry { operationalState = "operational"; }
				state Warmup;
				state ProductionShift;
				state Cooldown;
			}
			
			initial : Offline;
			transition from Offline to Maintenance when triggerMaintenance;
			transition from Maintenance to Operational when maintenanceComplete;
			transition from Offline to Operational when startup;
			transition from Operational::Warmup to Operational::ProductionShift when warmed;
			transition from Operational::ProductionShift to Operational::Cooldown when shiftEnd;
			transition from Operational::Cooldown to Offline when shutdownComplete;
			transition from Operational::ProductionShift to Maintenance when emergencyMaintenance;
		}
	}
	
	// ===== Main Plant =====
	
	part def VehicleManufacturingPlant {
		attribute plantId : String = "VMP-001";
		attribute location : String;
		attribute dailyProductionTarget : Integer = 400;
		attribute minQualityScore : Real = 0.95;
		attribute targetEfficiency : Real = 0.85;
		
		port in item flow steelIn : SteelSheet;
		port in item flow powertrainIn : Powertrain;
		port in item flow ordersIn : ProductionOrder;
		port out item flow finishedVehiclesOut : FinishedVehicle;
		
		part stampingDepartment : StampingDepartment;
		part weldingDepartment : WeldingDepartment;
		part paintingDepartment : PaintingDepartment;
		part finalAssemblyDepartment : FinalAssemblyDepartment;
		part qualityTestingFacility : QualityTestingFacility;
		part controlSystem : PlantControlSystem;
		
		connection steelIn to stampingDepartment.steelIn;
		connection stampingDepartment.panelsOut to weldingDepartment.panelsIn;
		connection weldingDepartment.chassisOut to paintingDepartment.chassisIn;
		connection paintingDepartment.paintedOut to finalAssemblyDepartment.paintedIn;
		connection powertrainIn to finalAssemblyDepartment.powertrainIn;
		connection finalAssemblyDepartment.assembledOut to qualityTestingFacility.vehicleIn;
		connection qualityTestingFacility.approvedOut to finishedVehiclesOut;
		
		action produceVehicle {
			in order : ProductionOrder;
			in steel : SteelSheet;
			in powertrain : Powertrain;
			out finished : FinishedVehicle;
			
			then stampAction;
			action stampAction {
				in sheet : SteelSheet;
				out panels : BodyPanel;
			}
			then weldAction;
			action weldAction {
				in panels : BodyPanel;
				out chassis : VehicleChassis;
			}
			then paintAction;
			action paintAction {
				in chassis : VehicleChassis;
				out painted : PaintedBody;
			}
			then assembleAction;
			action assembleAction {
				in body : PaintedBody;
				in pt : Powertrain;
				out assembled : AssembledVehicle;
			}
			then testAction;
			action testAction {
				in assembled : AssembledVehicle;
				out tested : FinishedVehicle;
			}
			then ship;
			action ship {
				in vehicle : FinishedVehicle;
			}
		}
		
		state machine PlantState {
			state Offline;
			state Operational {
				state ShiftActive;
				state ShiftIdle;
			}
			state Maintenance;
			
			initial : Offline;
			transition from Offline to Operational when startup;
			transition from Operational::ShiftActive to Operational::ShiftIdle when shiftEnd;
			transition from Operational::ShiftIdle to Operational::ShiftActive when shiftStart;
			transition from Operational to Offline when shutdown;
			transition from Operational to Maintenance when scheduledMaintenance;
			transition from Maintenance to Operational when maintenanceComplete;
			transition from Maintenance to Offline when fullShutdown;
		}
	}
	
	// ===== Satisfaction Relationships =====
	
	satisfy ProductionTargetRequirement by VehicleManufacturingPlant {
		dailyProductionRate = 400 [units: "vehicle/day"];
		minQualityScore = 0.95;
		minEfficiency = 0.85;
	}
	
	satisfy QualityApprovalRequirement by QualityTestingFacility {
		thresholdQuality = 0.95;
	}
	
	satisfy StampingThroughputRequirement by StampingPress {
		minPanelsPerHour = 80 [units: "panel/h"];
	}
	
	satisfy PaintBoothRequirement by PaintBooth {
		temperatureRange = (18..25) [K];
		humidityRange = 30..55 [%];
	}
	
	satisfy PlantOperationalRequirement by VehicleManufacturingPlant {
		shiftDuration = 8 [h];
		maintenanceCycle = 720 [h];
	}
}
