package ContinuousTrackSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TrackTensionValue :> ForceValue;
	attribute def WearLevelValue :> Real;
	attribute def TerrainTypeValue :> String;
	
	value def TrackSegment {
		attribute segmentLength : LengthValue;
		attribute segmentMass : MassValue;
		attribute wearLevel : WearLevelValue;
		attribute tensileStrength : ForceValue;
	}
	
	value def DriveCommand {
		attribute targetSpeed : SpeedValue;
		attribute targetTorque : TorqueValue;
	}
	
	value def GroundContact {
		attribute contactLength : LengthValue;
		attribute contactWidth : LengthValue;
		attribute normalForce : ForceValue;
		attribute frictionCoefficient : Real;
	}
	
	item def TrackLink {
		attribute linkMass : MassValue;
		attribute linkLength : LengthValue;
		attribute pinDiameter : LengthValue;
	}
	
	item def TrackPad {
		attribute padThickness : LengthValue;
		attribute padWidth : LengthValue;
		attribute grouserHeight : LengthValue;
	}
	
	port def MechanicalDrivePort {
		attribute inputTorque : TorqueValue;
		attribute rotationalSpeed : AngularVelocityValue;
		attribute outputForce : ForceValue;
	}
	
	port def LoadBearingPort {
		attribute verticalLoad : ForceValue;
		attribute deflection : LengthValue;
	}
	
	port def TerrainInterfacePort {
		attribute contactArea : AreaValue;
		attribute groundPressure : PressureValue;
		attribute tractionForce : ForceValue;
	}
	
	part def DriveWheel {
		attribute diameter : LengthValue;
		attribute numberOfTeeth : Integer;
		attribute hubMass : MassValue;
		port driveInput : MechanicalDrivePort;
	}
	
	part def IdlerWheel {
		attribute diameter : LengthValue;
		attribute bearingType : String;
		attribute adjustmentRange : LengthValue;
	}
	
	part def RoadWheel {
		attribute diameter : LengthValue;
		attribute suspensionTravel : LengthValue;
		attribute springRate : Real;
		port loadPort : LoadBearingPort;
	}
	
	part def TrackChain {
		attribute totalLinks : Integer;
		attribute totalLength : LengthValue;
		attribute width : LengthValue;
		attribute currentTension : TrackTensionValue;
		attribute maxTension : TrackTensionValue;
		attribute overallWear : WearLevelValue;
		part links : TrackLink[*];
		part pads : TrackPad[*];
	}
	
	part def TrackFrame {
		attribute frameLength : LengthValue;
		attribute frameHeight : LengthValue;
		attribute frameMass : MassValue;
		attribute material : String;
	}
	
	part def TensioningMechanism {
		attribute tensionForce : ForceValue;
		attribute adjustmentPosition : LengthValue;
		attribute maxAdjustment : LengthValue;
	}
	
	part def ContinuousTrackAssembly {
		doc /* A continuous track assembly that distributes vehicle weight over a large surface area,
		     providing superior traction and mobility on soft, uneven, or challenging terrain. */
		
		attribute vehicleMass : MassValue;
		attribute operatingSpeed : SpeedValue;
		attribute maxSpeed : SpeedValue;
		attribute trackPitch : LengthValue;
		
		part driveWheel : DriveWheel {
			attribute diameter = 650.0 [mm];
			attribute numberOfTeeth = 20;
			attribute hubMass = 45.0 [kg];
		}
		
		part frontIdler : IdlerWheel {
			attribute diameter = 550.0 [mm];
			attribute bearingType = "sealed roller";
			attribute adjustmentRange = 150.0 [mm];
		}
		
		part rearIdler : IdlerWheel {
			attribute diameter = 550.0 [mm];
			attribute bearingType = "sealed roller";
			attribute adjustmentRange = 150.0 [mm];
		}
		
		part roadWheels : RoadWheel[8] {
			attribute diameter = 480.0 [mm];
			attribute suspensionTravel = 250.0 [mm];
			attribute springRate = 120.0;
		}
		
		part trackChain : TrackChain {
			attribute totalLinks = 120;
			attribute totalLength = 5200.0 [mm];
			attribute width = 450.0 [mm];
			attribute currentTension = 18000.0 [N];
			attribute maxTension = 28000.0 [N];
			attribute overallWear = 0.25;
		}
		
		part trackFrame : TrackFrame {
			attribute frameLength = 3800.0 [mm];
			attribute frameHeight = 600.0 [mm];
			attribute frameMass = 950.0 [kg];
			attribute material = "high-strength steel";
		}
		
		part tensioner : TensioningMechanism {
			attribute tensionForce = 18000.0 [N];
			attribute adjustmentPosition = 75.0 [mm];
			attribute maxAdjustment = 150.0 [mm];
		}
		
		port driveInterface : MechanicalDrivePort;
		port terrainInterface : TerrainInterfacePort;
		port suspensionPorts : LoadBearingPort[8];
		
		connect driveInterface to driveWheel.driveInput;
		
		perform action trackOperation : operateTrackSystem;
	}
	
	action def MonitorTrackCondition {
		in trackAssembly : ContinuousTrackAssembly;
		out currentTension : TrackTensionValue;
		out wearLevel : WearLevelValue;
		out tensionStatus : String;
	}
	
	action def AdjustTension {
		in targetTension : TrackTensionValue;
		in currentTension : TrackTensionValue;
		in maxAdjustment : LengthValue;
		out adjustmentDistance : LengthValue;
		out newTension : TrackTensionValue;
	}
	
	action def CalculateTraction {
		in vehicleMass : MassValue;
		in groundContact : GroundContact;
		in driveCommand : DriveCommand;
		out tractionForce : ForceValue;
		out availableTraction : ForceValue;
	}
	
	action def DistributeLoad {
		in totalLoad : ForceValue;
		in numberOfWheels : Integer;
		in trackContactLength : LengthValue;
		in trackWidth : LengthValue;
		out loadPerWheel : ForceValue;
		out groundPressure : PressureValue;
	}
	
	action def EvaluateWear {
		in operatingTime : TimeValue;
		in terrainCondition : TerrainTypeValue;
		in currentWear : WearLevelValue;
		in trackSpeed : SpeedValue;
		out wearRate : Real;
		out estimatedRemainingLife : TimeValue;
		out maintenanceRequired : Boolean;
	}
	
	action def ApplyDriveTorque {
		in driveCommand : DriveCommand;
		in wheelDiameter : LengthValue;
		in numberOfTeeth : Integer;
		out outputForce : ForceValue;
		out linearSpeed : SpeedValue;
	}
	
	action def operateTrackSystem {
		doc /* Primary operational behavior: continuously distribute vehicle load across terrain
		     while generating traction force through the drive wheel to propel the vehicle. */
		
		first start;
		
		then action initialize {
			out systemMass : MassValue;
			out contactArea : AreaValue;
			out initialTension : TrackTensionValue;
		}
		
		then merge operationLoop;
		
		then action monitorCondition : MonitorTrackCondition {
			in trackAssembly;
			out currentTension;
			out wearLevel;
			out tensionStatus;
		}
		
		then decide;
			if monitorCondition.currentTension < 15000.0 [N] then increaseTension;
			if monitorCondition.currentTension > 22000.0 [N] then decreaseTension;
			if monitorCondition.currentTension >= 15000.0 [N] and 
			   monitorCondition.currentTension <= 22000.0 [N] then applyDrive;
		
		action increaseTension : AdjustTension {
			in targetTension = 18000.0 [N];
			in currentTension = monitorCondition.currentTension;
			in maxAdjustment = 150.0 [mm];
			out adjustmentDistance;
			out newTension;
		}
		then applyDrive;
		
		action decreaseTension : AdjustTension {
			in targetTension = 18000.0 [N];
			in currentTension = monitorCondition.currentTension;
			in maxAdjustment = 150.0 [mm];
			out adjustmentDistance;
			out newTension;
		}
		then applyDrive;
		
		action applyDrive : ApplyDriveTorque {
			in driveCommand : DriveCommand;
			in wheelDiameter = 650.0 [mm];
			in numberOfTeeth = 20;
			out outputForce;
			out linearSpeed;
		}
		
		then action calculateTraction : CalculateTraction {
			in vehicleMass = initialize.systemMass;
			in groundContact : GroundContact;
			in driveCommand : DriveCommand;
			out tractionForce;
			out availableTraction;
		}
		
		then action distributeLoad : DistributeLoad {
			in totalLoad : ForceValue;
			in numberOfWheels = 8;
			in trackContactLength = 3200.0 [mm];
			in trackWidth = 450.0 [mm];
			out loadPerWheel;
			out groundPressure;
		}
		
		then action evaluateWear : EvaluateWear {
			in operatingTime : TimeValue;
			in terrainCondition : TerrainTypeValue;
			in currentWear = monitorCondition.wearLevel;
			in trackSpeed = applyDrive.linearSpeed;
			out wearRate;
			out estimatedRemainingLife;
			out maintenanceRequired;
		}
		
		then decide;
			if evaluateWear.maintenanceRequired then scheduleService;
			if not evaluateWear.maintenanceRequired then operationLoop;
		
		action scheduleService {
			doc /* Schedule maintenance when wear exceeds threshold or remaining life is low */
		}
		then done;
	}
	
	state def TrackSystemStates {
		entry; then parked;
		
		state parked {
			doc /* Track system at rest with minimal tension */
		}
		accept at when tensionCommand
		do action applyInitialTension
		then tensioned;
		
		state tensioned {
			doc /* Track properly tensioned and ready for operation */
		}
		accept at when driveCommand
		then driving;
		
		state driving {
			doc /* Track system actively propelling vehicle */
		}
		accept at when stopCommand
		then braking;
		
		accept at when overloadDetected
		then overload;
		
		state braking {
			doc /* Decelerating to stop */
		}
		accept at when stopped
		then tensioned;
		
		state overload {
			doc /* Excessive load or tension detected */
		}
		accept at when loadReduced
		then tensioned;
		
		accept at when maintenanceRequired
		then maintenance;
		
		state maintenance {
			doc /* Track system undergoing service */
		}
		accept at when maintenanceComplete
		then parked;
	}
	
	requirement def <'REQ-001'> trackTensionRequirement {
		doc /* The continuous track tension shall be maintained between 15000 N and 22000 N 
		     during operation to ensure proper engagement with drive wheel and prevent 
		     excessive wear or track slippage. */
		
		subject trackSystem : ContinuousTrackAssembly;
		
		require constraint {
			trackSystem.trackChain.currentTension >= 15000.0 [N] and 
			trackSystem.trackChain.currentTension <= 22000.0 [N]
		}
	}
	
	requirement def <'REQ-002'> groundPressureRequirement {
		doc /* The ground pressure exerted by the continuous track system shall not exceed 
		     65 kPa to minimize terrain damage and ensure mobility on soft ground such as 
		     mud, sand, or snow. */
		
		subject trackSystem : ContinuousTrackAssembly;
		
		require constraint {
			trackSystem.terrainInterface.groundPressure <= 65000.0 [Pa]
		}
	}
	
	requirement def <'REQ-003'> tractionRequirement {
		doc /* The continuous track system shall provide sufficient traction force to propel 
		     the vehicle mass with a minimum coefficient of friction of 0.65 on standard 
		     terrain conditions. */
		
		subject trackSystem : ContinuousTrackAssembly;
		
		assume constraint terrainFrictionAssumption {
			doc /* Terrain provides minimum friction coefficient of 0.65 */
		}
		
		require constraint {
			trackSystem.terrainInterface.tractionForce >= 
			trackSystem.vehicleMass * 9.81 [m/s^2] * 0.65
		}
	}
	
	requirement def <'REQ-004'> wearLimitRequirement {
		doc /* The continuous track wear level shall not exceed 0.75 during normal operation, 
		     and the system shall alert operators when wear reaches 0.65 to schedule 
		     preventive maintenance. */
		
		subject trackSystem : ContinuousTrackAssembly;
		
		require constraint {
			trackSystem.trackChain.overallWear <= 0.75
		}
	}
	
	requirement def <'REQ-005'> loadDistributionRequirement {
		doc /* The continuous track system shall distribute vehicle load across a minimum of 
		     8 road wheels to ensure even weight distribution and minimize point loading 
		     on terrain. */
		
		subject trackSystem : ContinuousTrackAssembly;
		
		require constraint {
			trackSystem.roadWheels->size() >= 8
		}
	}
	
	requirement <'SYS-REQ-001'> primaryTrackSystemRequirement {
		doc /* The continuous track system shall distribute vehicle weight over an extended 
		     contact area to reduce ground pressure, while simultaneously generating traction 
		     through positive engagement between the drive wheel and track chain, enabling 
		     superior mobility on challenging terrain compared to wheeled vehicles. */
		
		subject trackSystem : ContinuousTrackAssembly;
		
		require trackTensionRequirement;
		require groundPressureRequirement;
		require tractionRequirement;
		require wearLimitRequirement;
		require loadDistributionRequirement;
	}
	
	part continuousTrackVehicle : ContinuousTrackAssembly {
		attribute vehicleMass = 18000.0 [kg];
		attribute operatingSpeed = 8.5 [m/s];
		attribute maxSpeed = 12.0 [m/s];
		attribute trackPitch = 160.0 [mm];
		
		perform action trackOperation : operateTrackSystem;
		
		satisfy primaryTrackSystemRequirement;
	}
}
