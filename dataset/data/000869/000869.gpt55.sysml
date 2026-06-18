package EccentricReducerModel {
	import ScalarValues::*;
	import ISQ::*;
	import SI::*;

	attribute def DiameterValue :> ISQ::LengthValue;
	attribute def RadiusValue :> ISQ::LengthValue;
	attribute def WallThicknessValue :> ISQ::LengthValue;
	attribute def LengthValue :> ISQ::LengthValue;
	attribute def OffsetValue :> ISQ::LengthValue;
	attribute def RoughnessValue :> ISQ::LengthValue;
	attribute def AreaValue :> ISQ::AreaValue;
	attribute def VolumeFlowRateValue :> ISQ::VolumeFlowRateValue;
	attribute def PressureValue :> ISQ::PressureValue;
	attribute def PressureDropValue :> ISQ::PressureValue;
	attribute def DensityValue :> ISQ::DensityValue;
	attribute def DynamicViscosityValue :> ISQ::DynamicViscosityValue;
	attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
	attribute def VelocityValue :> ISQ::SpeedValue;
	attribute def MassValue :> ISQ::MassValue;
	attribute def AngleValue :> ISQ::PlaneAngleValue;

	enum def FluidPhaseKind {
		enum liquid;
		enum gas;
		enum twoPhase;
	}

	enum def EccentricOrientationKind {
		enum flatOnTop;
		enum flatOnBottom;
	}

	enum def ReducerHealthKind {
		enum acceptable;
		enum fouled;
		enum corroded;
		enum leaking;
		enum blocked;
	}

	enum def ConnectionEndKind {
		enum welded;
		enum flanged;
		enum threaded;
		enum grooved;
	}

	item def ProcessFluid {
		attribute phase : FluidPhaseKind = FluidPhaseKind::liquid;
		attribute density : DensityValue = 998 [SI::kg_per_m3];
		attribute dynamicViscosity : DynamicViscosityValue = 0.001 [SI::Pa_s];
		attribute temperature : TemperatureValue = 293.15 [SI::K];
		attribute staticPressure : PressureValue = 600 [SI::kPa];
		attribute volumeFlowRate : VolumeFlowRateValue = 180 [SI::m3_per_h];
		attribute meanVelocity : VelocityValue = 1.2 [SI::m_per_s];
	}

	item def PressureSignal {
		attribute sensedPressure : PressureValue;
		attribute signalTemperature : TemperatureValue;
	}

	item def MaintenanceCommand {
		attribute isolate : Boolean;
		attribute drain : Boolean;
		attribute inspectInternalSurface : Boolean;
	}

	item def FlowStartCommand {
		attribute requestedFlowRate : VolumeFlowRateValue;
	}

	item def FlowStopCommand {
		attribute controlledRampDown : Boolean = true;
	}

	port def FluidPort {
		in item incomingFluid : ProcessFluid;
		out item outgoingFluid : ProcessFluid;
		attribute nominalDiameter : DiameterValue;
		attribute designPressure : PressureValue;
		attribute endConnection : ConnectionEndKind;
	}

	port def InstrumentPort {
		out item measuredPressure : PressureSignal;
		attribute tappingDiameter : DiameterValue = 12 [SI::mm];
		attribute maximumInstrumentPressure : PressureValue = 1600 [SI::kPa];
	}

	port def MaintenancePort {
		in item maintenanceCommand : MaintenanceCommand;
		attribute accessDiameter : DiameterValue = 25 [SI::mm];
	}

	connection def SealedFluidConnection {
		end upstreamEnd : FluidPort;
		end downstreamEnd : FluidPort;
		attribute leakageRateLimit : VolumeFlowRateValue = 0.0 [SI::m3_per_h];
	}

	constraint def PositiveDiameter {
		in d : DiameterValue;
		assert d > 0 [SI::mm];
	}

	constraint def DiameterReduction {
		in upstreamDiameter : DiameterValue;
		in downstreamDiameter : DiameterValue;
		assert upstreamDiameter > downstreamDiameter;
	}

	constraint def EccentricOffsetRelation {
		in upstreamDiameter : DiameterValue;
		in downstreamDiameter : DiameterValue;
		in offset : OffsetValue;
		assert offset == (upstreamDiameter - downstreamDiameter) / 2;
	}

	constraint def FlowContinuity {
		in inletFlow : VolumeFlowRateValue;
		in outletFlow : VolumeFlowRateValue;
		assert outletFlow >= 0.98 * inletFlow;
		assert outletFlow <= 1.02 * inletFlow;
	}

	constraint def PressureDropLimit {
		in pressureDrop : PressureDropValue;
		in maximumAllowedPressureDrop : PressureDropValue;
		assert pressureDrop <= maximumAllowedPressureDrop;
	}

	constraint def SmoothTransitionAngleLimit {
		in taperAngle : AngleValue;
		assert taperAngle <= 15 [SI::deg];
	}

	part def PipeEnd {
		attribute nominalDiameter : DiameterValue;
		attribute wallThickness : WallThicknessValue;
		attribute endConnection : ConnectionEndKind;
		attribute flangeFaceFlatness : LengthValue = 0.05 [SI::mm];
		port fluidInterface : FluidPort {
			:>> nominalDiameter = nominalDiameter;
			:>> endConnection = endConnection;
		}
	}

	part def LargeEnd :> PipeEnd {
		:>> nominalDiameter = 300 [SI::mm];
		:>> wallThickness = 9.5 [SI::mm];
		:>> endConnection = ConnectionEndKind::flanged;
		attribute boltCircleDiameter : DiameterValue = 445 [SI::mm];
		attribute gasketInsideDiameter : DiameterValue = 305 [SI::mm];
	}

	part def SmallEnd :> PipeEnd {
		:>> nominalDiameter = 150 [SI::mm];
		:>> wallThickness = 7.1 [SI::mm];
		:>> endConnection = ConnectionEndKind::flanged;
		attribute boltCircleDiameter : DiameterValue = 280 [SI::mm];
		attribute gasketInsideDiameter : DiameterValue = 154 [SI::mm];
	}

	part def EccentricTaperShell {
		attribute largeDiameter : DiameterValue = 300 [SI::mm];
		attribute smallDiameter : DiameterValue = 150 [SI::mm];
		attribute reducerLength : LengthValue = 450 [SI::mm];
		attribute wallThickness : WallThicknessValue = 8.0 [SI::mm];
		attribute eccentricOffset : OffsetValue = 75 [SI::mm];
		attribute taperAngle : AngleValue = 9.46 [SI::deg];
		attribute internalSurfaceRoughness : RoughnessValue = 0.045 [SI::mm];
		attribute materialMass : MassValue = 34 [SI::kg];
		attribute materialName : String = "ASTM A234 WPB carbon steel";
		attribute corrosionAllowance : WallThicknessValue = 1.5 [SI::mm];
		attribute orientation : EccentricOrientationKind = EccentricOrientationKind::flatOnTop;
		port upstreamPort : FluidPort {
			:>> nominalDiameter = largeDiameter;
			:>> designPressure = 1600 [SI::kPa];
			:>> endConnection = ConnectionEndKind::flanged;
		}
		port downstreamPort : FluidPort {
			:>> nominalDiameter = smallDiameter;
			:>> designPressure = 1600 [SI::kPa];
			:>> endConnection = ConnectionEndKind::flanged;
		}
		assert constraint positiveLargeDiameter : PositiveDiameter {
			d = largeDiameter;
		}
		assert constraint positiveSmallDiameter : PositiveDiameter {
			d = smallDiameter;
		}
		assert constraint reductionGeometry : DiameterReduction {
			upstreamDiameter = largeDiameter;
			downstreamDiameter = smallDiameter;
		}
		assert constraint eccentricGeometry : EccentricOffsetRelation {
			upstreamDiameter = largeDiameter;
			downstreamDiameter = smallDiameter;
			offset = eccentricOffset;
		}
		assert constraint smoothTaper : SmoothTransitionAngleLimit {
			taperAngle = taperAngle;
		}
	}

	part def InternalFlowPassage {
		attribute inletFlowArea : AreaValue = 0.0707 [SI::m2];
		attribute outletFlowArea : AreaValue = 0.0177 [SI::m2];
		attribute wettedLength : LengthValue = 450 [SI::mm];
		attribute hydraulicRoughness : RoughnessValue = 0.045 [SI::mm];
		port upstreamOpening : FluidPort {
			:>> nominalDiameter = 300 [SI::mm];
			:>> designPressure = 1600 [SI::kPa];
			:>> endConnection = ConnectionEndKind::flanged;
		}
		port downstreamOpening : FluidPort {
			:>> nominalDiameter = 150 [SI::mm];
			:>> designPressure = 1600 [SI::kPa];
			:>> endConnection = ConnectionEndKind::flanged;
		}
	}

	action def ReceiveFlowAtLargeEnd {
		in item fluidIn : ProcessFluid;
		out item admittedFluid : ProcessFluid;
		attribute acceptedDiameter : DiameterValue = 300 [SI::mm];
	}

	action def GuideFlowThroughEccentricTaper {
		in item admittedFluid : ProcessFluid;
		out item acceleratedFluid : ProcessFluid;
		attribute inletDiameter : DiameterValue = 300 [SI::mm];
		attribute outletDiameter : DiameterValue = 150 [SI::mm];
		attribute offset : OffsetValue = 75 [SI::mm];
		attribute pressureDrop : PressureDropValue = 12 [SI::kPa];
	}

	action def DischargeFlowAtSmallEnd {
		in item acceleratedFluid : ProcessFluid;
		out item fluidOut : ProcessFluid;
		attribute dischargeDiameter : DiameterValue = 150 [SI::mm];
	}

	action def ProvideEccentricReduction {
		in item upstreamFluid : ProcessFluid;
		out item downstreamFluid : ProcessFluid;
		attribute primaryFunctionDescription : String =
			"Provide a sealed, smooth, eccentric transition that connects a larger pipe to a smaller pipe while maintaining a continuous flow path and keeping one side of the pipe run flat to control gas pockets or liquid accumulation.";
		attribute inletDiameter : DiameterValue = 300 [SI::mm];
		attribute outletDiameter : DiameterValue = 150 [SI::mm];
		attribute maximumPressureDrop : PressureDropValue = 25 [SI::kPa];

		action receive : ReceiveFlowAtLargeEnd {
			fluidIn = upstreamFluid;
		}

		action guide : GuideFlowThroughEccentricTaper {
			admittedFluid = receive.admittedFluid;
			inletDiameter = inletDiameter;
			outletDiameter = outletDiameter;
		}

		action discharge : DischargeFlowAtSmallEnd {
			acceleratedFluid = guide.acceleratedFluid;
			fluidOut = downstreamFluid;
		}

		assert constraint requiredReduction : DiameterReduction {
			upstreamDiameter = inletDiameter;
			downstreamDiameter = outletDiameter;
		}

		assert constraint acceptablePressureDrop : PressureDropLimit {
			pressureDrop = guide.pressureDrop;
			maximumAllowedPressureDrop = maximumPressureDrop;
		}
	}

	action def IsolateReducer {
		in item command : MaintenanceCommand;
		out isolated : Boolean;
		attribute upstreamValveClosed : Boolean;
		attribute downstreamValveClosed : Boolean;
	}

	action def InspectReducerInterior {
		in item command : MaintenanceCommand;
		out health : ReducerHealthKind;
		attribute measuredWallLoss : WallThicknessValue = 0.2 [SI::mm];
		attribute foulingThickness : WallThicknessValue = 0.0 [SI::mm];
	}

	state def ReducerOperatingState {
		state dryIsolated;
		state filling;
		state steadyReducing;
		state shutdownDraining;
		state maintenanceInspection;
		state faulted;

		transition initialTransition first dryIsolated;

		transition startFilling
			first dryIsolated
			accept FlowStartCommand
			then filling;

		transition establishSteadyFlow
			first filling
			then steadyReducing;

		transition controlledStop
			first steadyReducing
			accept FlowStopCommand
			then shutdownDraining;

		transition drainedAndSafe
			first shutdownDraining
			then dryIsolated;

		transition enterMaintenance
			first dryIsolated
			accept MaintenanceCommand
			then maintenanceInspection;

		transition maintenanceComplete
			first maintenanceInspection
			then dryIsolated;

		transition leakDetected
			first steadyReducing
			then faulted;

		transition blockageDetected
			first filling
			then faulted;
	}

	part def EccentricReducer {
		attribute tagNumber : String = "ER-300x150-001";
		attribute inletNominalDiameter : DiameterValue = 300 [SI::mm];
		attribute outletNominalDiameter : DiameterValue = 150 [SI::mm];
		attribute centerlineOffset : OffsetValue = 75 [SI::mm];
		attribute faceToFaceLength : LengthValue = 450 [SI::mm];
		attribute designPressure : PressureValue = 1600 [SI::kPa];
		attribute designTemperature : TemperatureValue = 423.15 [SI::K];
		attribute expectedPressureDrop : PressureDropValue = 12 [SI::kPa];
		attribute maximumAllowablePressureDrop : PressureDropValue = 25 [SI::kPa];
		attribute allowableLeakageRate : VolumeFlowRateValue = 0.0 [SI::m3_per_h];
		attribute orientation : EccentricOrientationKind = EccentricOrientationKind::flatOnTop;
		attribute health : ReducerHealthKind = ReducerHealthKind::acceptable;
		attribute highLevelPrimaryFunction : String =
			"Transition process flow from a 300 mm pipe to a 150 mm pipe through an eccentric, sealed, smooth internal passage while preserving flow continuity and maintaining a flat top reference to reduce vapor pocket formation.";

		port inlet : FluidPort {
			:>> nominalDiameter = inletNominalDiameter;
			:>> designPressure = designPressure;
			:>> endConnection = ConnectionEndKind::flanged;
		}

		port outlet : FluidPort {
			:>> nominalDiameter = outletNominalDiameter;
			:>> designPressure = designPressure;
			:>> endConnection = ConnectionEndKind::flanged;
		}

		port upstreamPressureTap : InstrumentPort;
		port downstreamPressureTap : InstrumentPort;
		port maintenanceAccess : MaintenancePort;

		part largeEnd : LargeEnd;
		part smallEnd : SmallEnd;
		part taperShell : EccentricTaperShell {
			:>> largeDiameter = inletNominalDiameter;
			:>> smallDiameter = outletNominalDiameter;
			:>> reducerLength = faceToFaceLength;
			:>> eccentricOffset = centerlineOffset;
			:>> orientation = orientation;
		}
		part flowPassage : InternalFlowPassage;

		connection inletFlangeJoint : SealedFluidConnection connect inlet to largeEnd.fluidInterface {
			:>> leakageRateLimit = allowableLeakageRate;
		}

		connection largeEndToPassage : SealedFluidConnection connect largeEnd.fluidInterface to flowPassage.upstreamOpening {
			:>> leakageRateLimit = allowableLeakageRate;
		}

		connection passageToTaper : SealedFluidConnection connect flowPassage.upstreamOpening to taperShell.upstreamPort {
			:>> leakageRateLimit = allowableLeakageRate;
		}

		connection taperToSmallEnd : SealedFluidConnection connect taperShell.downstreamPort to smallEnd.fluidInterface {
			:>> leakageRateLimit = allowableLeakageRate;
		}

		connection outletFlangeJoint : SealedFluidConnection connect smallEnd.fluidInterface to outlet {
			:>> leakageRateLimit = allowableLeakageRate;
		}

		perform action primaryReductionFunction : ProvideEccentricReduction {
			inletDiameter = inletNominalDiameter;
			outletDiameter = outletNominalDiameter;
			maximumPressureDrop = maximumAllowablePressureDrop;
		}

		perform action isolationForMaintenance : IsolateReducer;
		perform action internalInspection : InspectReducerInterior;

		exhibit state operatingState : ReducerOperatingState;

		assert constraint diameterIsReduced : DiameterReduction {
			upstreamDiameter = inletNominalDiameter;
			downstreamDiameter = outletNominalDiameter;
		}

		assert constraint offsetMatchesEccentricGeometry : EccentricOffsetRelation {
			upstreamDiameter = inletNominalDiameter;
			downstreamDiameter = outletNominalDiameter;
			offset = centerlineOffset;
		}

		assert constraint pressureLossWithinLimit : PressureDropLimit {
			pressureDrop = expectedPressureDrop;
			maximumAllowedPressureDrop = maximumAllowablePressureDrop;
		}
	}

	part def PipeRunWithEccentricReducer {
		attribute serviceName : String = "Cooling water pump suction size transition";
		attribute operatingFlow : VolumeFlowRateValue = 180 [SI::m3_per_h];
		attribute upstreamPressure : PressureValue = 600 [SI::kPa];
		attribute downstreamPressure : PressureValue = 588 [SI::kPa];

		part upstreamPipe {
			attribute nominalDiameter : DiameterValue = 300 [SI::mm];
			attribute length : LengthValue = 2000 [SI::mm];
			port discharge : FluidPort {
				:>> nominalDiameter = nominalDiameter;
				:>> designPressure = 1600 [SI::kPa];
				:>> endConnection = ConnectionEndKind::flanged;
			}
		}

		part reducer : EccentricReducer;

		part downstreamPipe {
			attribute nominalDiameter : DiameterValue = 150 [SI::mm];
			attribute length : LengthValue = 2500 [SI::mm];
			port suction : FluidPort {
				:>> nominalDiameter = nominalDiameter;
				:>> designPressure = 1600 [SI::kPa];
				:>> endConnection = ConnectionEndKind::flanged;
			}
		}

		connection upstreamPipeToReducer : SealedFluidConnection connect upstreamPipe.discharge to reducer.inlet;
		connection reducerToDownstreamPipe : SealedFluidConnection connect reducer.outlet to downstreamPipe.suction;
	}

	requirement <ER-001> PrimaryFunctionRequirement {
		subject reducer : EccentricReducer;
		attribute statement : String =
			"The eccentric reducer shall provide a high-level function of transitioning process fluid from a larger inlet pipe diameter to a smaller outlet pipe diameter through a sealed eccentric taper while maintaining continuous flow.";
		require constraint {
			reducer.inletNominalDiameter > reducer.outletNominalDiameter;
		}
		require constraint {
			reducer.allowableLeakageRate == 0.0 [SI::m3_per_h];
		}
	}

	requirement <ER-002> EccentricGeometryRequirement {
		subject reducer : EccentricReducer;
		attribute statement : String =
			"The reducer centerline offset shall equal one half of the difference between inlet and outlet nominal diameters.";
		require constraint {
			reducer.centerlineOffset == (reducer.inletNominalDiameter - reducer.outletNominalDiameter) / 2;
		}
	}

	requirement <ER-003> PressureDropRequirement {
		subject reducer : EccentricReducer;
		attribute statement : String =
			"The reducer shall limit pressure loss caused by the diameter transition to the specified maximum pressure drop.";
		require constraint {
			reducer.expectedPressureDrop <= reducer.maximumAllowablePressureDrop;
		}
	}

	requirement <ER-004> OrientationRequirement {
		subject reducer : EccentricReducer;
		attribute statement : String =
			"The reducer shall use a flat-on-top orientation for pump suction service to reduce vapor pocket formation along the upper flow boundary.";
		require constraint {
			reducer.orientation == EccentricOrientationKind::flatOnTop;
		}
	}

	requirement <ER-005> FlowContinuityRequirement {
		subject pipeRun : PipeRunWithEccentricReducer;
		attribute statement : String =
			"The pipe run containing the eccentric reducer shall preserve volumetric flow continuity across the reducer during normal steady operation.";
		require constraint {
			pipeRun.operatingFlow > 0 [SI::m3_per_h];
		}
		require constraint {
			pipeRun.upstreamPressure > pipeRun.downstreamPressure;
		}
	}

	part coolingWaterReducerAssembly : PipeRunWithEccentricReducer {
		:>> serviceName = "Cooling water pump suction eccentric reducer assembly";
		:>> operatingFlow = 180 [SI::m3_per_h];
		:>> upstreamPressure = 600 [SI::kPa];
		:>> downstreamPressure = 588 [SI::kPa];

		:>> reducer {
			:>> tagNumber = "ER-CW-300x150-001";
			:>> inletNominalDiameter = 300 [SI::mm];
			:>> outletNominalDiameter = 150 [SI::mm];
			:>> centerlineOffset = 75 [SI::mm];
			:>> faceToFaceLength = 450 [SI::mm];
			:>> designPressure = 1600 [SI::kPa];
			:>> designTemperature = 423.15 [SI::K];
			:>> expectedPressureDrop = 12 [SI::kPa];
			:>> maximumAllowablePressureDrop = 25 [SI::kPa];
			:>> orientation = EccentricOrientationKind::flatOnTop;
		}
	}

	satisfy PrimaryFunctionRequirement by coolingWaterReducerAssembly.reducer;
	satisfy EccentricGeometryRequirement by coolingWaterReducerAssembly.reducer;
	satisfy PressureDropRequirement by coolingWaterReducerAssembly.reducer;
	satisfy OrientationRequirement by coolingWaterReducerAssembly.reducer;
	satisfy FlowContinuityRequirement by coolingWaterReducerAssembly;
}
