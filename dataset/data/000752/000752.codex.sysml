package SAHRA_Mechanical_Respirator_Model {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def PressureValue :> ScalarValues::Real {
        unit = "cmH2O";
    }

    attribute def FlowRateValue :> ScalarValues::Real {
        unit = "L/min";
    }

    attribute def VolumeValue :> ScalarValues::Real {
        unit = "mL";
    }

    attribute def TimeValue :> ScalarValues::Real {
        unit = "s";
    }

    attribute def FrequencyValue :> ScalarValues::Real {
        unit = "breaths/min";
    }

    attribute def FractionValue :> ScalarValues::Real {
        unit = "1";
    }

    attribute def OxygenConcentrationValue :> ScalarValues::Real {
        unit = "%";
    }

    attribute def ElectricalPowerValue :> ScalarValues::Real {
        unit = "W";
    }

    attribute def VoltageValue :> ScalarValues::Real {
        unit = "V";
    }

    item def AmbientAir {
        attribute oxygenFraction : OxygenConcentrationValue;
        attribute pressure : PressureValue;
    }

    item def OxygenEnrichedGas {
        attribute oxygenFraction : OxygenConcentrationValue;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }

    item def PatientBreathGas {
        attribute tidalVolume : VolumeValue;
        attribute airwayPressure : PressureValue;
        attribute inspiratoryFlow : FlowRateValue;
        attribute expiratoryFlow : FlowRateValue;
        attribute oxygenFraction : OxygenConcentrationValue;
    }

    item def ExhaledGas {
        attribute carbonDioxideFraction : FractionValue;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }

    item def ElectricalEnergy {
        attribute voltage : VoltageValue;
        attribute power : ElectricalPowerValue;
    }

    item def ControlCommand {
        attribute targetTidalVolume : VolumeValue;
        attribute targetRespiratoryRate : FrequencyValue;
        attribute targetInspiratoryPressure : PressureValue;
        attribute targetPEEP : PressureValue;
        attribute targetFiO2 : OxygenConcentrationValue;
        attribute inspiratoryTime : TimeValue;
    }

    item def SensorMeasurement {
        attribute measuredPressure : PressureValue;
        attribute measuredFlow : FlowRateValue;
        attribute measuredVolume : VolumeValue;
        attribute measuredOxygenFraction : OxygenConcentrationValue;
        attribute sampleAge : TimeValue;
    }

    item def AlarmSignal {
        attribute priority : ScalarValues::Integer;
        attribute active : Boolean;
        attribute acknowledged : Boolean;
    }

    port def GasInletPort {
        in item gasIn : AmbientAir;
    }

    port def OxygenInletPort {
        in item oxygenIn : OxygenEnrichedGas;
    }

    port def InspiratoryGasPort {
        out item gasOut : PatientBreathGas;
    }

    port def ExpiratoryGasPort {
        in item gasReturn : ExhaledGas;
    }

    port def PowerInputPort {
        in item electricalIn : ElectricalEnergy;
    }

    port def SensorDataPort {
        out item measurementOut : SensorMeasurement;
    }

    port def ControlPort {
        in item commandIn : ControlCommand;
        out item alarmOut : AlarmSignal;
    }

    part def SAHRA_MechanicalRespirator {
        doc /* SAHRA Mechanical Respirator provides controlled mechanical ventilation by moving a defined volume or pressure of breathable gas into a patient circuit, maintaining positive end expiratory pressure, monitoring airway conditions, and alerting operators when ventilation cannot remain within safe limits. */

        attribute setTidalVolume : VolumeValue = 500;
        attribute setRespiratoryRate : FrequencyValue = 12;
        attribute setInspiratoryPressure : PressureValue = 20;
        attribute setPEEP : PressureValue = 5;
        attribute setFiO2 : OxygenConcentrationValue = 40;
        attribute maxAirwayPressure : PressureValue = 40;
        attribute minDeliveredVolume : VolumeValue = 250;
        attribute inspiratoryTime : TimeValue = 1.0;
        attribute expiratoryTime : TimeValue = 4.0;
        attribute powerDemand : ElectricalPowerValue = 65;

        port ambientAirIn : GasInletPort;
        port oxygenIn : OxygenInletPort;
        port patientInspiratoryOut : InspiratoryGasPort;
        port patientExpiratoryIn : ExpiratoryGasPort;
        port powerIn : PowerInputPort;
        port clinicianInterface : ControlPort;

        part pneumaticModule : PneumaticModule;
        part driveModule : MechanicalDriveModule;
        part patientCircuit : PatientBreathingCircuit;
        part controlUnit : EmbeddedControlUnit;
        part sensorSuite : RespiratorySensorSuite;
        part alarmSystem : AlarmSystem;
        part powerSubsystem : PowerSubsystem;
        part userInterface : UserInterface;

        connect ambientAirIn.gasIn to pneumaticModule.airIn.gasIn;
        connect oxygenIn.oxygenIn to pneumaticModule.oxygenIn.oxygenIn;
        connect pneumaticModule.conditionedGasOut.gasOut to driveModule.gasIn.gasIn;
        connect driveModule.inspiratoryGasOut.gasOut to patientCircuit.inspiratoryLimb.gasOut;
        connect patientCircuit.patientExhalation.gasReturn to patientExpiratoryIn.gasReturn;
        connect patientCircuit.sensorTap.measurementOut to sensorSuite.measurementIn.measurementOut;
        connect sensorSuite.sensorData.measurementOut to controlUnit.sensorData.measurementOut;
        connect controlUnit.driveCommand.commandIn to driveModule.control.commandIn;
        connect controlUnit.valveCommand.commandIn to pneumaticModule.control.commandIn;
        connect controlUnit.alarmCommand.alarmOut to alarmSystem.alarmIn.alarmOut;
        connect clinicianInterface.commandIn to userInterface.commandEntry.commandIn;
        connect userInterface.commandOutput.commandIn to controlUnit.operatorCommand.commandIn;
        connect alarmSystem.alarmOut.alarmOut to clinicianInterface.alarmOut;
        connect powerIn.electricalIn to powerSubsystem.externalPower.electricalIn;
        connect powerSubsystem.controlPower.electricalIn to controlUnit.power.electricalIn;
        connect powerSubsystem.drivePower.electricalIn to driveModule.power.electricalIn;
        connect powerSubsystem.uiPower.electricalIn to userInterface.power.electricalIn;

        perform action operateRespirator;
    }

    part def PneumaticModule {
        attribute blendedFiO2 : OxygenConcentrationValue;
        attribute supplyPressure : PressureValue;
        attribute leakRate : FlowRateValue;

        port airIn : GasInletPort;
        port oxygenIn : OxygenInletPort;
        port conditionedGasOut : InspiratoryGasPort;
        port control : ControlPort;

        part inletFilter : Filter;
        part oxygenMixer : OxygenMixer;
        part inspiratoryValve : ProportionalValve;
        part reliefValve : PressureReliefValve;

        connect airIn.gasIn to inletFilter.airIn.gasIn;
        connect inletFilter.filteredAir.gasOut to oxygenMixer.airIn.gasIn;
        connect oxygenIn.oxygenIn to oxygenMixer.oxygenIn.oxygenIn;
        connect oxygenMixer.blendedGas.gasOut to inspiratoryValve.gasIn.gasIn;
        connect inspiratoryValve.gasOut.gasOut to reliefValve.gasIn.gasIn;
        connect reliefValve.gasOut.gasOut to conditionedGasOut.gasOut;
    }

    part def MechanicalDriveModule {
        attribute strokePosition : ScalarValues::Real;
        attribute compressionForce : ScalarValues::Real;
        attribute deliveredVolume : VolumeValue;

        port gasIn : GasInletPort;
        port inspiratoryGasOut : InspiratoryGasPort;
        port control : ControlPort;
        port power : PowerInputPort;

        part actuator : LinearActuator;
        part compressionBag : VentilationBag;
        part driveLinkage : Linkage;
        part positionEncoder : PositionEncoder;

        connect actuator.mechanicalOutput to driveLinkage.mechanicalInput;
        connect driveLinkage.mechanicalOutput to compressionBag.compressionInput;
        connect gasIn.gasIn to compressionBag.gasFill.gasIn;
        connect compressionBag.gasDelivery.gasOut to inspiratoryGasOut.gasOut;
    }

    part def PatientBreathingCircuit {
        attribute circuitCompliance : ScalarValues::Real;
        attribute resistance : ScalarValues::Real;
        attribute humidifierActive : Boolean;

        port inspiratoryLimb : InspiratoryGasPort;
        port patientExhalation : ExpiratoryGasPort;
        port sensorTap : SensorDataPort;

        part inspiratoryHose : BreathingHose;
        part yPiece : PatientYPiece;
        part expiratoryHose : BreathingHose;
        part peepValve : PEEPValve;
        part bacterialFilter : Filter;

        connect inspiratoryLimb.gasOut to inspiratoryHose.gasIn.gasIn;
        connect inspiratoryHose.gasOut.gasOut to yPiece.inspiratorySide.gasOut;
        connect yPiece.expiratorySide.gasReturn to expiratoryHose.gasIn.gasReturn;
        connect expiratoryHose.gasOut.gasReturn to peepValve.gasIn.gasReturn;
        connect peepValve.gasOut.gasReturn to bacterialFilter.exhaledIn.gasReturn;
        connect bacterialFilter.exhaledOut.gasReturn to patientExhalation.gasReturn;
    }

    part def EmbeddedControlUnit {
        attribute currentMode : VentilationModeKind;
        attribute breathCycleTime : TimeValue;
        attribute lastMeasuredPressure : PressureValue;
        attribute lastMeasuredVolume : VolumeValue;
        attribute faultDetected : Boolean;

        port operatorCommand : ControlPort;
        port sensorData : SensorDataPort;
        port driveCommand : ControlPort;
        port valveCommand : ControlPort;
        port alarmCommand : ControlPort;
        port power : PowerInputPort;

        part breathController : BreathCycleController;
        part safetyMonitor : SafetyMonitor;
        part commandProcessor : CommandProcessor;

        perform action controlBreathCycle;
        perform action evaluateSafetyLimits;
    }

    enum def VentilationModeKind {
        enum volumeControl;
        enum pressureControl;
        enum assistControl;
        enum standby;
        enum fault;
    }

    part def RespiratorySensorSuite {
        port measurementIn : SensorDataPort;
        port sensorData : SensorDataPort;

        part pressureSensor : AirwayPressureSensor;
        part flowSensor : FlowSensor;
        part oxygenSensor : OxygenSensor;

        attribute pressureAccuracy : PressureValue = 1;
        attribute flowAccuracy : FlowRateValue = 2;
        attribute oxygenAccuracy : OxygenConcentrationValue = 3;
    }

    part def AlarmSystem {
        attribute highPressureAlarmActive : Boolean;
        attribute lowVolumeAlarmActive : Boolean;
        attribute powerAlarmActive : Boolean;
        attribute apneaAlarmActive : Boolean;

        port alarmIn : ControlPort;
        port alarmOut : ControlPort;

        part audibleAnnunciator : AudibleAnnunciator;
        part visualIndicator : VisualIndicator;
    }

    part def PowerSubsystem {
        attribute batteryCharge : FractionValue;
        attribute remainingRuntime : TimeValue;
        attribute inputVoltage : VoltageValue;

        port externalPower : PowerInputPort;
        port controlPower : PowerInputPort;
        port drivePower : PowerInputPort;
        port uiPower : PowerInputPort;

        part acDcConverter : PowerConverter;
        part batteryPack : BatteryPack;
        part powerManager : PowerManager;
    }

    part def UserInterface {
        attribute displayedTidalVolume : VolumeValue;
        attribute displayedPressure : PressureValue;
        attribute displayedRespiratoryRate : FrequencyValue;
        attribute alarmMuted : Boolean;

        port commandEntry : ControlPort;
        port commandOutput : ControlPort;
        port power : PowerInputPort;

        part display : Display;
        part rotaryEncoder : InputKnob;
        part startStopSwitch : Switch;
        part alarmMuteButton : Switch;
    }

    part def Filter {
        port airIn : GasInletPort;
        port filteredAir : InspiratoryGasPort;
        port exhaledIn : ExpiratoryGasPort;
        port exhaledOut : ExpiratoryGasPort;
        attribute filtrationEfficiency : FractionValue = 0.99;
    }

    part def OxygenMixer {
        port airIn : GasInletPort;
        port oxygenIn : OxygenInletPort;
        port blendedGas : InspiratoryGasPort;
        attribute commandedFiO2 : OxygenConcentrationValue;
    }

    part def ProportionalValve {
        port gasIn : InspiratoryGasPort;
        port gasOut : InspiratoryGasPort;
        port control : ControlPort;
        attribute openingFraction : FractionValue;
    }

    part def PressureReliefValve {
        port gasIn : InspiratoryGasPort;
        port gasOut : InspiratoryGasPort;
        attribute crackingPressure : PressureValue = 45;
    }

    part def LinearActuator {
        port power : PowerInputPort;
        port control : ControlPort;
        port mechanicalOutput : MechanicalPort;
        attribute strokeLength : ScalarValues::Real;
        attribute peakForce : ScalarValues::Real;
    }

    port def MechanicalPort {
        out item force : ScalarValues::Real;
        out item displacement : ScalarValues::Real;
    }

    part def VentilationBag {
        port gasFill : GasInletPort;
        port gasDelivery : InspiratoryGasPort;
        port compressionInput : MechanicalPort;
        attribute nominalCapacity : VolumeValue = 1600;
        attribute compressedVolume : VolumeValue;
    }

    part def Linkage {
        port mechanicalInput : MechanicalPort;
        port mechanicalOutput : MechanicalPort;
        attribute mechanicalAdvantage : ScalarValues::Real;
    }

    part def PositionEncoder {
        attribute measuredPosition : ScalarValues::Real;
        attribute resolution : ScalarValues::Real;
    }

    part def BreathingHose {
        port gasIn : InspiratoryGasPort;
        port gasOut : InspiratoryGasPort;
        attribute length : ScalarValues::Real;
        attribute internalVolume : VolumeValue;
    }

    part def PatientYPiece {
        port inspiratorySide : InspiratoryGasPort;
        port expiratorySide : ExpiratoryGasPort;
        port patientConnection : InspiratoryGasPort;
    }

    part def PEEPValve {
        port gasIn : ExpiratoryGasPort;
        port gasOut : ExpiratoryGasPort;
        attribute peepSetting : PressureValue;
    }

    part def AirwayPressureSensor {
        attribute pressure : PressureValue;
        attribute samplePeriod : TimeValue = 0.01;
    }

    part def FlowSensor {
        attribute flow : FlowRateValue;
        attribute integratedVolume : VolumeValue;
        attribute samplePeriod : TimeValue = 0.01;
    }

    part def OxygenSensor {
        attribute oxygenFraction : OxygenConcentrationValue;
        attribute responseTime : TimeValue = 6;
    }

    part def BreathCycleController;
    part def SafetyMonitor;
    part def CommandProcessor;
    part def AudibleAnnunciator;
    part def VisualIndicator;
    part def PowerConverter;
    part def BatteryPack;
    part def PowerManager;
    part def Display;
    part def InputKnob;
    part def Switch;

    action def operateRespirator {
        in item requestedSettings : ControlCommand;
        in item patientFeedback : SensorMeasurement;
        out item deliveredBreath : PatientBreathGas;
        out item activeAlarm : AlarmSignal;

        first start;
        then initializeSystem;
        then awaitVentilationCommand;
        then cycleBreathing;
        then monitorSafety;
        then updateUserInterface;

        action initializeSystem;
        action awaitVentilationCommand;
        action cycleBreathing;
        action monitorSafety;
        action updateUserInterface;
    }

    action def controlBreathCycle {
        in item command : ControlCommand;
        in item measurement : SensorMeasurement;
        out item actuatorCommand : ControlCommand;
        out item valveCommand : ControlCommand;

        action computeInspiratoryTarget;
        action commandActuatorStroke;
        action commandInspiratoryValve;
        action holdInspiratoryPressure;
        action releaseToExpiration;
    }

    action def evaluateSafetyLimits {
        in item measurement : SensorMeasurement;
        out item alarm : AlarmSignal;

        action comparePressureLimit;
        action compareVolumeLimit;
        action detectDisconnect;
        action detectOcclusion;
        action reportAlarm;
    }

    state def RespiratorOperatingState {
        entry action initializeSelfTest;
        state Off;
        state Standby;
        state SelfTest;
        state Ventilating;
        state InspiratoryPhase;
        state ExpiratoryPhase;
        state AlarmActive;
        state FaultLockout;

        transition first Off;
        transition Off_to_SelfTest
            first Off
            then SelfTest;

        transition SelfTest_to_Standby
            first SelfTest
            then Standby;

        transition Standby_to_InspiratoryPhase
            first Standby
            then InspiratoryPhase;

        transition InspiratoryPhase_to_ExpiratoryPhase
            first InspiratoryPhase
            then ExpiratoryPhase;

        transition ExpiratoryPhase_to_InspiratoryPhase
            first ExpiratoryPhase
            then InspiratoryPhase;

        transition AnyVentilation_to_AlarmActive
            first Ventilating
            then AlarmActive;

        transition AlarmActive_to_Ventilating
            first AlarmActive
            then Ventilating;

        transition Fault_to_FaultLockout
            first AlarmActive
            then FaultLockout;
    }

    requirement def PrimaryFunctionRequirement {
        subject respirator : SAHRA_MechanicalRespirator;
        doc /* The respirator shall provide mechanical ventilatory support by delivering controlled breaths of breathable gas to a patient through a breathing circuit while supporting exhalation, maintaining selected airway pressure and volume targets, and monitoring for unsafe conditions. */
    }

    requirement def DeliveredVolumeRequirement {
        subject respirator : SAHRA_MechanicalRespirator;
        attribute requiredTidalVolume : VolumeValue = 500;
        attribute tolerance : FractionValue = 0.15;
        doc /* In volume-controlled operation, the respirator shall deliver the selected tidal volume within plus or minus 15 percent under nominal patient circuit conditions. */
    }

    requirement def PressureLimitRequirement {
        subject respirator : SAHRA_MechanicalRespirator;
        attribute maximumAllowedAirwayPressure : PressureValue = 40;
        doc /* The respirator shall prevent sustained patient airway pressure above the configured maximum airway pressure limit. */
    }

    requirement def PEEPRequirement {
        subject respirator : SAHRA_MechanicalRespirator;
        attribute minimumPEEP : PressureValue = 3;
        attribute maximumPEEP : PressureValue = 20;
        doc /* The respirator shall maintain operator-selected positive end expiratory pressure within the supported PEEP range during expiration. */
    }

    requirement def OxygenBlendingRequirement {
        subject respirator : SAHRA_MechanicalRespirator;
        attribute minimumFiO2 : OxygenConcentrationValue = 21;
        attribute maximumFiO2 : OxygenConcentrationValue = 100;
        doc /* The respirator shall support delivery of air or oxygen-enriched gas across the configured oxygen concentration range when connected to a suitable oxygen source. */
    }

    requirement def AlarmRequirement {
        subject respirator : SAHRA_MechanicalRespirator;
        doc /* The respirator shall generate audible and visual alarms for high airway pressure, low delivered volume, patient circuit disconnect, power loss, sensor failure, and actuator fault. */
    }

    requirement def PowerRequirement {
        subject respirator : SAHRA_MechanicalRespirator;
        attribute nominalPowerDemand : ElectricalPowerValue = 65;
        attribute nominalInputVoltage : VoltageValue = 24;
        doc /* The respirator shall operate from the specified electrical supply and provide managed power to control, display, sensing, alarm, and mechanical drive functions. */
    }

    satisfy PrimaryFunctionRequirement by SAHRA_MechanicalRespirator;
    satisfy DeliveredVolumeRequirement by MechanicalDriveModule;
    satisfy PressureLimitRequirement by PressureReliefValve;
    satisfy PEEPRequirement by PEEPValve;
    satisfy OxygenBlendingRequirement by OxygenMixer;
    satisfy AlarmRequirement by AlarmSystem;
    satisfy PowerRequirement by PowerSubsystem;
}