package 'Industrial Purification System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	item def MaterialFlow {
		attribute mass : MassValue;
		attribute purity : Real;
	}
	item def InspectionData {
		attribute purity : Real;
	}
	enum def RouteTarget {
		separation;
		consolidation;
	}
	item def RouteCommand {
		attribute target : RouteTarget;
	}
	item def ProcessCommand {
		attribute efficiency : Real;
	}
	item def CommandComplete;

	port def MaterialPort {
		out item material : MaterialFlow;
	}
	port def DataPort {
		out item inspectionData : InspectionData;
	}
	port def RouteCommandPort {
		out item routeCommand : RouteCommand;
	}
	port def ProcessCommandPort {
		out item processCommand : ProcessCommand;
	}

	part def StorageVessel {
		attribute capacity : MassValue;
		attribute currentMass : MassValue;
	}

	part def InputStorageVessel :> StorageVessel {
		port materialOut : MaterialPort;
	}

	part def InspectionUnit {
		port materialIn : ~MaterialPort;
		port materialOut : MaterialPort;
		port dataOut : DataPort;
	}

	part def RoutingUnit {
		port materialIn : ~MaterialPort;
		port toSeparation : MaterialPort;
		port toConsolidation : MaterialPort;
		port commandIn : ~RouteCommandPort;
	}

	part def SeparationUnit {
		attribute efficiency : Real;
		port materialIn : ~MaterialPort;
		port materialOut : MaterialPort;
		port commandIn : ~ProcessCommandPort;
	}

	part def ConsolidationUnit {
		port materialIn : ~MaterialPort;
		port materialOut : MaterialPort;
	}

	part def OutputStorageVessel :> StorageVessel {
		port materialIn : ~MaterialPort;
	}

	part def ControlSystem {
		attribute targetPurity : Real = 97.5;
		port dataIn : ~DataPort;
		port routeCommandOut : RouteCommandPort;
		port processCommandOut : ProcessCommandPort;

		state controlStates {
			entry; then monitoring;
			state monitoring;
			accept when dataIn.inspectionData.purity < targetPurity
				then commandingSeparation;
			accept when dataIn.inspectionData.purity >= targetPurity
				then commandingConsolidation;
			state commandingSeparation {
				entry;
			}
			accept CommandComplete then monitoring;
			state commandingConsolidation {
				entry;
			}
			accept CommandComplete then monitoring;
		}
	}

	part def PurificationSystem {
		attribute throughput : MassFlowRateValue;

		part inputVessel : InputStorageVessel;
		part inspection : InspectionUnit;
		part routing : RoutingUnit;
		part separation : SeparationUnit;
		part consolidation : ConsolidationUnit;
		part outputVessel : OutputStorageVessel;
		part controller : ControlSystem;

		flow rawFlow of MaterialFlow from inputVessel.materialOut.material to inspection.materialIn.material;
		flow inspectedFlow of MaterialFlow from inspection.materialOut.material to routing.materialIn.material;
		flow toSeparationFlow of MaterialFlow from routing.toSeparation.material to separation.materialIn.material;
		flow recirculatedFlow of MaterialFlow from separation.materialOut.material to inspection.materialIn.material;
		flow toConsolidationFlow of MaterialFlow from routing.toConsolidation.material to consolidation.materialIn.material;
		flow productFlow of MaterialFlow from consolidation.materialOut.material to outputVessel.materialIn.material;

		flow dataFlow of InspectionData from inspection.dataOut.inspectionData to controller.dataIn.inspectionData;
		flow routeCommandFlow of RouteCommand from controller.routeCommandOut.routeCommand to routing.commandIn.routeCommand;
		flow processCommandFlow of ProcessCommand from controller.processCommandOut.processCommand to separation.commandIn.processCommand;
	}

	requirement def PurityRequirement {
		doc /* The refined product shall have a purity of at least 97.5%. */
		subject product : MaterialFlow;
		attribute minPurity : Real = 97.5;
		require constraint { product.purity >= minPurity }
	}

	requirement def ThroughputRequirement {
		doc /* The system shall maintain a nominal processing speed. */
		subject system : PurificationSystem;
		attribute minThroughput : MassFlowRateValue = 10.0 [kg/s];
		require constraint { system.throughput >= minThroughput }
	}

	requirement def CapacityRequirement {
		doc /* The system shall not exceed the capacity of its storage vessels. */
		subject vessel : StorageVessel;
		require constraint { vessel.currentMass <= vessel.capacity }
	}
}
