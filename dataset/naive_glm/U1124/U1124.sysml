package IndustrialPurificationSystem {

	import ScalarValues::*;
	import ISQ::*;

	// ---------- Value Types ----------
	value type MassFlowRate > Real { unit 'kg/s'; }
	value type Mass > Real { unit 'kg'; }
	value type Purity > Real { unit '%'; min 0; max 100; }
	value type ContaminantLevel > Real { unit '%'; min 0; max 100; }
	value type SeparationEfficiency > Real { unit '%'; min 0; max 100; }
	value type Pressure > Real { unit 'Pa'; }
	value type Temperature > Real { unit 'K'; }
	value type Volume > Real { unit 'm3'; }
	value type DurationValue > Real { unit 's'; }

	item def RawMaterial {
		attribute mass : Mass;
		attribute contaminantLevel : ContaminantLevel;
		attribute temperature : Temperature;
	}

	item def RefinedProduct {
		attribute mass : Mass;
		attribute purity : Purity;
		attribute density : Real { unit 'kg/m3'; }
	}

	item def ContaminantWaste {
		attribute mass : Mass;
	}

	item def InspectionReport {
		attribute measuredContaminantLevel : ContaminantLevel;
		attribute measuredPurity : Purity;
		attribute timestamp : DurationValue;
		attribute pass : Boolean;
	}

	item def ControlCommand {
		attribute targetUnit : String;
		attribute commandType : String;
		attribute parameterValue : Real;
	}

	// ---------- Port Definitions ----------
	port def MaterialPort {
		in item material : RawMaterial;
		out item flow : RawMaterial;
	}

	port def RefinedPort {
		in item product : RefinedProduct;
	}

	port def WastePort {
		out item waste : ContaminantWaste;
	}

	port def InspectionPort {
		out item report : InspectionReport;
		in item command : ControlCommand;
	}

	port def ControlPort {
		out item command : ControlCommand;
		in item report : InspectionReport;
		in item status : UnitStatus;
	}

	item def UnitStatus {
		attribute unitName : String;
		attribute operational : Boolean;
		attribute currentLoad : Mass;
		attribute faultCode : Integer;
	}

	// ---------- Interfaces ----------
	interface def MaterialFlow {
		end supplier : MaterialPort;
		end consumer : MaterialPort;
	}

	interface def RefinedFlow {
		end supplier : MaterialPort;
		end consumer : RefinedPort;
	}

	interface def WasteFlow {
		end supplier : WastePort;
		end consumer : WastePort;
	}

	interface def InspectionDataLink {
		end supplier : InspectionPort;
		end consumer : ControlPort;
	}

	interface def CommandLink {
		end supplier : ControlPort;
		end consumer : InspectionPort;
	}

	// ---------- Part Definitions ----------
	part def InputStorageVessel {
		attribute capacity : Mass = 500 [kg];
		attribute currentMass : Mass;
		attribute nominalFlowRate : MassFlowRate = 2.5 [kg/s];

		port out materialOut : MaterialPort;
		port in controlIn : ControlPort;

		state def InputVesselBehavior {
			entry action { send materialOut.flow; }
			state Idle;
			state Dispensing {
				entry action { currentMass = currentMass - nominalFlowRate * 1.0 [s]; }
				do action { send materialOut.flow; }
			}
			state Faulted;
			transition idle_to_dispensing
				first Idle
				then Dispensing
				when controlIn.command.commandType == "startFeed";
			transition dispensing_to_idle
				first Dispensing
				then Idle
				when currentMass <= 0 [kg];
			transition to_faulted
				first Idle
				then Faulted
				when currentMass > capacity;
		}

		composition behavior : InputVesselBehavior;
	}

	part def InspectionUnit {
		attribute inspectionDuration : DurationValue = 0.5 [s];
		attribute targetPurity : Purity = 97.5 [%];
		attribute tolerance : ContaminantLevel = 2.5 [%];

		port in materialIn : MaterialPort;
		port out pureOut : MaterialPort;
		port out impureOut : MaterialPort;
		port out inspectionReport : InspectionPort;
		port in commandIn : ControlPort;

		state def InspectionBehavior {
			state Waiting;
			state Analyzing {
				entry action {
					InspectionReport.measuredContaminantLevel = materialIn.material.contaminantLevel;
					InspectionReport.measuredPurity = 100.0 [%] - materialIn.material.contaminantLevel;
					InspectionReport.pass = (InspectionReport.measuredPurity >= targetPurity);
					send inspectionReport.report;
				}
			}
			state RoutingPure {
				entry action { send pureOut.flow; }
			}
			state RoutingImpure {
				entry action { send impureOut.flow; }
			}
			transition waiting_to_analyzing
				first Waiting
				then Analyzing
				when materialIn.material != null;
			transition analyzing_to_routingPure
				first Analyzing
				then RoutingPure
				when InspectionReport.pass == true;
			transition analyzing_to_routingImpure
				first Analyzing
				then RoutingImpure
				when InspectionReport.pass == false;
			transition pure_to_waiting
				first RoutingPure
				then Waiting;
			transition impure_to_waiting
				first RoutingImpure
				then Waiting;
		}

		composition behavior : InspectionBehavior;
	}

	part def SeparationUnit {
		attribute efficiency : SeparationEfficiency = 85.0 [%];
		attribute processingRate : MassFlowRate = 2.0 [kg/s];
		attribute operatingPressure : Pressure = 150000 [Pa];
		attribute operatingTemperature : Temperature = 350 [K];

		port in materialIn : MaterialPort;
		port out processedOut : MaterialPort;
		port out wasteOut : WastePort;
		port in controlIn : ControlPort;

		state def SeparationBehavior {
			state Standby;
			state Processing {
				entry action {
					RawMaterial.contaminantLevel = RawMaterial.contaminantLevel * (1.0 - efficiency / 100.0);
					ContaminantWaste.mass = RawMaterial.mass * (RawMaterial.contaminantLevel * efficiency / 100.0);
					send wasteOut.waste;
					send processedOut.flow;
				}
			}
			state Maintenance;
			transition standby_to_processing
				first Standby
				then Processing
				when materialIn.material != null;
			transition processing_to_standby
				first Processing
				then Standby
				when materialIn.material == null;
			transition to_maintenance
				first Processing
				then Maintenance
				when controlIn.command.commandType == "maintenance";
			transition maintenance_to_standby
				first Maintenance
				then Standby
				when controlIn.command.commandType == "resume";
		}

		composition behavior : SeparationBehavior;
	}

	part def ConsolidationUnit {
		attribute compressionPressure : Pressure = 500000 [Pa];
		attribute outputDensity : Real { unit 'kg/m3'; } = 1200;
		attribute batchMass : Mass = 50 [kg];

		port in materialIn : MaterialPort;
		port out productOut : RefinedPort;
		port in controlIn : ControlPort;

		state def ConsolidationBehavior {
			state Idle;
			state Accumulating;
			state Compressing {
				entry action {
					RefinedProduct.mass = batchMass;
					RefinedProduct.purity = 100.0 [%] - materialIn.material.contaminantLevel;
					RefinedProduct.density = outputDensity;
					send productOut.product;
				}
			}
			transition idle_to_accumulating
				first Idle
				then Accumulating
				when materialIn.material != null;
			transition accumulating_to_compressing
				first Accumulating
				then Compressing
				when currentAccumulatedMass >= batchMass;
			transition compressing_to_idle
				first Compressing
				then Idle;
		}

		attribute currentAccumulatedMass : Mass;
		composition behavior : ConsolidationBehavior;
	}

	part def OutputStorageVessel {
		attribute capacity : Mass = 1000 [kg];
		attribute currentMass : Mass;
		attribute maxFillLevel : Real = 0.95;

		port in productIn : RefinedPort;
		port in controlIn : ControlPort;

		state def OutputVesselBehavior {
			state Receiving {
				entry action { currentMass = currentMass + productIn.product.mass; }
			}
			state Full;
			state ReadyForDistribution;
			transition receiving_to_full
				first Receiving
				then Full
				when currentMass >= capacity * maxFillLevel;
			transition full_to_ready
				first Full
				then ReadyForDistribution
				when controlIn.command.commandType == "discharge";
			transition ready_to_receiving
				first ReadyForDistribution
				then Receiving
				when currentMass < capacity * maxFillLevel;
		}

		composition behavior : OutputVesselBehavior;
	}

	part def ControlSystem {
		attribute targetPurity : Purity = 97.5 [%];
		attribute nominalThroughput : MassFlowRate = 2.0 [kg/s];
		attribute maxCycleCount : Integer = 10;

		port out toInput : ControlPort;
		port out toInspection : ControlPort;
		port out toSeparation : ControlPort;
		port out toConsolidation : ControlPort;
		port out toOutput : ControlPort;

		port in fromInspection : InspectionPort;
		port in fromInput : ControlPort;
		port in fromSeparation : ControlPort;
		port in fromConsolidation : ControlPort;
		port in fromOutput : ControlPort;

		attribute cycleCount : Integer;
		attribute currentPurity : Purity;

		state def ControlBehavior {
			state Monitoring {
				entry action {
					currentPurity = fromInspection.report.measuredPurity;
				}
				do action {
					if currentPurity >= targetPurity {
						ControlCommand.targetUnit = "ConsolidationUnit";
						ControlCommand.commandType = "acceptBatch";
						send toConsolidation.command;
					} else {
						ControlCommand.targetUnit = "SeparationUnit";
						ControlCommand.commandType = "process";
						send toSeparation.command;
						cycleCount = cycleCount + 1;
					}
				}
			}
			state EmergencyStop {
				entry action {
					ControlCommand.commandType = "stop";
					send toInput.command;
					send toSeparation.command;
					send toConsolidation.command;
				}
			}
			state Diagnostics;
			transition monitoring_to_emergency
				first Monitoring
				then EmergencyStop
				when fromInput.status.faultCode != 0 or fromSeparation.status.faultCode != 0;
			transition monitoring_to_diagnostics
				first Monitoring
				then Diagnostics
				when cycleCount >= maxCycleCount;
			transition diagnostics_to_monitoring
				first Diagnostics
				then Monitoring
				when fromSeparation.status.operational == true;
		}

		composition behavior : ControlBehavior;
	}

	// ---------- Top-level System ----------
	part def PurificationPlant {
		part inputVessel : InputStorageVessel {
			attribute capacity = 500 [kg];
		}
		part inspection : InspectionUnit {
			attribute targetPurity = 97.5 [%];
		}
		part separation : SeparationUnit {
			attribute efficiency = 85.0 [%];
		}
		part consolidation : ConsolidationUnit {
			attribute batchMass = 50 [kg];
		}
		part outputVessel : OutputStorageVessel {
			attribute capacity = 1000 [kg];
		}
		part controller : ControlSystem {
			attribute targetPurity = 97.5 [%];
			attribute nominalThroughput = 2.0 [kg/s];
		}

		// Material flow connections
		connection inputToInspection : MaterialFlow connect inputVessel.materialOut to inspection.materialIn;
		connection inspectionToSeparation : MaterialFlow connect inspection.impureOut to separation.materialIn;
		connection separationToInspection : MaterialFlow connect separation.processedOut to inspection.materialIn;
		connection inspectionToConsolidation : MaterialFlow connect inspection.pureOut to consolidation.materialIn;
		connection consolidationToOutput : RefinedFlow connect consolidation.productOut to outputVessel.productIn;
		connection separationWaste : WasteFlow connect separation.wasteOut to ::Environment.wasteSink;

		// Control data connections
		connection inspectionToControl : InspectionDataLink connect inspection.inspectionReport to controller.fromInspection;
		connection controlToInspection : CommandLink connect controller.toInspection to inspection.commandIn;
		connection controlToInput : CommandLink connect controller.toInput to inputVessel.controlIn;
		connection controlToSeparation : CommandLink connect controller.toSeparation to separation.controlIn;
		connection controlToConsolidation : CommandLink connect controller.toConsolidation to consolidation.controlIn;
		connection controlToOutput : CommandLink connect controller.toOutput to outputVessel.controlIn;

		// Status feedback connections
		connection inputStatus : InspectionDataLink connect inputVessel.controlIn to controller.fromInput;
		connection separationStatus : InspectionDataLink connect separation.controlIn to controller.fromSeparation;
		connection consolidationStatus : InspectionDataLink connect consolidation.controlIn to controller.fromConsolidation;
		connection outputStatus : InspectionDataLink connect outputVessel.controlIn to controller.fromOutput;
	}

	part def Environment {
		port in wasteSink : WastePort;
	}

	// ---------- Requirements ----------
	requirement def PurificationPerformanceRequirement {
		subject plant : PurificationPlant;
		requirement {
			/* The plant shall process raw material at a nominal throughput of at least 2.0 kg/s. */
		}
		attribute minThroughput : MassFlowRate = 2.0 [kg/s];
	}

	requirement def PurityTargetRequirement {
		subject inspectionUnit : InspectionUnit;
		requirement {
			/* The inspection unit shall certify material as pure only when measured purity is >= 97.5%. */
		}
		attribute targetPurity : Purity = 97.5 [%];
	}

	requirement def SeparationEfficiencyRequirement {
		subject separationUnit : SeparationUnit;
		requirement {
			/* The separation unit shall achieve a contaminant removal efficiency of at least 85%. */
		}
		attribute minEfficiency : SeparationEfficiency = 85.0 [%];
	}

	requirement def StorageSafetyRequirement {
		subject vessel : OutputStorageVessel;
		requirement {
			/* The output storage vessel shall not exceed 95% of its rated capacity during operation. */
		}
		attribute maxFillFraction : Real = 0.95;
	}

	requirement def CyclicProcessingRequirement {
		subject controller : ControlSystem;
		requirement {
			/* The control system shall re-route impure material to the separation unit until target purity is achieved or max cycle count is reached. */
		}
		attribute maxCycles : Integer = 10;
	}

	requirement def EmergencyShutdownRequirement {
		subject controller : ControlSystem;
		requirement {
			/* The control system shall initiate emergency stop upon detection of any unit fault. */
		}
	}

	requirement def InputCapacityRequirement {
		subject inputVessel : InputStorageVessel;
		requirement {
			/* The input storage vessel shall not be loaded beyond its rated capacity of 500 kg. */
		}
		attribute maxCapacity : Mass = 500 [kg];
	}

	requirement def ConsolidationDensityRequirement {
		subject consolidation : ConsolidationUnit;
		requirement {
			/* The consolidation unit shall compress purified product to a density of at least 1200 kg/m3. */
		}
		attribute minDensity : Real { unit 'kg/m3'; } = 1200;
	}

	// ---------- Requirement Satisfaction ----------
	satisfaction satisfyPurityTarget : PurityTargetRequirement {
		subject requirementSubject : inspectionUnit = inspection;
	}

	satisfaction satisfyThroughput : PurificationPerformanceRequirement {
		subject requirementSubject : plant = ::PurificationPlant;
	}

	satisfaction satisfySeparationEfficiency : SeparationEfficiencyRequirement {
		subject requirementSubject : separationUnit = separation;
	}

	satisfaction satisfyStorageSafety : StorageSafetyRequirement {
		subject requirementSubject : vessel = outputVessel;
	}

	satisfaction satisfyCyclicProcessing : CyclicProcessingRequirement {
		subject requirementSubject : controller = controller;
	}

	satisfaction satisfyEmergencyShutdown : EmergencyShutdownRequirement {
		subject requirementSubject : controller = controller;
	}

	satisfaction satisfyInputCapacity : InputCapacityRequirement {
		subject requirementSubject : inputVessel = inputVessel;
	}

	satisfaction satisfyConsolidationDensity : ConsolidationDensityRequirement {
		subject requirementSubject : consolidation = consolidation;
	}

}
