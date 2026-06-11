package BurnRecoveryBedSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    doc /* 
     * Primary function: The Burn Recovery Bed supports a burn patient during acute recovery by
     * maintaining a sterile, thermally controlled, pressure-relieving care surface while enabling
     * continuous monitoring, wound-care access, fluid management, and safe repositioning.
     */

    attribute def Temperature {
        :> scalar;
        unit = "degC";
    }

    attribute def Pressure {
        :> scalar;
        unit = "kPa";
    }

    attribute def FlowRate {
        :> scalar;
        unit = "L/min";
    }

    attribute def Humidity {
        :> scalar;
        unit = "%RH";
    }

    attribute def Mass {
        :> scalar;
        unit = "kg";
    }

    attribute def Time {
        :> scalar;
        unit = "s";
    }

    attribute def Angle {
        :> scalar;
        unit = "deg";
    }

    item def Air;
    item def FilteredAir :> Air;
    item def WarmAir :> Air;
    item def CoolingAir :> Air;
    item def SterileBarrier;
    item def Exudate;
    item def AlarmSignal;
    item def PatientData;
    item def CaregiverCommand;
    item def ElectricalPower;
    item def ThermalEnergy;
    item def SupportForce;
    item def DisinfectantCycleRequest;

    port def AirPort {
        in item airIn : Air;
        out item airOut : Air;
    }

    port def PowerPort {
        in item power : ElectricalPower;
    }

    port def DataPort {
        in item command : CaregiverCommand;
        out item data : PatientData;
        out item alarm : AlarmSignal;
    }

    port def DrainPort {
        out item fluid : Exudate;
    }

    port def SupportPort {
        out item loadSupport : SupportForce;
    }

    port def ThermalPort {
        out item heatTransfer : ThermalEnergy;
    }

    part def BurnRecoveryBed {
        attribute bedLength : Length = 2.2 [m];
        attribute bedWidth : Length = 1.05 [m];
        attribute maxPatientMass : Mass = 250 [kg];
        attribute targetSurfaceTemperature : Temperature = 34 [degC];
        attribute targetHumidity : Humidity = 45 [%RH];
        attribute maxInterfacePressure : Pressure = 4.0 [kPa];
        attribute headTiltAngle : Angle = 0 [deg];
        attribute kneeTiltAngle : Angle = 0 [deg];

        port powerInput : PowerPort;
        port clinicalNetwork : DataPort;
        port ambientAirInterface : AirPort;
        port drainageInterface : DrainPort;
        port patientSupportInterface : SupportPort;
        port patientThermalInterface : ThermalPort;

        part frame : StructuralFrame;
        part supportSurface : LowPressureSupportSurface;
        part airTherapySystem : AirTherapySystem;
        part climateController : MicroclimateController;
        part sterileCanopy : SterileCanopy;
        part fluidManagement : FluidManagementSystem;
        part patientMonitor : PatientMonitoringSystem;
        part repositioningSystem : RepositioningSystem;
        part safetyController : SafetyController;
        part userConsole : CaregiverConsole;
        part powerSystem : PowerDistributionSystem;

        connect powerInput.power to powerSystem.externalPower.power;
        connect powerSystem.controlPower.power to safetyController.power.power;
        connect powerSystem.therapyPower.power to airTherapySystem.power.power;
        connect powerSystem.therapyPower.power to climateController.power.power;
        connect powerSystem.actuatorPower.power to repositioningSystem.power.power;
        connect powerSystem.controlPower.power to patientMonitor.power.power;
        connect powerSystem.controlPower.power to userConsole.power.power;

        connect ambientAirInterface.airIn to airTherapySystem.intake.airIn;
        connect airTherapySystem.filteredOutlet.airOut to climateController.airInput.airIn;
        connect climateController.conditionedAirOutlet.airOut to supportSurface.airSupply.airIn;
        connect supportSurface.returnAir.airOut to airTherapySystem.returnIntake.airIn;

        connect fluidManagement.drainOutput.fluid to drainageInterface.fluid;
        connect supportSurface.exudateOutlet.fluid to fluidManagement.fluidInput.fluid;

        connect supportSurface.supportOutput.loadSupport to patientSupportInterface.loadSupport;
        connect climateController.patientThermalOutput.heatTransfer to patientThermalInterface.heatTransfer;

        connect patientMonitor.monitorData.data to safetyController.patientData.data;
        connect userConsole.consoleCommand.command to safetyController.caregiverCommand.command;
        connect safetyController.controllerData.data to clinicalNetwork.data;
        connect safetyController.alarmOutput.alarm to clinicalNetwork.alarm;

        connect safetyController.surfaceCommand.command to supportSurface.control.command;
        connect safetyController.climateCommand.command to climateController.control.command;
        connect safetyController.repositionCommand.command to repositioningSystem.control.command;
        connect safetyController.airCommand.command to airTherapySystem.control.command;

        perform action provideBurnRecoverySupport;
    }

    part def StructuralFrame {
        attribute safeWorkingLoad : Mass = 320 [kg];
        attribute minimumHeight : Length = 0.45 [m];
        attribute maximumHeight : Length = 0.85 [m];

        part headDeck : ArticulatingDeckSection;
        part torsoDeck : ArticulatingDeckSection;
        part legDeck : ArticulatingDeckSection;
        part baseLift : LiftColumnSet;
        part sideRails : SideRailSet;
    }

    part def ArticulatingDeckSection {
        attribute deckAngle : Angle = 0 [deg];
        attribute locked : Boolean = true;
    }

    part def LiftColumnSet {
        attribute currentHeight : Length = 0.62 [m];
        attribute verticalSpeed : Speed = 0.015 [m/s];
    }

    part def SideRailSet {
        attribute leftRailRaised : Boolean = true;
        attribute rightRailRaised : Boolean = true;
        attribute railLockConfirmed : Boolean = true;
    }

    part def LowPressureSupportSurface {
        attribute averageInterfacePressure : Pressure = 2.8 [kPa];
        attribute pressureLimit : Pressure = 4.0 [kPa];
        attribute surfaceTemperature : Temperature = 34 [degC];
        attribute immersionDepth : Length = 0.09 [m];

        port airSupply : AirPort;
        port returnAir : AirPort;
        port exudateOutlet : DrainPort;
        port supportOutput : SupportPort;
        port control : DataPort;

        part airCellArray : AirCellArray;
        part pressureSensors : InterfacePressureSensorArray;
        part shearReductionLayer : ShearReductionLayer;
        part removableSterileCover : SterileCover;
    }

    part def AirCellArray {
        attribute zoneCount : Integer = 12;
        attribute headZonePressure : Pressure = 2.6 [kPa];
        attribute torsoZonePressure : Pressure = 3.1 [kPa];
        attribute sacralZonePressure : Pressure = 2.7 [kPa];
        attribute legZonePressure : Pressure = 2.4 [kPa];
    }

    part def InterfacePressureSensorArray {
        attribute sensorCount : Integer = 96;
        attribute samplePeriod : Time = 5 [s];
        attribute highestMeasuredPressure : Pressure = 3.4 [kPa];
    }

    part def ShearReductionLayer {
        attribute coefficientOfFriction : Real = 0.18;
    }

    part def SterileCover {
        attribute microbialBarrierIntegrity : Boolean = true;
        attribute fluidImpermeable : Boolean = true;
        attribute replacementInterval : Time = 28800 [s];
    }

    part def AirTherapySystem {
        attribute blowerFlowRate : FlowRate = 120 [L/min];
        attribute filterEfficiency : Real = 0.9997;
        attribute filterPressureDrop : Pressure = 0.35 [kPa];

        port power : PowerPort;
        port intake : AirPort;
        port returnIntake : AirPort;
        port filteredOutlet : AirPort;
        port control : DataPort;

        part blower : VariableSpeedBlower;
        part hepaFilter : HEPAFilter;
        part uvSterilizer : UVAirSterilizer;
        part flowSensor : AirFlowSensor;
    }

    part def VariableSpeedBlower {
        attribute commandedFlow : FlowRate = 120 [L/min];
        attribute maximumFlow : FlowRate = 180 [L/min];
        attribute minimumFlow : FlowRate = 30 [L/min];
    }

    part def HEPAFilter {
        attribute particulateRemovalAt03Micron : Real = 0.9997;
        attribute replacementDue : Boolean = false;
    }

    part def UVAirSterilizer {
        attribute lampEnabled : Boolean = true;
        attribute accumulatedRunTime : Time = 3600 [s];
    }

    part def AirFlowSensor {
        attribute measuredFlow : FlowRate = 118 [L/min];
        attribute faultDetected : Boolean = false;
    }

    part def MicroclimateController {
        attribute measuredTemperature : Temperature = 34 [degC];
        attribute measuredHumidity : Humidity = 45 [%RH];
        attribute temperatureTolerance : Temperature = 1 [degC];
        attribute humidityTolerance : Humidity = 8 [%RH];

        port power : PowerPort;
        port airInput : AirPort;
        port conditionedAirOutlet : AirPort;
        port patientThermalOutput : ThermalPort;
        port control : DataPort;

        part heater : AirHeater;
        part cooler : ThermoelectricCooler;
        part humidifier : SterileHumidifier;
        part temperatureSensors : TemperatureSensorSet;
        part humiditySensor : HumiditySensor;
    }

    part def AirHeater {
        attribute enabled : Boolean = false;
        attribute heatPower : Power = 250 [W];
    }

    part def ThermoelectricCooler {
        attribute enabled : Boolean = false;
        attribute coolingPower : Power = 180 [W];
    }

    part def SterileHumidifier {
        attribute enabled : Boolean = true;
        attribute sterileWaterLevel : Real = 0.75;
    }

    part def TemperatureSensorSet {
        attribute sensorCount : Integer = 8;
        attribute maximumPatientSurfaceTemperature : Temperature = 35 [degC];
        attribute minimumPatientSurfaceTemperature : Temperature = 33 [degC];
    }

    part def HumiditySensor {
        attribute relativeHumidity : Humidity = 45 [%RH];
    }

    part def SterileCanopy {
        attribute canopyClosed : Boolean = true;
        attribute positivePressure : Pressure = 0.02 [kPa];
        attribute accessPortCount : Integer = 6;

        part transparentBarrier : SterileBarrierPanel;
        part glovePorts : GlovePortSet;
        part medicationPassThrough : SealedPassThrough;
    }

    part def SterileBarrierPanel {
        attribute opticalClarity : Real = 0.92;
        attribute barrierIntegrity : Boolean = true;
    }

    part def GlovePortSet {
        attribute portCount : Integer = 6;
        attribute allSealsVerified : Boolean = true;
    }

    part def SealedPassThrough {
        attribute innerDoorLocked : Boolean = true;
        attribute outerDoorLocked : Boolean = false;
    }

    part def FluidManagementSystem {
        attribute collectionVolume : Volume = 1.2 [L];
        attribute highLevelAlarmThreshold : Volume = 1.8 [L];

        port fluidInput : DrainPort;
        port drainOutput : DrainPort;

        part absorbentLiner : AbsorbentLiner;
        part drainageChannels : DrainageChannelSet;
        part collectionCanister : CollectionCanister;
    }

    part def AbsorbentLiner {
        attribute absorptionCapacity : Volume = 2.0 [L];
        attribute saturated : Boolean = false;
    }

    part def DrainageChannelSet {
        attribute channelCount : Integer = 8;
        attribute blocked : Boolean = false;
    }

    part def CollectionCanister {
        attribute currentVolume : Volume = 1.2 [L];
        attribute sealed : Boolean = true;
    }

    part def PatientMonitoringSystem {
        attribute heartRate : Frequency = 1.25 [Hz];
        attribute oxygenSaturation : Real = 0.97;
        attribute patientCoreTemperature : Temperature = 37 [degC];
        attribute patientMassEstimate : Mass = 82 [kg];

        port power : PowerPort;
        port monitorData : DataPort;

        part vitalSignsModule : VitalSignsModule;
        part loadCells : LoadCellSet;
        part moistureSensors : MoistureSensorArray;
    }

    part def VitalSignsModule {
        attribute heartRateBpm : Integer = 75;
        attribute spo2Percent : Real = 97;
        attribute respiratoryRatePerMinute : Integer = 16;
    }

    part def LoadCellSet {
        attribute cellCount : Integer = 4;
        attribute measuredMass : Mass = 82 [kg];
    }

    part def MoistureSensorArray {
        attribute sensorCount : Integer = 16;
        attribute woundExudateDetected : Boolean = true;
        attribute excessiveMoistureDetected : Boolean = false;
    }

    part def RepositioningSystem {
        attribute turnAngle : Angle = 0 [deg];
        attribute maximumTurnAngle : Angle = 30 [deg];
        attribute repositionInterval : Time = 7200 [s];

        port power : PowerPort;
        port control : DataPort;

        part leftTurnActuator : LinearActuator;
        part rightTurnActuator : LinearActuator;
        part headTiltActuator : LinearActuator;
        part kneeTiltActuator : LinearActuator;
    }

    part def LinearActuator {
        attribute extension : Length = 0.0 [m];
        attribute maximumForce : Force = 1200 [N];
        attribute motionEnabled : Boolean = false;
    }

    part def SafetyController {
        attribute systemMode : BedMode = BedMode::Standby;
        attribute alarmActive : Boolean = false;
        attribute lastSelfTestPassed : Boolean = true;
        attribute emergencyStopPressed : Boolean = false;

        port power : PowerPort;
        port patientData : DataPort;
        port caregiverCommand : DataPort;
        port controllerData : DataPort;
        port alarmOutput : DataPort;
        port surfaceCommand : DataPort;
        port climateCommand : DataPort;
        port repositionCommand : DataPort;
        port airCommand : DataPort;

        perform action coordinateTherapy;
        exhibit state machine operatingStateMachine;
    }

    enum def BedMode {
        enum Standby;
        enum AdmitPatient;
        enum ActiveTherapy;
        enum WoundCareAccess;
        enum Repositioning;
        enum Decontamination;
        enum Alarm;
        enum Shutdown;
    }

    part def CaregiverConsole {
        attribute displayBrightness : Real = 0.8;
        attribute touchInputEnabled : Boolean = true;
        attribute selectedMode : BedMode = BedMode::ActiveTherapy;

        port power : PowerPort;
        port consoleCommand : DataPort;
    }

    part def PowerDistributionSystem {
        attribute mainsAvailable : Boolean = true;
        attribute batteryStateOfCharge : Real = 0.95;
        attribute remainingBackupTime : Time = 7200 [s];

        port externalPower : PowerPort;
        port controlPower : PowerPort;
        port therapyPower : PowerPort;
        port actuatorPower : PowerPort;

        part battery : BackupBattery;
        part isolationTransformer : MedicalIsolationTransformer;
        part powerMonitor : PowerMonitor;
    }

    part def BackupBattery {
        attribute capacity : Energy = 720000 [J];
        attribute stateOfCharge : Real = 0.95;
    }

    part def MedicalIsolationTransformer {
        attribute leakageCurrent : Current = 0.0001 [A];
    }

    part def PowerMonitor {
        attribute overCurrentDetected : Boolean = false;
        attribute undervoltageDetected : Boolean = false;
    }

    action def ProvideBurnRecoverySupport {
        in item patientCommand : CaregiverCommand;
        out item therapyStatus : PatientData;

        first start;
        then verifySterileSurface;
        then admitPatient;
        then regulateSupportPressure;
        then regulateMicroclimate;
        then monitorPatient;
        then manageExudate;
        then enableCareAccess;
        then continueTherapy;

        action verifySterileSurface;
        action admitPatient;
        action regulateSupportPressure;
        action regulateMicroclimate;
        action monitorPatient;
        action manageExudate;
        action enableCareAccess;
        action continueTherapy;
    }

    action def CoordinateTherapy {
        in item patientData : PatientData;
        in item caregiverCommand : CaregiverCommand;
        out item surfaceCommand : CaregiverCommand;
        out item climateCommand : CaregiverCommand;
        out item repositionCommand : CaregiverCommand;
        out item airCommand : CaregiverCommand;
        out item alarmSignal : AlarmSignal;

        first receiveInputs;
        then evaluateSafetyLimits;
        then computeTherapySetpoints;
        then issueCommands;
        then logClinicalData;

        action receiveInputs;
        action evaluateSafetyLimits;
        action computeTherapySetpoints;
        action issueCommands;
        action logClinicalData;
    }

    state machine def BedOperatingStateMachine {
        state standby;
        state admittingPatient;
        state activeTherapy;
        state woundCareAccess;
        state repositioning;
        state decontamination;
        state alarm;
        state shutdown;

        entry action initializeController;
        then standby;

        transition standby_to_admit
            first standby
            accept CaregiverCommand
            if commandIsAdmit
            then admittingPatient;

        transition admit_to_therapy
            first admittingPatient
            if patientMassConfirmed and sterileCoverInstalled
            then activeTherapy;

        transition therapy_to_woundCare
            first activeTherapy
            accept CaregiverCommand
            if commandIsWoundCare
            then woundCareAccess;

        transition woundCare_to_therapy
            first woundCareAccess
            if canopyClosed and accessPortsSealed
            then activeTherapy;

        transition therapy_to_reposition
            first activeTherapy
            if repositionIntervalElapsed
            then repositioning;

        transition reposition_to_therapy
            first repositioning
            if targetTurnAngleReached or caregiverCancelsTurn
            then activeTherapy;

        transition therapy_to_alarm
            first activeTherapy
            if temperatureOutOfRange or highInterfacePressure or airflowFault or emergencyStopPressed
            then alarm;

        transition alarm_to_therapy
            first alarm
            if alarmAcknowledged and unsafeConditionCleared
            then activeTherapy;

        transition standby_to_decontamination
            first standby
            accept DisinfectantCycleRequest
            then decontamination;

        transition decontamination_to_standby
            first decontamination
            if decontaminationComplete and sterileCoverReplaced
            then standby;

        transition any_to_shutdown
            first standby
            accept CaregiverCommand
            if commandIsShutdown
            then shutdown;
    }

    requirement def PrimaryFunctionRequirement {
        subject bed : BurnRecoveryBed;
        doc /* The bed shall support burn recovery by combining pressure relief, sterile environmental protection, microclimate regulation, patient monitoring, exudate management, and controlled repositioning in one integrated clinical platform. */
    }

    requirement def PressureReliefRequirement {
        subject surface : LowPressureSupportSurface;
        attribute requiredMaximumPressure : Pressure = 4.0 [kPa];
        doc /* The support surface shall maintain patient interface pressure at or below the required maximum during active therapy for patients up to the rated maximum mass. */
        require constraint { surface.averageInterfacePressure <= requiredMaximumPressure }
    }

    requirement def TemperatureControlRequirement {
        subject controller : MicroclimateController;
        attribute targetTemperature : Temperature = 34 [degC];
        attribute tolerance : Temperature = 1 [degC];
        doc /* The microclimate controller shall maintain the patient support surface temperature within tolerance of the target temperature. */
        require constraint {
            controller.measuredTemperature >= targetTemperature - tolerance and
            controller.measuredTemperature <= targetTemperature + tolerance
        }
    }

    requirement def HumidityControlRequirement {
        subject controller : MicroclimateController;
        attribute targetRelativeHumidity : Humidity = 45 [%RH];
        attribute tolerance : Humidity = 8 [%RH];
        doc /* The microclimate controller shall maintain relative humidity in a range that reduces dressing desiccation and excessive moisture accumulation. */
        require constraint {
            controller.measuredHumidity >= targetRelativeHumidity - tolerance and
            controller.measuredHumidity <= targetRelativeHumidity + tolerance
        }
    }

    requirement def SterileBarrierRequirement {
        subject canopy : SterileCanopy;
        doc /* The sterile canopy shall provide a closed positive-pressure barrier with sealed access ports during active therapy. */
        require constraint {
            canopy.canopyClosed == true and
            canopy.positivePressure >= 0.01 [kPa]
        }
    }

    requirement def MonitoringRequirement {
        subject monitor : PatientMonitoringSystem;
        doc /* The monitoring system shall provide vital signs, patient mass, and moisture status to the safety controller during active therapy. */
    }

    requirement def FluidManagementRequirement {
        subject fluidSystem : FluidManagementSystem;
        doc /* The fluid management system shall collect wound exudate and alarm before the collection canister reaches full capacity. */
        require constraint { fluidSystem.collectionVolume < fluidSystem.highLevelAlarmThreshold }
    }

    requirement def RepositioningRequirement {
        subject repositioner : RepositioningSystem;
        doc /* The repositioning system shall support scheduled low-angle turns without exceeding the maximum allowed turn angle. */
        require constraint { repositioner.turnAngle <= repositioner.maximumTurnAngle }
    }

    requirement def BackupPowerRequirement {
        subject power : PowerDistributionSystem;
        attribute minimumBackupTime : Time = 3600 [s];
        doc /* The power system shall provide backup power long enough to sustain monitoring, alarms, and controlled surface support during mains loss. */
        require constraint { power.remainingBackupTime >= minimumBackupTime }
    }

    requirement def SafetyAlarmRequirement {
        subject controller : SafetyController;
        doc /* The safety controller shall enter alarm mode when unsafe thermal, pressure, airflow, power, or emergency stop conditions are detected. */
    }

    satisfy PrimaryFunctionRequirement by BurnRecoveryBed;
    satisfy PressureReliefRequirement by LowPressureSupportSurface;
    satisfy TemperatureControlRequirement by MicroclimateController;
    satisfy HumidityControlRequirement by MicroclimateController;
    satisfy SterileBarrierRequirement by SterileCanopy;
    satisfy MonitoringRequirement by PatientMonitoringSystem;
    satisfy FluidManagementRequirement by FluidManagementSystem;
    satisfy RepositioningRequirement by RepositioningSystem;
    satisfy BackupPowerRequirement by PowerDistributionSystem;
    satisfy SafetyAlarmRequirement by SafetyController;

    part burnRecoveryBed : BurnRecoveryBed {
        :>> provideBurnRecoverySupport : ProvideBurnRecoverySupport;
        :>> safetyController.coordinateTherapy : CoordinateTherapy;
        :>> safetyController.operatingStateMachine : BedOperatingStateMachine;
    }
}