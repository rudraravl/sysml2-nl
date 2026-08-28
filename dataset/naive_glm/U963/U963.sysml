package AerobotSystem {
    import ScalarValues::*;
    
    // ==================== Units ====================
    unit m;
    unit s;
    unit kg;
    unit K;
    unit Pa;
    unit N;
    unit W;
    unit J;
    unit Hz;
    unit rad;
    unit V;
    unit A;
    unit C;
    
    // ==================== Value Types ====================
    value type Altitude :> Real { :>> unit = m; }
    value type Temperature :> Real { :>> unit = K; }
    value type PressureValue :> Real { :>> unit = Pa; }
    value type VelocityValue :> Real { :>> unit = m / s; }
    value type MassValue :> Real { :>> unit = kg; }
    value type VolumeValue :> Real { :>> unit = m * m * m; }
    value type PowerValue :> Real { :>> unit = W; }
    value type EnergyValue :> Real { :>> unit = J; }
    value type AngleValue :> Real { :>> unit = rad; }
    value type DurationValue :> Real { :>> unit = s; }
    value type FrequencyValue :> Real { :>> unit = Hz; }
    value type ForceValue :> Real { :>> unit = N; }
    value type MassFlowRateValue :> Real { :>> unit = kg / s; }
    value type VolumeFlowRateValue :> Real { :>> unit = m * m * m / s; }
    value type VoltageValue :> Real { :>> unit = V; }
    value type CurrentValue :> Real { :>> unit = A; }
    value type ChargeValue :> Real { :>> unit = C; }
    value type AreaValue :> Real { :>> unit = m * m; }
    value type DataSizeValue :> Integer;
    value type DataRateValue :> Real;
    value type LatitudeValue :> Real;
    value type LongitudeValue :> Real;
    value type ConfidenceValue :> Real;
    
    // ==================== Enumerations ====================
    enumeration FlightStatusType { standby; ascending; cruising; descending; communicating; safeMode; }
    enumeration CommandTypeType { gotoWaypoint; collectData; transmitData; changeAltitude; abort; }
    enumeration ValveCommandType { open; close; regulate; }
    enumeration ValveStateType { opened; closed; regulating; }
    enumeration MissionPhaseType { ascent; cruise; descent; communication; }
    enumeration InstrumentStateType { idle; capturing; processing; transmitting; }
    enumeration PowerStateType { charging; discharging; balanced; lowPower; }
    enumeration SolarStateType { illuminated; shadowed; }
    
    // ==================== Item Definitions ====================
    item def PositionData {
        attribute latitude : LatitudeValue;
        attribute longitude : LongitudeValue;
        attribute altitude : Altitude;
    }
    
    item def EnvironmentalData {
        attribute temperature : Temperature;
        attribute pressure : PressureValue;
        attribute windSpeed : VelocityValue;
        attribute windDirection : AngleValue;
        attribute altitude : Altitude;
        attribute timestamp : DurationValue;
    }
    
    item def ScienceData {
        attribute imageCount : DataSizeValue;
        attribute spectralReadings : DataSizeValue;
        attribute particleCounts : DataSizeValue;
        attribute totalSize : DataSizeValue;
        attribute timestamp : DurationValue;
    }
    
    item def TelemetryMessage {
        attribute environmentalData : EnvironmentalData;
        attribute scienceData : ScienceData;
        attribute position : PositionData;
        attribute status : FlightStatusType;
    }
    
    item def HighLevelCommand {
        attribute commandType : CommandTypeType;
        attribute targetWaypoint : PositionData;
    }
    
    item def AltitudeCommand {
        attribute targetAltitude : Altitude;
        attribute ascentRate : VelocityValue;
    }
    
    item def GasControlSignal {
        attribute valveCommand : ValveCommandType;
        attribute flowRate : VolumeFlowRateValue;
    }
    
    item def BallastReleaseCommand {
        attribute releaseMass : MassValue;
    }
    
    item def LiftData {
        attribute liftForce : ForceValue;
        attribute gasVolume : VolumeValue;
    }
    
    item def WindData {
        attribute windSpeed : VelocityValue;
        attribute windDirection : AngleValue;
        attribute altitude : Altitude;
    }
    
    item def NavigationPlan {
        attribute targetWaypoint : PositionData;
        attribute requiredAltitude : Altitude;
        attribute estimatedTimeToWaypoint : DurationValue;
        attribute confidence : ConfidenceValue;
    }
    
    item def PowerSupply {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute power : PowerValue;
    }
    
    // ==================== Port Definitions ====================
    port def CommandInPort { in item commands[*] : HighLevelCommand; }
    port def TelemetryOutPort { out item telemetry[*] : TelemetryMessage; }
    port def EnvDataOutPort { out item envData : EnvironmentalData; }
    port def EnvDataInPort { in item envData : EnvironmentalData; }
    port def SciDataOutPort { out item sciData : ScienceData; }
    port def SciDataInPort { in item sciData : ScienceData; }
    port def WindDataOutPort { out item wind : WindData; }
    port def WindDataInPort { in item wind : WindData; }
    port def AltCmdOutPort { out item altCmd : AltitudeCommand; }
    port def AltCmdInPort { in item altCmd : AltitudeCommand; }
    port def GasCmdOutPort { out item gasCmd : GasControlSignal; }
    port def GasCmdInPort { in item gasCmd : GasControlSignal; }
    port def LiftOutPort { out item lift : LiftData; }
    port def LiftInPort { in item lift : LiftData; }
    port def PowerOutPort { out item supply : PowerSupply; }
    port def PowerInPort { in item supply : PowerSupply; }
    port def BallastCmdOutPort { out item ballastCmd : BallastReleaseCommand; }
    port def BallastCmdInPort { in item ballastCmd : BallastReleaseCommand; }
    port def NavPlanOutPort { out item plan : NavigationPlan; }
    port def PositionOutPort { out item pos : PositionData; }
    
    // ==================== Requirements ====================
    requirement def MissionDurationRequirement {
        doc /* The Aerobot shall autonomously explore planetary atmospheres for at least 30 days. */
        attribute minMissionDuration : DurationValue = 2592000;
        subject aerobot;
        require aerobot.achievedDuration >= minMissionDuration;
    }
    
    requirement def AltitudeControlRequirement {
        doc /* The Aerobot shall maintain target altitude within plus/minus 200 meters. */
        attribute altitudeTolerance : Altitude = 200;
        subject buoyancyCtrl;
        require buoyancyCtrl.altitudeError <= altitudeTolerance;
    }
    
    requirement def ScienceDataCollectionRequirement {
        doc /* The Aerobot shall continuously collect atmospheric and scientific data. */
        subject sciPkg;
        require sciPkg.collectionEnabled;
    }
    
    requirement def AutonomyRequirement {
        doc /* The Aerobot shall autonomously navigate using wind-based altitude changes. */
        subject aerobot;
        require aerobot.autonomousNavigationEnabled;
    }
    
    requirement def CommunicationRequirement {
        doc /* The Aerobot shall transmit telemetry to a ground station. */
        subject comm;
        require comm.transmissionActive;
    }
    
    // ==================== Action Definitions ====================
    action def CalculateNavigation {
        in currentPosition : PositionData;
        in windForecast : WindData;
        in targetWaypoint : PositionData;
        out navigationPlan : NavigationPlan;
        
        private attribute desiredDirection : AngleValue;
        private attribute bestAltitude : Altitude;
        
        action analyzeWind;
        action selectAltitude;
        action computePlan;
        then analyzeWind;
        then selectAltitude;
        then computePlan;
    }
    
    action def ManageAltitude {
        in currentAltitude : Altitude;
        in targetAltitude : Altitude;
        in currentLift : LiftData;
        out gasControl : GasControlSignal;
        out ballastCommand : BallastReleaseCommand;
        
        action ascend;
        action descend;
        action hold;
        if currentAltitude < targetAltitude {
            then ascend;
        } else if currentAltitude > targetAltitude {
            then descend;
        } else {
            then hold;
        }
    }
    
    action def CollectScienceData {
        out sciData : ScienceData;
        action captureImages;
        action performSpectralAnalysis;
        action countParticles;
        then captureImages;
        then performSpectralAnalysis;
        then countParticles;
    }
    
    // ==================== Part Definitions ====================
    
    part def BalloonEnvelope {
        attribute maxVolume : VolumeValue = 5000;
        attribute liftingGas : String = "Helium";
        attribute currentGasVolume : VolumeValue;
        attribute envelopeMaterial : String = "Polyethylene";
        attribute burstAltitude : Altitude = 35000;
        
        port gasControl : GasCmdInPort;
        port liftOutput : LiftOutPort;
        
        action computeLift {
            in gasVolume : VolumeValue;
            in ambientPressure : PressureValue;
            out lift : LiftData;
        }
        
        state envelopeState {
            state stable;
            state expanding;
            state contracting;
            transition stable -> expanding 
                when gasControl.gasCmd.valveCommand == ValveCommandType::open;
            transition expanding -> stable 
                when currentGasVolume >= maxVolume;
            transition stable -> contracting 
                when gasControl.gasCmd.valveCommand == ValveCommandType::close;
            transition contracting -> stable 
                when gasControl.gasCmd.valveCommand == ValveCommandType::regulate;
        }
    }
    
    part def BallastSystem {
        attribute totalBallastMass : MassValue = 50;
        attribute remainingBallast : MassValue;
        attribute releaseRate : MassFlowRateValue = 0.1;
        attribute ballastMaterial : String = "Sand";
        
        port ballastCommand : BallastCmdInPort;
        
        state ballastState {
            state holding;
            state releasing;
            transition holding -> releasing 
                when ballastCommand.ballastCmd.releaseMass > 0;
            transition releasing -> holding 
                when remainingBallast <= 0;
        }
    }
    
    part def BuoyancyController {
        attribute currentAltitude : Altitude;
        attribute targetAltitude : Altitude;
        attribute altitudeError : Altitude;
        attribute tolerance : Altitude = 200;
        attribute ascentRate : VelocityValue;
        attribute maxAscentRate : VelocityValue = 5;
        attribute maxDescentRate : VelocityValue = 5;
        attribute controlMode : String;
        
        port altCmdIn : AltCmdInPort;
        port liftIn : LiftInPort;
        port gasCmdOut : GasCmdOutPort;
        port ballastCmdOut : BallastCmdOutPort;
        
        action controlAltitude {
            in target : Altitude;
            in current : Altitude;
            in lift : LiftData;
            out gasCmd : GasControlSignal;
            out ballastCmd : BallastReleaseCommand;
        }
        
        state altitudeControlState {
            state ascending;
            state descending;
            state holding;
            transition ascending -> holding 
                when altitudeError <= tolerance;
            transition descending -> holding 
                when altitudeError <= tolerance;
            transition holding -> ascending 
                when targetAltitude > currentAltitude + tolerance;
            transition holding -> descending 
                when targetAltitude < currentAltitude - tolerance;
            transition ascending -> descending 
                when liftIn.lift.liftForce < 0;
            transition descending -> ascending 
                when liftIn.lift.liftForce > 0;
        }
    }
    
    part def ScienceInstrumentPackage {
        attribute instrumentState : InstrumentStateType = InstrumentStateType::idle;
        attribute imageResolutionPixels : DataSizeValue;
        attribute spectralRangeBands : DataSizeValue;
        attribute particleDetectorSensitivity : DataSizeValue;
        attribute collectionEnabled : Boolean = true;
        attribute dataBuffer : DataSizeValue;
        attribute maxBuffer : DataSizeValue = 100000;
        
        port sciDataOut : SciDataOutPort;
        port powerIn : PowerInPort;
        
        action captureImages;
        action performSpectralAnalysis;
        action countParticles;
        
        state instrumentStateMachine {
            state idle;
            state capturing;
            state processing;
            state transmitting;
            transition idle -> capturing 
                when collectionEnabled;
            transition capturing -> processing 
                when captureImages.done;
            transition processing -> transmitting 
                when performSpectralAnalysis.done;
            transition transmitting -> idle 
                when dataBuffer <= 0;
        }
    }
    
    part def AtmosphericSensorSuite {
        attribute samplingFrequency : FrequencyValue = 10;
        attribute temperatureRangeMin : Temperature = 200;
        attribute temperatureRangeMax : Temperature = 350;
        attribute pressureRangeMin : PressureValue = 100;
        attribute pressureRangeMax : PressureValue = 120000;
        attribute windSpeedRangeMax : VelocityValue = 100;
        
        port envDataOut : EnvDataOutPort;
        port windDataOut : WindDataOutPort;
        port powerIn : PowerInPort;
        
        action measureTemperature;
        action measurePressure;
        action measureWind;
        action sampleAtmosphere {
            then measureTemperature;
            then measurePressure;
            then measureWind;
        }
    }
    
    part def PowerSystem {
        attribute solarPanelArea : AreaValue = 2.0;
        attribute batteryCapacity : EnergyValue = 500000;
        attribute currentCharge : EnergyValue;
        attribute chargeRate : PowerValue;
        attribute dischargeRate : PowerValue;
        attribute powerStateType : PowerStateType;
        attribute solarIrradiance : PowerValue;
        attribute solarState : SolarStateType;
        
        port powerOut : PowerOutPort;
        
        state powerStateMachine {
            state charging;
            state discharging;
            state balanced;
            state lowPower;
            transition charging -> balanced 
                when currentCharge >= batteryCapacity;
            transition balanced -> discharging 
                when chargeRate < dischargeRate;
            transition discharging -> charging 
                when chargeRate > dischargeRate;
            transition discharging -> lowPower 
                when currentCharge < 0.1 * batteryCapacity;
            transition lowPower -> charging 
                when chargeRate > dischargeRate;
        }
        
        state solarState {
            state illuminated;
            state shadowed;
            transition illuminated -> shadowed 
                when solarIrradiance < 10;
            transition shadowed -> illuminated 
                when solarIrradiance >= 10;
        }
    }
    
    part def NavigationSubsystem {
        attribute currentPosition : PositionData;
        attribute currentWaypoint : PositionData;
        attribute nextWaypoint : PositionData;
        attribute autonomousNavigationEnabled : Boolean = true;
        attribute positionFix : PositionData;
        attribute windModel : String;
        
        port envDataIn : EnvDataInPort;
        port windDataIn : WindDataInPort;
        port commandIn : CommandInPort;
        port powerIn : PowerInPort;
        port navPlanOut : NavPlanOutPort;
        port altCmdOut : AltCmdOutPort;
        port positionOut : PositionOutPort;
        
        action calculateWaypoint {
            in current : PositionData;
            in wind : WindData;
            in target : PositionData;
            out plan : NavigationPlan;
        }
        action updatePosition;
        
        state navigationStateMachine {
            state idle;
            state planning;
            state executing;
            state waitingForWind;
            transition idle -> planning 
                when commandIn.commands->notEmpty();
            transition planning -> executing 
                when navPlanOut.plan.confidence > 0.5;
            transition executing -> waitingForWind 
                when altCmdOut.altCmd.targetAltitude != currentPosition.altitude;
            transition waitingForWind -> executing 
                when envDataIn.envData.windDirection == navPlanOut.plan.targetWaypoint;
            transition executing -> idle 
                when navPlanOut.plan.targetWaypoint == currentPosition;
        }
    }
    
    part def CommunicationSubsystem {
        attribute transmissionActive : Boolean = false;
        attribute uplinkRate : DataRateValue;
        attribute downlinkRate : DataRateValue;
        attribute buffer : DataSizeValue;
        attribute maxBuffer : DataSizeValue = 1000000;
        attribute antennaType : String = "Patch";
        attribute frequencyBand : String = "S-band";
        
        port commandIn : CommandInPort;
        port envDataIn : EnvDataInPort;
        port sciDataIn : SciDataInPort;
        port powerIn : PowerInPort;
        port telemetryOut : TelemetryOutPort;
        
        action transmitTelemetry {
            in env : EnvironmentalData;
            in sci : ScienceData;
            in pos : PositionData;
            out telemetry : TelemetryMessage;
        }
        action receiveCommands;
        
        state commStateMachine {
            state idle;
            state receiving;
            state transmitting;
            transition idle -> receiving 
                when commandIn.commands->notEmpty();
            transition receiving -> idle 
                when commandIn.commands->isEmpty();
            transition idle -> transmitting 
                when buffer > 0;
            transition transmitting -> idle 
                when buffer <= 0;
        }
    }
    
    part def Gondola {
        attribute mass : MassValue = 100;
        attribute totalPowerBudget : PowerValue;
        attribute housingMaterial : String = "Carbon Fiber";
        
        part sciencePkg : ScienceInstrumentPackage;
        part atmosphereSuite : AtmosphericSensorSuite;
        part powerSubsystem : PowerSystem;
        part navigationSubsystem : NavigationSubsystem;
        part commSubsystem : CommunicationSubsystem;
        part buoyancyController : BuoyancyController;
        part ballastSubsystem : BallastSystem;
        
        port commandIn : CommandInPort;
        port telemetryOut : TelemetryOutPort;
        port liftFromEnvelope : LiftInPort;
        port gasControlOut : GasCmdOutPort;
        
        // Power distribution
        connect powerSubsystem.powerOut -> sciencePkg.powerIn;
        connect powerSubsystem.powerOut -> atmosphereSuite.powerIn;
        connect powerSubsystem.powerOut -> navigationSubsystem.powerIn;
        connect powerSubsystem.powerOut -> commSubsystem.powerIn;
        
        // Environmental data flow
        connect atmosphereSuite.envDataOut -> navigationSubsystem.envDataIn;
        connect atmosphereSuite.windDataOut -> navigationSubsystem.windDataIn;
        connect atmosphereSuite.envDataOut -> commSubsystem.envDataIn;
        
        // Science data flow
        connect sciencePkg.sciDataOut -> commSubsystem.sciDataIn;
        
        // Commands delegation
        connect commandIn -> navigationSubsystem.commandIn;
        connect commandIn -> commSubsystem.commandIn;
        
        // Navigation to buoyancy
        connect navigationSubsystem.altCmdOut -> buoyancyController.altCmdIn;
        
        // Lift data from envelope to buoyancy controller
        connect liftFromEnvelope -> buoyancyController.liftIn;
        
        // Buoyancy gas control delegation to envelope
        connect buoyancyController.gasCmdOut -> gasControlOut;
        
        // Buoyancy ballast control to ballast system
        connect buoyancyController.ballastCmdOut -> ballastSubsystem.ballastCommand;
        
        // Telemetry delegation
        connect commSubsystem.telemetryOut -> telemetryOut;
    }
    
    // ==================== Aerobot ====================
    part def Aerobot {
        attribute missionDuration : DurationValue = 2592000;
        attribute achievedDuration : DurationValue;
        attribute autonomousNavigationEnabled : Boolean = true;
        attribute missionPhase : MissionPhaseType;
        attribute currentAltitude : Altitude;
        attribute operationalAltitude : Altitude = 25000;
        attribute maxAltitude : Altitude = 35000;
        attribute minAltitude : Altitude = 5000;
        
        part envelope : BalloonEnvelope;
        part gondola : Gondola;
        
        port commandPort : CommandInPort;
        port telemetryPort : TelemetryOutPort;
        
        // Envelope-to-gondola lift
        connect envelope.liftOutput -> gondola.liftFromEnvelope;
        
        // Buoyancy gas control to envelope
        connect gondola.gasControlOut -> envelope.gasControl;
        
        // External interfaces
        connect commandPort -> gondola.commandIn;
        connect gondola.telemetryOut -> telemetryPort;
        
        // Mission state machine
        state missionStateMachine {
            state ascentPhase {
                entry { missionPhase := MissionPhaseType::ascent; }
            }
            state cruisePhase {
                entry { missionPhase := MissionPhaseType::cruise; }
            }
            state descentPhase {
                entry { missionPhase := MissionPhaseType::descent; }
            }
            state communicationPhase {
                entry { missionPhase := MissionPhaseType::communication; }
            }
            
            transition ascentPhase -> cruisePhase 
                when currentAltitude >= operationalAltitude;
            transition cruisePhase -> descentPhase 
                when gondola.navigationSubsystem.altCmdOut.altCmd.targetAltitude < currentAltitude;
            transition descentPhase -> cruisePhase 
                when gondola.buoyancyController.altitudeError <= gondola.buoyancyController.tolerance;
            transition cruisePhase -> communicationPhase 
                when gondola.commSubsystem.buffer > 0;
            transition communicationPhase -> cruisePhase 
                when gondola.commSubsystem.buffer <= 0;
        }
        
        // Requirements satisfaction
        requirement missionDur : MissionDurationRequirement;
        requirement altCtrl : AltitudeControlRequirement;
        requirement sciData : ScienceDataCollectionRequirement;
        requirement autonomy : AutonomyRequirement;
        requirement comm : CommunicationRequirement;
        
        satisfy missionDur by self;
        satisfy altCtrl by gondola.buoyancyController;
        satisfy sciData by gondola.sciencePkg;
        satisfy autonomy by self;
        satisfy comm by gondola.commSubsystem;
    }
}
