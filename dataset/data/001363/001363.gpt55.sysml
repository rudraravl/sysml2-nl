package AutonomousUnderwaterVehicleModel {

    import ScalarValues::*;

    attribute def Mass_kg :> Real {
        attribute unit : String = "kg";
    }

    attribute def Length_m :> Real {
        attribute unit : String = "m";
    }

    attribute def Diameter_m :> Real {
        attribute unit : String = "m";
    }

    attribute def Area_m2 :> Real {
        attribute unit : String = "m^2";
    }

    attribute def Volume_m3 :> Real {
        attribute unit : String = "m^3";
    }

    attribute def Speed_mps :> Real {
        attribute unit : String = "m/s";
    }

    attribute def Acceleration_mps2 :> Real {
        attribute unit : String = "m/s^2";
    }

    attribute def Force_N :> Real {
        attribute unit : String = "N";
    }

    attribute def Torque_Nm :> Real {
        attribute unit : String = "N*m";
    }

    attribute def Power_W :> Real {
        attribute unit : String = "W";
    }

    attribute def Energy_Wh :> Real {
        attribute unit : String = "W*h";
    }

    attribute def Voltage_V :> Real {
        attribute unit : String = "V";
    }

    attribute def Current_A :> Real {
        attribute unit : String = "A";
    }

    attribute def Time_s :> Real {
        attribute unit : String = "s";
    }

    attribute def Time_h :> Real {
        attribute unit : String = "h";
    }

    attribute def Pressure_kPa :> Real {
        attribute unit : String = "kPa";
    }

    attribute def Temperature_C :> Real {
        attribute unit : String = "degC";
    }

    attribute def Salinity_psu :> Real {
        attribute unit : String = "psu";
    }

    attribute def Frequency_kHz :> Real {
        attribute unit : String = "kHz";
    }

    attribute def DataRate_kbps :> Real {
        attribute unit : String = "kb/s";
    }

    attribute def Angle_deg :> Real {
        attribute unit : String = "deg";
    }

    attribute def Latitude_deg :> Real {
        attribute unit : String = "deg";
    }

    attribute def Longitude_deg :> Real {
        attribute unit : String = "deg";
    }

    attribute def Probability :> Real {
        attribute unit : String = "1";
    }

    enum def MissionPhase {
        enum idle;
        enum selfTest;
        enum dive;
        enum transit;
        enum survey;
        enum avoidObstacle;
        enum returnHome;
        enum surface;
        enum transmitReport;
        enum abort;
    }

    enum def HealthState {
        enum nominal;
        enum degraded;
        enum failed;
        enum isolated;
    }

    enum def CommandMode {
        enum holdPosition;
        enum followTrack;
        enum changeDepth;
        enum avoidObstacle;
        enum returnToRecovery;
        enum emergencySurface;
    }

    enum def WaterCurrentClass {
        enum calm;
        enum moderate;
        enum strong;
    }

    item def GeoPosition {
        attribute latitude : Latitude_deg;
        attribute longitude : Longitude_deg;
        attribute depthBelowSurface : Length_m;
        attribute horizontalUncertainty : Length_m;
        attribute verticalUncertainty : Length_m;
    }

    item def MissionWaypoint {
        attribute sequenceNumber : Integer;
        attribute position : GeoPosition;
        attribute desiredSpeed : Speed_mps;
        attribute desiredAltitudeAboveSeafloor : Length_m;
        attribute dwellTime : Time_s;
    }

    item def SurveyArea {
        attribute center : GeoPosition;
        attribute length : Length_m;
        attribute width : Length_m;
        attribute surveyLineSpacing : Length_m;
        attribute maximumDepth : Length_m;
        attribute expectedCurrent : WaterCurrentClass;
    }

    item def MissionPlan {
        attribute planIdentifier : String;
        attribute surveyArea : SurveyArea;
        attribute requestedSurveySpeed : Speed_mps;
        attribute minimumAltitudeAboveSeafloor : Length_m;
        attribute maximumAllowedDepth : Length_m;
        attribute recoveryPosition : GeoPosition;
        attribute acousticReportingInterval : Time_s;
        attribute abortBatteryThreshold : Real;
    }

    item def ElectricalPower {
        attribute voltage : Voltage_V;
        attribute current : Current_A;
        attribute power : Power_W;
    }

    item def EnergyStatus {
        attribute stateOfCharge : Real;
        attribute remainingEnergy : Energy_Wh;
        attribute estimatedRemainingEndurance : Time_h;
        attribute health : HealthState;
    }

    item def ControlCommand {
        attribute commandMode : CommandMode;
        attribute targetDepth : Length_m;
        attribute targetSpeed : Speed_mps;
        attribute targetHeading : Angle_deg;
        attribute targetAltitude : Length_m;
    }

    item def ThrustVector {
        attribute surgeForce : Force_N;
        attribute swayForce : Force_N;
        attribute heaveForce : Force_N;
        attribute yawTorque : Torque_Nm;
    }

    item def NavigationSolution {
        attribute position : GeoPosition;
        attribute speedOverGround : Speed_mps;
        attribute heading : Angle_deg;
        attribute pitch : Angle_deg;
        attribute roll : Angle_deg;
        attribute positionConfidence : Probability;
    }

    item def InertialMeasurement {
        attribute accelerationX : Acceleration_mps2;
        attribute accelerationY : Acceleration_mps2;
        attribute accelerationZ : Acceleration_mps2;
        attribute yawRate : Angle_deg;
        attribute pitchRate : Angle_deg;
        attribute rollRate : Angle_deg;
    }

    item def DepthMeasurement {
        attribute depth : Length_m;
        attribute pressure : Pressure_kPa;
        attribute waterTemperature : Temperature_C;
    }

    item def DopplerVelocityMeasurement {
        attribute velocityForward : Speed_mps;
        attribute velocityStarboard : Speed_mps;
        attribute velocityDown : Speed_mps;
        attribute altitudeAboveBottom : Length_m;
        attribute bottomLockValid : Boolean;
    }

    item def ObstacleMap {
        attribute nearestObstacleRange : Length_m;
        attribute nearestObstacleBearing : Angle_deg;
        attribute freePathBearing : Angle_deg;
        attribute safeCorridorWidth : Length_m;
        attribute obstacleDetected : Boolean;
    }

    item def SonarImage {
        attribute centerFrequency : Frequency_kHz;
        attribute swathWidth : Length_m;
        attribute alongTrackResolution : Length_m;
        attribute crossTrackResolution : Length_m;
        attribute qualityScore : Real;
    }

    item def WaterQualitySample {
        attribute temperature : Temperature_C;
        attribute salinity : Salinity_psu;
        attribute pressure : Pressure_kPa;
        attribute sampleDepth : Length_m;
        attribute dissolvedOxygenPercent : Real;
    }

    item def SurveyData {
        attribute sonarImage : SonarImage;
        attribute waterQuality : WaterQualitySample;
        attribute navigationAtCollection : NavigationSolution;
        attribute timestampSecondsFromMissionStart : Time_s;
    }

    item def AcousticMessage {
        attribute messageIdentifier : String;
        attribute payloadSize : Integer;
        attribute dataRate : DataRate_kbps;
        attribute acknowledged : Boolean;
    }

    item def MissionReport {
        attribute planIdentifier : String;
        attribute missionCompleted : Boolean;
        attribute totalDistanceTravelled : Length_m;
        attribute totalSubmergedTime : Time_h;
        attribute finalEnergyState : EnergyStatus;
        attribute numberOfSurveyRecords : Integer;
        attribute anomaliesDetected : Integer;
    }

    item def FaultReport {
        attribute faultCode : String;
        attribute healthState : HealthState;
        attribute severity : Integer;
        attribute recommendedCommandMode : CommandMode;
    }

    item def PowerOnCommand;
    item def LaunchCommand;
    item def DiveCommand;
    item def SurveyAreaReached;
    item def SurveyComplete;
    item def ObstacleDetected;
    item def ObstacleCleared;
    item def AbortCommand;
    item def RecoveryReached;
    item def SurfaceReached;
    item def ReportTransmitted;

    port def ElectricalSourcePort {
        out item suppliedPower : ElectricalPower;
    }

    port def ElectricalLoadPort {
        in item receivedPower : ElectricalPower;
    }

    port def EnergyStatusOutPort {
        out item status : EnergyStatus;
    }

    port def EnergyStatusInPort {
        in item status : EnergyStatus;
    }

    port def MissionPlanInPort {
        in item plan : MissionPlan;
    }

    port def MissionReportOutPort {
        out item report : MissionReport;
    }

    port def CommandInPort {
        in item command : ControlCommand;
    }

    port def CommandOutPort {
        out item command : ControlCommand;
    }

    port def ThrustOutPort {
        out item thrust : ThrustVector;
    }

    port def NavigationOutPort {
        out item navigation : NavigationSolution;
    }

    port def NavigationInPort {
        in item navigation : NavigationSolution;
    }

    port def InertialOutPort {
        out item measurement : InertialMeasurement;
    }

    port def DepthOutPort {
        out item measurement : DepthMeasurement;
    }

    port def DopplerOutPort {
        out item measurement : DopplerVelocityMeasurement;
    }

    port def ObstacleMapOutPort {
        out item obstacleMap : ObstacleMap;
    }

    port def ObstacleMapInPort {
        in item obstacleMap : ObstacleMap;
    }

    port def SurveyDataOutPort {
        out item surveyData : SurveyData;
    }

    port def SurveyDataInPort {
        in item surveyData : SurveyData;
    }

    port def AcousticInOutPort {
        inout item message : AcousticMessage;
    }

    port def FaultReportOutPort {
        out item fault : FaultReport;
    }

    port def FaultReportInPort {
        in item fault : FaultReport;
    }

    part def PressureHull {
        attribute dryMass : Mass_kg = 72.0;
        attribute length : Length_m = 3.20;
        attribute outsideDiameter : Diameter_m = 0.42;
        attribute internalUsableVolume : Volume_m3 = 0.21;
        attribute ratedDepth : Length_m = 600.0;
        attribute collapsePressure : Pressure_kPa = 6900.0;
        attribute dragReferenceArea : Area_m2 = 0.138;
    }

    part def EnergyStorageSystem {
        attribute batteryChemistry : String = "lithium-ion pressure-tolerant module";
        attribute nominalVoltage : Voltage_V = 48.0;
        attribute usableCapacity : Energy_Wh = 9600.0;
        attribute maximumContinuousOutput : Power_W = 2600.0;
        attribute stateOfCharge : Real = 1.0;
        attribute dryMass : Mass_kg = 48.0;

        port dcOutput : ElectricalSourcePort;
        port statusOutput : EnergyStatusOutPort;
    }

    part def PowerDistributionUnit {
        attribute regulatedBusVoltage : Voltage_V = 24.0;
        attribute maximumTotalLoad : Power_W = 2400.0;
        attribute conversionEfficiency : Real = 0.94;

        port dcInput : ElectricalLoadPort;
        port propulsionOutput : ElectricalSourcePort;
        port computerOutput : ElectricalSourcePort;
        port sensorOutput : ElectricalSourcePort;
        port communicationsOutput : ElectricalSourcePort;
        port buoyancyOutput : ElectricalSourcePort;
        port safetyOutput : ElectricalSourcePort;
    }

    part def PropulsionSystem {
        attribute thrusterCount : Integer = 4;
        attribute maximumSurgeThrust : Force_N = 180.0;
        attribute maximumYawTorque : Torque_Nm = 58.0;
        attribute cruisePowerAtSurveySpeed : Power_W = 720.0;
        attribute propellerDiameter : Diameter_m = 0.18;

        port powerInput : ElectricalLoadPort;
        port commandInput : CommandInPort;
        port thrustOutput : ThrustOutPort;
    }

    part def BuoyancyAndTrimSystem {
        attribute variableBallastVolume : Volume_m3 = 0.012;
        attribute trimMassTravel : Length_m = 0.35;
        attribute maximumDepthRate : Speed_mps = 0.35;
        attribute neutralBuoyancyOffset : Force_N = 3.0;

        port powerInput : ElectricalLoadPort;
        port commandInput : CommandInPort;
        port faultOutput : FaultReportOutPort;
    }

    abstract part def NavigationSensor {
        attribute health : HealthState = HealthState::nominal;
        port powerInput : ElectricalLoadPort;
    }

    part def InertialMeasurementUnit :> NavigationSensor {
        attribute biasStability : Angle_deg = 0.02;
        port inertialOutput : InertialOutPort;
    }

    part def DopplerVelocityLog :> NavigationSensor {
        attribute bottomLockMaximumAltitude : Length_m = 120.0;
        attribute velocityAccuracy : Speed_mps = 0.003;
        port dopplerOutput : DopplerOutPort;
    }

    part def DepthPressureSensor :> NavigationSensor {
        attribute ratedDepth : Length_m = 1000.0;
        attribute depthAccuracy : Length_m = 0.05;
        port depthOutput : DepthOutPort;
    }

    part def NavigationSystem {
        attribute nominalPositionErrorSubmerged : Length_m = 12.0;
        attribute surfacingGnssPositionError : Length_m = 2.5;
        attribute updatePeriod : Time_s = 0.2;

        port powerInput : ElectricalLoadPort;
        port commandInput : CommandInPort;
        port navigationOutput : NavigationOutPort;

        part imu : InertialMeasurementUnit;
        part dvl : DopplerVelocityLog;
        part depthSensor : DepthPressureSensor;

        connect powerInput to imu.powerInput;
        connect powerInput to dvl.powerInput;
        connect powerInput to depthSensor.powerInput;
    }

    part def PerceptionSystem {
        attribute forwardSonarFrequency : Frequency_kHz = 900.0;
        attribute forwardSonarRange : Length_m = 80.0;
        attribute minimumObstacleClearance : Length_m = 8.0;
        attribute obstacleMapUpdatePeriod : Time_s = 0.5;

        port powerInput : ElectricalLoadPort;
        port navigationInput : NavigationInPort;
        port obstacleMapOutput : ObstacleMapOutPort;
    }

    part def PayloadSurveySensorSuite {
        attribute sideScanFrequency : Frequency_kHz = 600.0;
        attribute nominalSwathWidth : Length_m = 120.0;
        attribute alongTrackResolution : Length_m = 0.25;
        attribute ctdSamplePeriod : Time_s = 2.0;
        attribute payloadPower : Power_W = 170.0;

        port powerInput : ElectricalLoadPort;
        port navigationInput : NavigationInPort;
        port surveyDataOutput : SurveyDataOutPort;
    }

    part def AcousticCommunicationSystem {
        attribute nominalRange : Length_m = 3000.0;
        attribute nominalDataRate : DataRate_kbps = 9.6;
        attribute emergencyBeaconPower : Power_W = 25.0;
        attribute reportingInterval : Time_s = 300.0;

        port powerInput : ElectricalLoadPort;
        port acousticLink : AcousticInOutPort;
        port reportInput : MissionReportOutPort;
    }

    part def MissionComputer {
        attribute processorPower : Power_W = 65.0;
        attribute storageCapacityRecords : Integer = 250000;
        attribute controlLoopPeriod : Time_s = 0.1;
        attribute activeMissionPhase : MissionPhase = MissionPhase::idle;

        port powerInput : ElectricalLoadPort;
        port missionPlanInput : MissionPlanInPort;
        port energyStatusInput : EnergyStatusInPort;
        port navigationInput : NavigationInPort;
        port obstacleMapInput : ObstacleMapInPort;
        port surveyDataInput : SurveyDataInPort;
        port propulsionCommandOutput : CommandOutPort;
        port buoyancyCommandOutput : CommandOutPort;
        port navigationCommandOutput : CommandOutPort;
        port acousticMessagePort : AcousticInOutPort;
        port missionReportOutput : MissionReportOutPort;
        port faultInput : FaultReportInPort;
    }

    part def SafetySystem {
        attribute abortDepthLimit : Length_m = 580.0;
        attribute abortBatteryThreshold : Real = 0.18;
        attribute leakDetected : Boolean = false;
        attribute emergencyDropWeightMass : Mass_kg = 8.0;
        attribute emergencySurfaceAscentRate : Speed_mps = 0.45;

        port powerInput : ElectricalLoadPort;
        port energyStatusInput : EnergyStatusInPort;
        port navigationInput : NavigationInPort;
        port faultInput : FaultReportInPort;
        port emergencyCommandOutput : CommandOutPort;
        port faultOutput : FaultReportOutPort;
    }

    action def ReceiveMissionPlan {
        in item uploadedPlan : MissionPlan;
        out item acceptedPlan : MissionPlan;
    }

    action def PerformPreDiveSelfTest {
        in item plan : MissionPlan;
        in item energy : EnergyStatus;
        out item ready : Boolean;
        out item fault : FaultReport;
    }

    action def DiveToSurveyDepth {
        in item plan : MissionPlan;
        in item navigation : NavigationSolution;
        out item depthCommand : ControlCommand;
    }

    action def NavigateSurveyTrack {
        in item plan : MissionPlan;
        in item navigation : NavigationSolution;
        out item propulsionCommand : ControlCommand;
        out item buoyancyCommand : ControlCommand;
    }

    action def CollectSurveyData {
        in item navigation : NavigationSolution;
        out item surveyData : SurveyData;
    }

    action def AvoidObstacle {
        in item obstacleMap : ObstacleMap;
        in item navigation : NavigationSolution;
        out item avoidanceCommand : ControlCommand;
    }

    action def ReturnToRecoveryPoint {
        in item plan : MissionPlan;
        in item navigation : NavigationSolution;
        out item returnCommand : ControlCommand;
    }

    action def SurfaceAndTransmitReport {
        in item surveyData : SurveyData;
        in item energy : EnergyStatus;
        out item report : MissionReport;
        out item acousticMessage : AcousticMessage;
    }

    action def ExecuteAutonomousUnderwaterMission {
        in item missionPlan : MissionPlan;
        in item initialPosition : GeoPosition;
        out item missionReport : MissionReport;

        action receivePlan : ReceiveMissionPlan;
        action selfTest : PerformPreDiveSelfTest;
        action dive : DiveToSurveyDepth;
        action transitAndSurvey : NavigateSurveyTrack;
        action collectData : CollectSurveyData;
        action avoidObstacles : AvoidObstacle;
        action returnHome : ReturnToRecoveryPoint;
        action surfaceAndReport : SurfaceAndTransmitReport;

        first receivePlan;
        then selfTest;
        then dive;
        then transitAndSurvey;
        then collectData;
        then returnHome;
        then surfaceAndReport;
    }

    state def AUVOperationalStates {
        state poweredOff;
        state standby;
        state preDiveSelfTest;
        state diving;
        state transitingToSurveyArea;
        state surveying;
        state obstacleAvoidance;
        state returningToRecovery;
        state surfacing;
        state transmittingReport;
        state safeAbort;

        transition initialTransition first start then poweredOff;
        transition powerOnTransition first poweredOff then standby accept PowerOnCommand;
        transition launchTransition first standby then preDiveSelfTest accept LaunchCommand;
        transition diveTransition first preDiveSelfTest then diving accept DiveCommand;
        transition transitTransition first diving then transitingToSurveyArea;
        transition surveyStartTransition first transitingToSurveyArea then surveying accept SurveyAreaReached;
        transition obstacleDetectedTransition first surveying then obstacleAvoidance accept ObstacleDetected;
        transition obstacleClearedTransition first obstacleAvoidance then surveying accept ObstacleCleared;
        transition surveyCompleteTransition first surveying then returningToRecovery accept SurveyComplete;
        transition recoveryTransition first returningToRecovery then surfacing accept RecoveryReached;
        transition surfaceTransition first surfacing then transmittingReport accept SurfaceReached;
        transition reportCompleteTransition first transmittingReport then standby accept ReportTransmitted;
        transition abortFromDive first diving then safeAbort accept AbortCommand;
        transition abortFromTransit first transitingToSurveyArea then safeAbort accept AbortCommand;
        transition abortFromSurvey first surveying then safeAbort accept AbortCommand;
        transition abortFromAvoidance first obstacleAvoidance then safeAbort accept AbortCommand;
        transition abortFromReturn first returningToRecovery then safeAbort accept AbortCommand;
    }

    part def AutonomousUnderwaterVehicle {
        attribute vehicleName : String = "AUV-Explorer-600";
        attribute primaryFunction : String = "Autonomously navigate underwater, execute a planned survey, collect sonar and water-quality data, avoid hazards, and return to a recovery location with a mission report.";
        attribute dryMass : Mass_kg = 185.0;
        attribute submergedDisplacement : Mass_kg = 188.0;
        attribute overallLength : Length_m = 3.20;
        attribute maximumOperatingDepth : Length_m = 600.0;
        attribute nominalSurveySpeed : Speed_mps = 1.5;
        attribute maximumSpeed : Speed_mps = 2.6;
        attribute nominalEndurance : Time_h = 12.0;
        attribute minimumTurnRadius : Length_m = 7.5;
        attribute requiredObstacleClearance : Length_m = 8.0;

        port missionUpload : MissionPlanInPort;
        port acousticExternal : AcousticInOutPort;
        port missionReportDownload : MissionReportOutPort;

        part hull : PressureHull;
        part energyStorage : EnergyStorageSystem;
        part powerDistribution : PowerDistributionUnit;
        part propulsion : PropulsionSystem;
        part buoyancyAndTrim : BuoyancyAndTrimSystem;
        part navigation : NavigationSystem;
        part perception : PerceptionSystem;
        part payloadSensors : PayloadSurveySensorSuite;
        part acousticCommunications : AcousticCommunicationSystem;
        part missionComputer : MissionComputer;
        part safety : SafetySystem;

        exhibit state operationalStates : AUVOperationalStates;
        perform action autonomousMission : ExecuteAutonomousUnderwaterMission;

        connect missionUpload to missionComputer.missionPlanInput;
        connect missionReportDownload to missionComputer.missionReportOutput;
        connect acousticExternal to acousticCommunications.acousticLink;
        connect acousticExternal to missionComputer.acousticMessagePort;

        connect energyStorage.dcOutput to powerDistribution.dcInput;
        connect energyStorage.statusOutput to missionComputer.energyStatusInput;
        connect energyStorage.statusOutput to safety.energyStatusInput;

        connect powerDistribution.propulsionOutput to propulsion.powerInput;
        connect powerDistribution.computerOutput to missionComputer.powerInput;
        connect powerDistribution.sensorOutput to navigation.powerInput;
        connect powerDistribution.sensorOutput to perception.powerInput;
        connect powerDistribution.sensorOutput to payloadSensors.powerInput;
        connect powerDistribution.communicationsOutput to acousticCommunications.powerInput;
        connect powerDistribution.buoyancyOutput to buoyancyAndTrim.powerInput;
        connect powerDistribution.safetyOutput to safety.powerInput;

        connect missionComputer.propulsionCommandOutput to propulsion.commandInput;
        connect missionComputer.buoyancyCommandOutput to buoyancyAndTrim.commandInput;
        connect missionComputer.navigationCommandOutput to navigation.commandInput;
        connect safety.emergencyCommandOutput to propulsion.commandInput;
        connect safety.emergencyCommandOutput to buoyancyAndTrim.commandInput;

        connect navigation.navigationOutput to missionComputer.navigationInput;
        connect navigation.navigationOutput to perception.navigationInput;
        connect navigation.navigationOutput to payloadSensors.navigationInput;
        connect navigation.navigationOutput to safety.navigationInput;

        connect perception.obstacleMapOutput to missionComputer.obstacleMapInput;
        connect payloadSensors.surveyDataOutput to missionComputer.surveyDataInput;

        connect buoyancyAndTrim.faultOutput to missionComputer.faultInput;
        connect buoyancyAndTrim.faultOutput to safety.faultInput;
        connect safety.faultOutput to missionComputer.faultInput;
        connect missionComputer.missionReportOutput to acousticCommunications.reportInput;
    }

    constraint def EnduranceConstraint {
        in endurance : Time_h;
        endurance >= 8.0;
    }

    constraint def DepthRatingConstraint {
        in operatingDepth : Length_m;
        in ratedDepth : Length_m;
        operatingDepth <= ratedDepth;
    }

    constraint def ObstacleClearanceConstraint {
        in clearance : Length_m;
        clearance >= 8.0;
    }

    constraint def SurveySpeedConstraint {
        in speed : Speed_mps;
        speed >= 1.0 and speed <= 2.0;
    }

    requirement def PrimaryFunctionRequirement {
        subject auv : AutonomousUnderwaterVehicle;
        doc /* The autonomous underwater vehicle shall perform its primary high-level function without continuous human control: receive a mission plan, dive, navigate underwater through a defined survey area, collect sonar and environmental data, avoid obstacles, return to the recovery location, surface, and deliver a mission report. */
    }

    requirement def EnduranceRequirement {
        subject auv : AutonomousUnderwaterVehicle;
        doc /* The vehicle shall provide sufficient stored energy to support at least 8 hours of submerged autonomous survey operation. */
        require constraint EnduranceConstraint {
            endurance = auv.nominalEndurance;
        }
    }

    requirement def OperatingDepthRequirement {
        subject auv : AutonomousUnderwaterVehicle;
        doc /* The vehicle shall operate safely to a depth of 600 m without exceeding the pressure hull rating. */
        require constraint DepthRatingConstraint {
            operatingDepth = auv.maximumOperatingDepth;
            ratedDepth = auv.hull.ratedDepth;
        }
    }

    requirement def ObstacleAvoidanceRequirement {
        subject auv : AutonomousUnderwaterVehicle;
        doc /* The vehicle shall maintain at least 8 m clearance from detected obstacles during autonomous transit and survey operations. */
        require constraint ObstacleClearanceConstraint {
            clearance = auv.requiredObstacleClearance;
        }
    }

    requirement def SurveyPerformanceRequirement {
        subject auv : AutonomousUnderwaterVehicle;
        doc /* The vehicle shall conduct nominal seabed survey lines at a speed between 1.0 m/s and 2.0 m/s while collecting side-scan sonar and water-quality data. */
        require constraint SurveySpeedConstraint {
            speed = auv.nominalSurveySpeed;
        }
    }

    requirement def RecoveryReportingRequirement {
        subject auv : AutonomousUnderwaterVehicle;
        doc /* The vehicle shall return to the planned recovery position, surface, and transmit a mission report containing completion status, submerged time, distance travelled, energy status, survey record count, and anomaly count. */
    }

    part auvExplorer600 : AutonomousUnderwaterVehicle {
        attribute vehicleName = "AUV-Explorer-600";
        attribute dryMass = 185.0;
        attribute submergedDisplacement = 188.0;
        attribute nominalEndurance = 12.0;
        attribute maximumOperatingDepth = 600.0;
        attribute nominalSurveySpeed = 1.5;
    }

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject auv = auvExplorer600;
    }

    requirement endurance : EnduranceRequirement {
        subject auv = auvExplorer600;
    }

    requirement operatingDepth : OperatingDepthRequirement {
        subject auv = auvExplorer600;
    }

    requirement obstacleAvoidance : ObstacleAvoidanceRequirement {
        subject auv = auvExplorer600;
    }

    requirement surveyPerformance : SurveyPerformanceRequirement {
        subject auv = auvExplorer600;
    }

    requirement recoveryReporting : RecoveryReportingRequirement {
        subject auv = auvExplorer600;
    }
}
