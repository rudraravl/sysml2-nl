package FlameDetectorSystemModel {

	import ScalarValues::*;
	import SI::*;
	import ISQ::*;

	attribute def Irradiance :> Real {
		doc /* Radiant flux incident on a surface per unit area. */
		attribute unitSymbol : String = "W/m^2";
	}

	attribute def Temperature :> Real {
		doc /* Thermodynamic temperature. */
		attribute unitSymbol : String = "degC";
	}

	attribute def TimeDuration :> Real {
		doc /* Elapsed time duration. */
		attribute unitSymbol : String = "s";
	}

	attribute def Voltage :> Real {
		doc /* Electric potential difference. */
		attribute unitSymbol : String = "V";
	}

	attribute def Current :> Real {
		doc /* Electric current. */
		attribute unitSymbol : String = "A";
	}

	attribute def Power :> Real {
		doc /* Electric power. */
		attribute unitSymbol : String = "W";
	}

	attribute def Probability :> Real {
		doc /* Dimensionless probability in the range 0..1. */
	}

	attribute def Angle :> Real {
		doc /* Angular field of view. */
		attribute unitSymbol : String = "deg";
	}

	attribute def Distance :> Real {
		doc /* Linear distance. */
		attribute unitSymbol : String = "m";
	}

	attribute def Frequency :> Real {
		doc /* Signal or event frequency. */
		attribute unitSymbol : String = "Hz";
	}

	enum def DetectorMode {
		enum off;
		enum startup;
		enum standby;
		enum monitoring;
		enum suspectFlame;
		enum alarm;
		enum fault;
		enum maintenance;
	}

	enum def AlarmSeverity {
		enum advisory;
		enum warning;
		enum fireAlarm;
		enum detectorFault;
	}

	enum def FlameClassification {
		enum noFlame;
		enum possibleFlame;
		enum confirmedFlame;
		enum obscured;
		enum invalid;
	}

	enum def FaultCode {
		enum none;
		enum lowSupplyVoltage;
		enum sensorSaturation;
		enum opticalWindowContaminated;
		enum processorWatchdogExpired;
		enum communicationLost;
		enum selfTestFailed;
		enum excessiveTemperature;
	}

	item def UltravioletRadiation {
		attribute wavelengthMin : Real = 180.0;
		attribute wavelengthMax : Real = 260.0;
		attribute wavelengthUnit : String = "nm";
		attribute irradiance : Irradiance;
	}

	item def InfraredRadiation {
		attribute wavelengthMin : Real = 4.1;
		attribute wavelengthMax : Real = 4.7;
		attribute wavelengthUnit : String = "um";
		attribute irradiance : Irradiance;
	}

	item def FlameOpticalSignature {
		attribute uvBand : UltravioletRadiation;
		attribute irBand : InfraredRadiation;
		attribute flickerFrequency : Frequency;
		attribute apparentSourceDistance : Distance;
		attribute confidence : Probability;
	}

	item def ElectricalSupply {
		attribute voltage : Voltage;
		attribute currentAvailable : Current;
		attribute powerAvailable : Power;
	}

	item def ConditionedPower {
		attribute voltage : Voltage;
		attribute currentLimit : Current;
		attribute rippleVoltage : Voltage;
	}

	item def AlarmSignal {
		attribute severity : AlarmSeverity;
		attribute classification : FlameClassification;
		attribute confidence : Probability;
		attribute timestamp : TimeDuration;
		attribute message : String;
	}

	item def StatusMessage {
		attribute mode : DetectorMode;
		attribute fault : FaultCode;
		attribute supplyVoltage : Voltage;
		attribute internalTemperature : Temperature;
		attribute opticalWindowTransmission : Probability;
		attribute lastDetectionConfidence : Probability;
	}

	item def MaintenanceCommand {
		attribute requestSelfTest : Boolean;
		attribute resetLatchedAlarm : Boolean;
		attribute enterMaintenanceMode : Boolean;
		attribute exitMaintenanceMode : Boolean;
	}

	item def ConfigurationData {
		attribute uvThreshold : Irradiance;
		attribute irThreshold : Irradiance;
		attribute minimumConfidence : Probability;
		attribute alarmDelay : TimeDuration;
		attribute fieldOfView : Angle;
	}

	item def DiagnosticResult {
		attribute passed : Boolean;
		attribute fault : FaultCode;
		attribute detail : String;
	}

	port def OpticalInputPort {
		in item uvRadiation : UltravioletRadiation;
		in item irRadiation : InfraredRadiation;
	}

	port def FlameEmissionPort {
		out item uvRadiation : UltravioletRadiation;
		out item irRadiation : InfraredRadiation;
	}

	port def ElectricalPowerInPort {
		in item supply : ElectricalSupply;
	}

	port def ConditionedPowerPort {
		out item conditionedPower : ConditionedPower;
	}

	port def InternalPowerPort {
		in item conditionedPower : ConditionedPower;
	}

	port def AlarmOutputPort {
		out item alarm : AlarmSignal;
	}

	port def StatusOutputPort {
		out item status : StatusMessage;
	}

	port def MaintenancePort {
		in item command : MaintenanceCommand;
		out item result : DiagnosticResult;
	}

	port def ConfigurationPort {
		in item configuration : ConfigurationData;
	}

	port def SensorSignalPort {
		out item signature : FlameOpticalSignature;
	}

	port def ProcessorInputPort {
		in item signature : FlameOpticalSignature;
	}

	port def ProcessorAlarmPort {
		out item alarm : AlarmSignal;
		out item status : StatusMessage;
	}

	part def ProtectedZone {
		doc /* Space monitored by the flame detector for optical flame signatures. */

		attribute zoneLength : Distance = 20.0;
		attribute zoneWidth : Distance = 12.0;
		attribute zoneHeight : Distance = 6.0;
		attribute ambientTemperature : Temperature = 25.0;
		attribute expectedMaximumDistanceToFlame : Distance = 18.0;

		port flameEmission : FlameEmissionPort;

		item simulatedFlameUV : UltravioletRadiation {
			attribute wavelengthMin = 180.0;
			attribute wavelengthMax = 260.0;
			attribute irradiance = 0.000003;
		}

		item simulatedFlameIR : InfraredRadiation {
			attribute wavelengthMin = 4.1;
			attribute wavelengthMax = 4.7;
			attribute irradiance = 0.000020;
		}
	}

	part def PrimaryPowerSource {
		attribute nominalVoltage : Voltage = 24.0;
		attribute minimumVoltage : Voltage = 18.0;
		attribute maximumVoltage : Voltage = 32.0;
		attribute availableCurrent : Current = 0.5;
		attribute availablePower : Power = 12.0;

		port powerOut : ConditionedPowerPort;
	}

	part def OpticalWindow {
		doc /* Transparent protective interface admitting UV and IR radiation while sealing the detector housing. */

		attribute uvTransmission : Probability = 0.88;
		attribute irTransmission : Probability = 0.92;
		attribute contaminationIndex : Probability = 0.02;
		attribute minimumAllowedTransmission : Probability = 0.70;

		port externalOptics : OpticalInputPort;
		port internalOptics : FlameEmissionPort;
	}

	part def UltravioletSensor {
		doc /* Sensor channel sensitive to flame ultraviolet radiation. */

		attribute spectralMin : Real = 180.0;
		attribute spectralMax : Real = 260.0;
		attribute spectralUnit : String = "nm";
		attribute noiseEquivalentIrradiance : Irradiance = 0.0000002;
		attribute saturationIrradiance : Irradiance = 0.01;
		attribute responseTime : TimeDuration = 0.050;

		port opticalIn : OpticalInputPort;
		port signalOut : SensorSignalPort;
		port powerIn : InternalPowerPort;
	}

	part def InfraredSensor {
		doc /* Sensor channel sensitive to carbon-dioxide flame infrared emission near 4.4 um. */

		attribute spectralMin : Real = 4.1;
		attribute spectralMax : Real = 4.7;
		attribute spectralUnit : String = "um";
		attribute noiseEquivalentIrradiance : Irradiance = 0.0000010;
		attribute saturationIrradiance : Irradiance = 0.02;
		attribute responseTime : TimeDuration = 0.080;

		port opticalIn : OpticalInputPort;
		port signalOut : SensorSignalPort;
		port powerIn : InternalPowerPort;
	}

	part def SignalProcessor {
		doc /* Digital processor that filters sensor signals, correlates UV/IR flicker behavior, classifies flame presence, and generates alarm/status outputs. */

		attribute sampleRate : Frequency = 200.0;
		attribute uvThreshold : Irradiance = 0.0000010;
		attribute irThreshold : Irradiance = 0.0000060;
		attribute minimumFlickerFrequency : Frequency = 1.0;
		attribute maximumFlickerFrequency : Frequency = 20.0;
		attribute minimumAlarmConfidence : Probability = 0.85;
		attribute maximumDetectionLatency : TimeDuration = 3.0;
		attribute falseAlarmProbabilityPerHour : Probability = 0.000001;
		attribute currentMode : DetectorMode = DetectorMode::off;
		attribute currentFault : FaultCode = FaultCode::none;

		port uvInput : ProcessorInputPort;
		port irInput : ProcessorInputPort;
		port configurationIn : ConfigurationPort;
		port maintenance : MaintenancePort;
		port processorOut : ProcessorAlarmPort;
		port powerIn : InternalPowerPort;

		perform action monitorAndClassify : MonitorForFlame;
		exhibit state operatingState : FlameDetectorOperatingState;
	}

	part def AlarmInterface {
		doc /* Electrical and logical interface that transmits fire alarms and detector faults to external annunciation or safety systems. */

		attribute relayContactRatingVoltage : Voltage = 30.0;
		attribute relayContactRatingCurrent : Current = 1.0;
		attribute alarmLatched : Boolean = false;

		port alarmIn : ProcessorInputPort;
		port alarmOut : AlarmOutputPort;
		port statusOut : StatusOutputPort;
		port powerIn : InternalPowerPort;
	}

	part def PowerConditioner {
		doc /* Converts incoming 24 Vdc supply to regulated internal supply rails and reports supply faults. */

		attribute inputMinimumVoltage : Voltage = 18.0;
		attribute inputMaximumVoltage : Voltage = 32.0;
		attribute regulatedVoltage : Voltage = 5.0;
		attribute maximumOutputCurrent : Current = 0.25;
		attribute maximumOutputPower : Power = 1.25;
		attribute undervoltageFaultThreshold : Voltage = 17.5;

		port supplyIn : ElectricalPowerInPort;
		port conditionedOut : ConditionedPowerPort;
	}

	part def SelfTestEmitter {
		doc /* Internal optical test source used to verify UV and IR sensor response without requiring an external flame. */

		attribute uvTestIrradiance : Irradiance = 0.0000020;
		attribute irTestIrradiance : Irradiance = 0.0000100;
		attribute testPulseDuration : TimeDuration = 0.200;

		port testOpticalOut : FlameEmissionPort;
		port powerIn : InternalPowerPort;
	}

	part def FlameDetector {
		doc /* Flame detector assembly whose primary function is to observe a protected zone, identify optical flame signatures, and issue a timely alarm when flame is confirmed. */

		attribute nominalFieldOfView : Angle = 100.0;
		attribute maximumDetectionRange : Distance = 18.0;
		attribute alarmResponseTime : TimeDuration = 3.0;
		attribute minimumDetectionConfidence : Probability = 0.85;
		attribute operatingTemperatureMin : Temperature = -40.0;
		attribute operatingTemperatureMax : Temperature = 75.0;
		attribute ingressProtectionRating : String = "IP66";

		port opticalIn : OpticalInputPort;
		port powerIn : ElectricalPowerInPort;
		port alarmOut : AlarmOutputPort;
		port statusOut : StatusOutputPort;
		port maintenance : MaintenancePort;
		port configurationIn : ConfigurationPort;

		part window : OpticalWindow;
		part uvSensor : UltravioletSensor;
		part irSensor : InfraredSensor;
		part processor : SignalProcessor;
		part alarmInterface : AlarmInterface;
		part powerConditioner : PowerConditioner;
		part selfTestEmitter : SelfTestEmitter;

		connection externalOpticalPath connect opticalIn to window.externalOptics;
		connection transmittedOpticalPathToUV connect window.internalOptics to uvSensor.opticalIn;
		connection transmittedOpticalPathToIR connect window.internalOptics to irSensor.opticalIn;
		connection selfTestPathToUV connect selfTestEmitter.testOpticalOut to uvSensor.opticalIn;
		connection selfTestPathToIR connect selfTestEmitter.testOpticalOut to irSensor.opticalIn;

		connection externalPowerCable connect powerIn to powerConditioner.supplyIn;
		connection conditionedPowerToUV connect powerConditioner.conditionedOut to uvSensor.powerIn;
		connection conditionedPowerToIR connect powerConditioner.conditionedOut to irSensor.powerIn;
		connection conditionedPowerToProcessor connect powerConditioner.conditionedOut to processor.powerIn;
		connection conditionedPowerToAlarmInterface connect powerConditioner.conditionedOut to alarmInterface.powerIn;
		connection conditionedPowerToSelfTestEmitter connect powerConditioner.conditionedOut to selfTestEmitter.powerIn;

		connection uvSignalPath connect uvSensor.signalOut to processor.uvInput;
		connection irSignalPath connect irSensor.signalOut to processor.irInput;
		connection configurationPath connect configurationIn to processor.configurationIn;
		connection maintenancePath connect maintenance to processor.maintenance;
		connection processorAlarmPath connect processor.processorOut to alarmInterface.alarmIn;
		connection externalAlarmPath connect alarmInterface.alarmOut to alarmOut;
		connection externalStatusPath connect alarmInterface.statusOut to statusOut;
	}

	part def FireAlarmControlPanel {
		doc /* External system receiving flame detector alarms and status messages. */

		attribute panelSupplyVoltage : Voltage = 24.0;
		attribute alarmInputImpedance : Real = 10000.0;
		attribute impedanceUnit : String = "ohm";

		port alarmIn : AlarmOutputPort;
		port statusIn : StatusOutputPort;
		port maintenanceOut : MaintenancePort;
		port configurationOut : ConfigurationPort;
	}

	part def FlameDetectionSystem {
		doc /* System based on a flame detector. Its high-level primary function is to continuously monitor optical radiation from a protected zone, discriminate true flame signatures from background radiation, and communicate a fire alarm when a flame is confirmed. */

		attribute systemAvailability : Probability = 0.995;
		attribute maximumEndToEndAlarmLatency : TimeDuration = 3.0;
		attribute protectedZoneCoverage : Probability = 0.95;

		part protectedZone : ProtectedZone;
		part detector : FlameDetector;
		part powerSource : PrimaryPowerSource;
		part controlPanel : FireAlarmControlPanel;

		connection zoneToDetectorOpticalPath connect protectedZone.flameEmission to detector.opticalIn;
		connection sourceToDetectorPowerPath connect powerSource.powerOut to detector.powerIn;
		connection detectorAlarmToPanel connect detector.alarmOut to controlPanel.alarmIn;
		connection detectorStatusToPanel connect detector.statusOut to controlPanel.statusIn;
		connection panelMaintenanceToDetector connect controlPanel.maintenanceOut to detector.maintenance;
		connection panelConfigurationToDetector connect controlPanel.configurationOut to detector.configurationIn;

		perform action primaryFunction : DetectAndAnnunciateFlame;
	}

	action def AcquireOpticalRadiation {
		in item uvIn : UltravioletRadiation;
		in item irIn : InfraredRadiation;
		out item signature : FlameOpticalSignature;

		attribute acquisitionPeriod : TimeDuration = 0.005;
		attribute fieldOfView : Angle = 100.0;
	}

	action def FilterBackgroundRadiation {
		in item rawSignature : FlameOpticalSignature;
		out item filteredSignature : FlameOpticalSignature;

		attribute lowFlickerRejectionFrequency : Frequency = 0.5;
		attribute highFlickerRejectionFrequency : Frequency = 30.0;
		attribute sunlightRejectionEnabled : Boolean = true;
		attribute weldingArcRejectionEnabled : Boolean = true;
	}

	action def CorrelateUVIRPattern {
		in item filteredSignature : FlameOpticalSignature;
		out item classification : FlameOpticalSignature;

		attribute uvThreshold : Irradiance = 0.0000010;
		attribute irThreshold : Irradiance = 0.0000060;
		attribute requiredTemporalCorrelation : Probability = 0.80;
		attribute minimumConfidence : Probability = 0.85;
	}

	action def GenerateAlarmDecision {
		in item classificationInput : FlameOpticalSignature;
		out item alarmDecision : AlarmSignal;
		out item statusDecision : StatusMessage;

		attribute alarmDelay : TimeDuration = 0.500;
		attribute latchAlarm : Boolean = true;
	}

	action def PerformSelfTest {
		out item result : DiagnosticResult;

		attribute selfTestInterval : TimeDuration = 3600.0;
		attribute opticalPulseDuration : TimeDuration = 0.200;
		attribute requiredSensorResponse : Probability = 0.75;
	}

	action def MonitorForFlame {
		doc /* Repeating behavior executed by the signal processor to transform incoming UV and IR sensor observations into flame classification, alarm, and status information. */

		in item uvSignature : FlameOpticalSignature;
		in item irSignature : FlameOpticalSignature;
		in item configuration : ConfigurationData;
		out item alarm : AlarmSignal;
		out item status : StatusMessage;

		first acquire : AcquireOpticalRadiation;
		then filter : FilterBackgroundRadiation;
		then correlate : CorrelateUVIRPattern;
		then decide : GenerateAlarmDecision;

		flow acquire.signature to filter.rawSignature;
		flow filter.filteredSignature to correlate.filteredSignature;
		flow correlate.classification to decide.classificationInput;
		flow decide.alarmDecision to alarm;
		flow decide.statusDecision to status;
	}

	action def DetectAndAnnunciateFlame {
		doc /* High-level system function: receive optical radiation from the protected zone, determine whether the radiation is consistent with flame, and send a fire alarm to the control panel when confirmed. */

		in item zoneUV : UltravioletRadiation;
		in item zoneIR : InfraredRadiation;
		out item panelAlarm : AlarmSignal;
		out item panelStatus : StatusMessage;

		attribute maximumAllowedLatency : TimeDuration = 3.0;
		attribute requiredConfidence : Probability = 0.85;

		action monitor : MonitorForFlame;
		action selfTest : PerformSelfTest;

		flow monitor.alarm to panelAlarm;
		flow monitor.status to panelStatus;
	}

	state def FlameDetectorOperatingState {
		doc /* Operating state behavior for the flame detector signal processor and alarm logic. */

		attribute mode : DetectorMode;

		entry action initialize {
			out item initialStatus : StatusMessage {
				attribute mode = DetectorMode::startup;
				attribute fault = FaultCode::none;
				attribute message : String = "Initializing flame detector";
			}
		}

		state off;
		state startup;
		state standby;
		state monitoring;
		state suspectFlame;
		state alarm;
		state fault;
		state maintenance;

		transition initialTransition first off;

		transition powerApplied
			first off
			then startup;

		transition initializationComplete
			first startup
			then standby;

		transition monitoringEnabled
			first standby
			then monitoring;

		transition flameSignatureAbovePrealarmThreshold
			first monitoring
			then suspectFlame;

		transition flameConfirmed
			first suspectFlame
			then alarm;

		transition signatureRejected
			first suspectFlame
			then monitoring;

		transition resetLatchedAlarm
			first alarm
			then monitoring;

		transition faultDetectedFromAnyOperatingState
			first monitoring
			then fault;

		transition faultDetectedDuringStartup
			first startup
			then fault;

		transition faultCleared
			first fault
			then standby;

		transition enterMaintenance
			first standby
			then maintenance;

		transition exitMaintenance
			first maintenance
			then standby;
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The flame detection system shall continuously monitor the protected zone and provide a fire alarm when a flame is confirmed. */

		subject system : FlameDetectionSystem;

		require constraint {
			system.maximumEndToEndAlarmLatency <= 3.0
		}
	}

	requirement def DetectionCoverageRequirement {
		doc /* The detector shall cover the protected zone within its specified field of view and maximum range. */

		subject detector : FlameDetector;

		require constraint {
			detector.nominalFieldOfView >= 90.0 and detector.maximumDetectionRange >= 18.0
		}
	}

	requirement def AlarmLatencyRequirement {
		doc /* The detector shall issue an alarm within the allowed response time after a qualifying flame signature is present. */

		subject detector : FlameDetector;

		require constraint {
			detector.alarmResponseTime <= 3.0
		}
	}

	requirement def DetectionConfidenceRequirement {
		doc /* The detector shall require sufficient classification confidence before issuing a fire alarm. */

		subject detector : FlameDetector;

		require constraint {
			detector.minimumDetectionConfidence >= 0.85
		}
	}

	requirement def SupplyVoltageRequirement {
		doc /* The detector shall operate from a nominal 24 Vdc fire-alarm supply over the specified supply range. */

		subject conditioner : PowerConditioner;

		require constraint {
			conditioner.inputMinimumVoltage <= 18.0 and conditioner.inputMaximumVoltage >= 32.0
		}
	}

	requirement def EnvironmentalOperatingRequirement {
		doc /* The detector shall operate over the specified industrial temperature range. */

		subject detector : FlameDetector;

		require constraint {
			detector.operatingTemperatureMin <= -40.0 and detector.operatingTemperatureMax >= 75.0
		}
	}

	requirement def FalseAlarmRejectionRequirement {
		doc /* The signal processor shall reject common non-flame optical backgrounds such that false-alarm probability remains below the specified value. */

		subject processor : SignalProcessor;

		require constraint {
			processor.falseAlarmProbabilityPerHour <= 0.000001
		}
	}

	requirement def SelfTestRequirement {
		doc /* The detector shall support an internal self-test that verifies optical path, UV channel, IR channel, processor, and alarm output readiness. */

		subject emitter : SelfTestEmitter;

		require constraint {
			emitter.testPulseDuration <= 0.500
		}
	}

	requirement def FaultReportingRequirement {
		doc /* The detector shall report internal faults as status messages and shall distinguish fire alarms from detector faults. */

		subject processor : SignalProcessor;

		require constraint {
			processor.currentFault == FaultCode::none or processor.currentMode == DetectorMode::fault
		}
	}

	satisfy PrimaryFunctionRequirement by FlameDetectionSystem::primaryFunction;
	satisfy DetectionCoverageRequirement by FlameDetector;
	satisfy AlarmLatencyRequirement by FlameDetector::processor::monitorAndClassify;
	satisfy DetectionConfidenceRequirement by SignalProcessor;
	satisfy SupplyVoltageRequirement by PowerConditioner;
	satisfy EnvironmentalOperatingRequirement by FlameDetector;
	satisfy FalseAlarmRejectionRequirement by SignalProcessor;
	satisfy SelfTestRequirement by SelfTestEmitter;
	satisfy FaultReportingRequirement by SignalProcessor;

	part flameDetectionInstallation : FlameDetectionSystem;

}
