package ProtectiveVentilator {
    import ScalarValues::*;

    // ===== Unit Definitions =====
    unit cmH2O;
    unit mL;
    unit L_per_min;
    unit bpm;
    unit s;
    unit kg;

    // ===== Value Type Definitions =====
    attribute def Pressure :> Real {
        doc /* Airway pressure in centimeters of water */
        unit cmH2O;
    }

    attribute def Volume :> Real {
        doc /* Gas volume in milliliters */
        unit mL;
    }

    attribute def FlowRate :> Real {
        doc /* Gas flow rate in liters per minute */
        unit L_per_min;
    }

    attribute def Frequency :> Real {
        doc /* Frequency in breaths per minute */
        unit bpm;
    }

    attribute def Duration :> Real {
        doc /* Time duration in seconds */
        unit s;
    }

    attribute def BodyWeight :> Real {
        doc /* Body weight in kilograms */
        unit kg;
    }

    attribute def Fraction :> Real {
        doc /* Dimensionless fraction in range 0.0 to 1.0 */
    }

    // ===== Item Definitions =====
    item def BreathingGas {
        doc /* Breathable gas mixture delivered to patient */
        attribute oxygenConcentration : Fraction;
        attribute temperature : Real;
        attribute humidity : Real;
    }

    item def SensorReading {
        doc /* Aggregated real-time sensor data from breathing circuit */
        attribute airwayPressure : Pressure;
        attribute tidalVolume : Volume;
        attribute flowRate : FlowRate;
        attribute fiO2 : Fraction;
        attribute timestamp : Real;
    }

    item def AlarmEvent {
        doc /* Alarm event with severity and descriptive message */
        attribute severity : Integer;
        attribute code : String;
        attribute message : String;
    }

    item def VentilatorSettings {
        doc /* Clinical settings for ventilation therapy */
        attribute respiratoryRate : Frequency;
        attribute fiO2 : Fraction;
        attribute targetTidalVolume : Volume;
        attribute peep : Pressure;
        attribute plateauPressureLimit : Pressure;
        attribute inspiratoryTime : Duration;
        attribute flowPattern : String;
    }

    item def ControlCommand {
        doc /* Command from controller to pneumatic or alarm subsystem */
        attribute commandType : String;
        attribute targetValue : Real;
        attribute commandUnit : String;
    }

    // ===== Port Definitions =====
    port def GasFlowPort {
        doc /* Port carrying breathable gas flow */
        out item gas : BreathingGas;
        attribute pressure : Pressure;
        attribute flow : FlowRate;
    }

    port def SensorDataPort {
        doc /* Port carrying sensor readings */
        out item reading : SensorReading;
    }

    port def ControlPort {
        doc /* Port carrying control commands */
        out item command : ControlCommand;
    }

    port def SettingsPort {
        doc /* Port receiving ventilator settings */
        in item settings : VentilatorSettings;
    }

    port def AlarmPort {
        doc /* Port carrying alarm events */
        out item alarm : AlarmEvent;
    }

    // ===== Connection Definitions =====
    connection def GasConnection {
        doc /* Connection for gas flow between two gas flow ports */
        end supplier : GasFlowPort;
        end consumer : ~GasFlowPort;
    }

    connection def DataConnection {
        doc /* Connection for sensor data transmission */
        end supplier : SensorDataPort;
        end consumer : ~SensorDataPort;
    }

    connection def CommandConnection {
        doc /* Connection for control commands */
        end supplier : ControlPort;
        end consumer : ~ControlPort;
    }

    connection def SettingsConnection {
        doc /* Connection for ventilator settings */
        end supplier : ~SettingsPort;
        end consumer : SettingsPort;
    }

    connection def AlarmConnection {
        doc /* Connection for alarm event routing */
        end supplier : AlarmPort;
        end consumer : ~AlarmPort;
    }

    // ===== Pneumatic Delivery System =====
    part def PneumaticDeliverySystem {
        doc /* Physical mechanism delivering controlled breathable gas to the patient, managing inspiration and PEEP */

        port gasOutput : GasFlowPort;
        port controlInput : ~ControlPort;

        attribute currentFlow : FlowRate;
        attribute currentPressure : Pressure;
        attribute deliveredVolume : Volume;
        attribute valveState : String;
        attribute isDelivering : Boolean;

        part oxygenSource {
            doc /* Pressurized oxygen supply */
            attribute supplyPressure : Pressure := 50;
            attribute purity : Fraction := 1.0;
        }

        part airSource {
            doc /* Pressurized medical air supply */
            attribute supplyPressure : Pressure := 50;
        }

        part gasMixer {
            doc /* Blends oxygen and air to achieve target FiO2 */
            attribute oxygenFraction : Fraction;
            attribute outputGas : BreathingGas;
        }

        part inspiratoryValve {
            doc /* Proportional valve controlling inspiratory flow */
            attribute openness : Real := 0.0;
            attribute maxFlow : FlowRate := 120;
        }

        part expiratoryValve {
            doc /* Proportional valve controlling expiratory flow and PEEP */
            attribute openness : Real := 1.0;
        }

        part peepValve {
            doc /* Valve maintaining positive end-expiratory pressure */
            attribute peepLevel : Pressure := 5;
            attribute tolerance : Pressure := 2;
        }

        part pressureRegulator {
            doc /* Regulates output pressure and provides safety relief */
            attribute regulatedPressure : Pressure;
            attribute safetyReliefThreshold : Pressure := 60;
        }

        action def PerformInspiration {
            doc /* Opens inspiratory valve and delivers target volume at target flow for the specified inspiratory time */
            in targetVolume : Volume;
            in targetFlow : FlowRate;
            in gasMixture : BreathingGas;
            in inspiratoryTime : Duration;
            out deliveredVol : Volume;
            out peakPressure : Pressure;
        }

        action def PerformExpiration {
            doc /* Closes inspiratory valve and regulates expiratory valve to maintain PEEP during passive exhalation */
            in peepTarget : Pressure;
            out endPressure : Pressure;
            out exhaledVolume : Volume;
        }

        action def MaintainPEEP {
            doc /* Continuously regulates expiratory valve opening to hold PEEP within tolerance */
            in peepTarget : Pressure;
            in measuredPressure : Pressure;
        }

        action def EmergencyStop {
            doc /* Immediately closes inspiratory valve and fully opens expiratory valve to release pressure */
            out safeState : Boolean;
        }
    }

    // ===== Sensor Array =====
    part def SensorArray {
        doc /* Suite of sensors continuously monitoring airway pressure, tidal volume, and gas flow */

        port sensorOutput : SensorDataPort;
        port gasSampling : ~GasFlowPort;

        attribute samplingRate : Frequency := 100;
        attribute lastReading : SensorReading;
        attribute isCalibrated : Boolean := true;

        part pressureSensor {
            doc /* Measures airway pressure in real-time */
            attribute measuredPressure : Pressure;
            attribute accuracy : Pressure := 1;
            attribute rangeMax : Pressure := 100;
        }

        part flowSensor {
            doc /* Measures gas flow rate in the breathing circuit */
            attribute measuredFlow : FlowRate;
            attribute accuracy : FlowRate := 0.5;
            attribute rangeMax : FlowRate := 150;
        }

        part volumeSensor {
            doc /* Computes delivered volume by integrating flow signal over time */
            attribute accumulatedVolume : Volume;
            attribute accuracy : Volume := 5;
        }

        part oxygenSensor {
            doc /* Measures oxygen concentration in delivered gas */
            attribute measuredFiO2 : Fraction;
            attribute accuracy : Fraction := 0.03;
        }

        action def SampleAllSensors {
            doc /* Samples all sensors and packages readings into a single SensorReading item */
            in pressureSignal : Pressure;
            in flowSignal : FlowRate;
            in fiO2Signal : Fraction;
            out reading : SensorReading;
        }

        action def IntegrateFlowToVolume {
            doc /* Numerically integrates flow rate over a time step to produce a volume increment */
            in flowSignal : FlowRate;
            in deltaTime : Duration;
            out volumeIncrement : Volume;
        }

        action def CalibrateSensors {
            doc /* Performs zero-point calibration and range verification on all sensors */
            out calibrationStatus : Boolean;
        }
    }

    // ===== Alarm System =====
    part def AlarmSystem {
        doc /* Alerts medical staff through audible and visual indicators when safety limits are violated */

        port alarmOutput : AlarmPort;
        port triggerInput : ~ControlPort;

        attribute activeAlarms : AlarmEvent[0..*];
        attribute alarmLog : AlarmEvent[0..*];
        attribute alarmVolume : Real := 80.0;

        part audibleAlarm {
            doc /* Sound generator for audible alerts */
            attribute volume : Real := 80.0;
            attribute pattern : String;
            attribute isSilenced : Boolean := false;
        }

        part visualAlarm {
            doc /* Visual display for visual alerts */
            attribute color : String;
            attribute isFlashing : Boolean := false;
            attribute displayMessage : String;
        }

        action def RaiseAlarm {
            doc /* Raises an alarm with the specified severity, code, and message */
            in severity : Integer;
            in code : String;
            in message : String;
            out alarm : AlarmEvent;
        }

        action def ClearAlarm {
            doc /* Clears an active alarm identified by its code */
            in code : String;
        }

        action def LogAlarm {
            doc /* Records an alarm event in the persistent alarm log */
            in alarm : AlarmEvent;
        }

        action def EscalateAlarm {
            doc /* Increases alarm severity and audible volume if not acknowledged within timeout */
            in alarm : AlarmEvent;
            out escalatedAlarm : AlarmEvent;
        }
    }

    // ===== Ventilator Controller =====
    part def VentilatorController {
        doc /* Central controller that executes a lung-protective ventilation strategy using clinical settings, patient parameters, and closed-loop sensor feedback */

        port settingsInput : SettingsPort;
        port sensorInput : ~SensorDataPort;
        port pneumaticControl : ControlPort;
        port alarmControl : ControlPort;

        attribute currentSettings : VentilatorSettings;
        attribute predictedBodyWeight : BodyWeight;
        attribute currentReading : SensorReading;

        attribute measuredPressure : Pressure;
        attribute measuredTidalVolume : Volume;
        attribute measuredFlow : FlowRate;
        attribute measuredFiO2 : Fraction;

        attribute computedTidalVolumeLimit : Volume;
        attribute computedPressureLimit : Pressure;

        attribute maxTidalVolumePerKg : Real := 8.0;
        attribute maxPlateauPressure : Pressure := 30;
        attribute minPEEP : Pressure := 5;

        attribute breathCounter : Integer := 0;
        attribute cyclePhase : String;
        attribute inspirationElapsed : Duration;

        attribute powerOn : Boolean := false;
        attribute selfTestPassed : Boolean := false;
        attribute ventilationStarted : Boolean := false;
        attribute inspirationTimerExpired : Boolean := false;
        attribute breathCycleComplete : Boolean := false;
        attribute alarmAcknowledged : Boolean := false;
        attribute safeConditionsRestored : Boolean := false;
        attribute pressureViolation : Boolean := false;
        attribute volumeViolation : Boolean := false;

        action def ComputeProtectiveLimits {
            doc /* Computes tidal volume limit as predicted body weight times mL per kg, and sets plateau pressure limit */
            in pbw : BodyWeight;
            in maxPerKg : Real;
            in maxPressure : Pressure;
            out tidalVolumeLimit : Volume;
            out pressureLimit : Pressure;
        }

        action def AnalyzeFeedback {
            doc /* Compares measured pressure and volume against computed safety limits and flags violations */
            in reading : SensorReading;
            in pressureLimit : Pressure;
            in volumeLimit : Volume;
            out pressureViolation : Boolean;
            out volumeViolation : Boolean;
            out severity : Integer;
            out message : String;
        }

        action def GenerateControlCommand {
            doc /* Produces a control command for the pneumatic delivery system */
            in phase : String;
            in targetValue : Real;
            in commandUnit : String;
            out command : ControlCommand;
        }

        action def TriggerAlarmCommand {
            doc /* Produces an alarm trigger command for the alarm system */
            in severity : Integer;
            in message : String;
            out command : ControlCommand;
        }

        action def UpdateSettings {
            doc /* Accepts new clinical settings and updates the active ventilation parameters */
            in newSettings : VentilatorSettings;
            out updatedSettings : VentilatorSettings;
        }

        action def BeginInspiration {
            doc /* Commands pneumatic system to start inspiration at target flow and volume */
        }

        action def MonitorInspiration {
            doc /* Continuously checks sensor feedback for pressure or volume violations during inspiration */
        }

        action def CompleteInspiration {
            doc /* Ends inspiration and prepares transition to expiration */
        }

        action def BeginExpiration {
            doc /* Commands pneumatic system to begin expiration with PEEP maintenance */
        }

        action def MonitorExpiration {
            doc /* Monitors PEEP levels and circuit integrity during expiration */
        }

        action def CompleteExpiration {
            doc /* Ends expiration, increments breath counter, and prepares next cycle */
        }

        action def ActivateAlarmProtocol {
            doc /* Suspends normal ventilation and commands alarm system to raise alert */
        }

        action def HoldVentilationSafe {
            doc /* Holds ventilation in a safe state while alarm is active */
        }

        action def ResetAfterAcknowledgment {
            doc /* Resets alarm state and prepares system to resume ventilation */
        }

        action def RunSelfTest {
            doc /* Runs comprehensive self-test on power-up */
        }

        action def VerifyComponents {
            doc /* Verifies pneumatic, sensor, and alarm components are functional */
        }

        action def ReportStatus {
            doc /* Reports self-test results to user interface */
        }

        action def WaitForStart {
            doc /* Waits for ventilation start command from clinical user */
        }

        action def MonitorUserInput {
            doc /* Monitors for setting changes or start command while idle */
        }

        action def InitializeController {
            doc /* Initializes controller attributes and subsystems on power-up */
        }

        state machine VentilationStateMachine {
            doc /* Governs the breathing cycle and safety response transitions */

            entry action initializeController;

            state Idle {
                doc /* System powered on but not actively ventilating */
                entry action waitForStart;
                do action monitorUserInput;
            }

            state SystemCheck {
                doc /* Running self-test and component verification */
                entry action runSelfTest;
                do action verifyComponents;
                exit action reportStatus;
            }

            state Inspiration {
                doc /* Actively delivering controlled gas volume to patient */
                entry action beginInspiration;
                do action monitorInspiration;
                exit action completeInspiration;
            }

            state Expiration {
                doc /* Patient exhaling with PEEP maintenance */
                entry action beginExpiration;
                do action monitorExpiration;
                exit action completeExpiration;
            }

            state AlarmActive {
                doc /* Safety violation detected; alarm active and ventilation held safe */
                entry action activateAlarmProtocol;
                do action holdVentilationSafe;
                exit action resetAfterAcknowledgment;
            }

            transition from Idle to SystemCheck when powerOn;
            transition from SystemCheck to Idle when selfTestPassed;
            transition from Idle to Inspiration when ventilationStarted;
            transition from Inspiration to Expiration when measuredTidalVolume >= currentSettings.targetTidalVolume;
            transition from Inspiration to Expiration when inspirationTimerExpired;
            transition from Inspiration to AlarmActive when measuredPressure > computedPressureLimit;
            transition from Inspiration to AlarmActive when measuredTidalVolume > computedTidalVolumeLimit;
            transition from Expiration to Inspiration when breathCycleComplete;
            transition from Expiration to AlarmActive when measuredPressure < minPEEP;
            transition from AlarmActive to Idle when alarmAcknowledged;
            transition from AlarmActive to Expiration when safeConditionsRestored;
        }
    }

    // ===== Main System =====
    part def ProtectiveVentilatorSystem {
        doc /* Complete protective mechanical ventilation system for critically ill patients */

        port patientCircuit : ~GasFlowPort;
        port clinicianInterface : ~SettingsPort;
        port systemAlarmOutput : ~AlarmPort;

        attribute systemStatus : String;
        attribute patientId : String;
        attribute systemSerialNumber : String;

        part pneumaticDelivery : PneumaticDeliverySystem;

        part sensorArray : SensorArray;

        part controller : VentilatorController;

        part alarmSystem : AlarmSystem;

        part userInterface {
            doc /* Clinical user interface for settings entry and alarm display */
            port settingsOutput : ~SettingsPort;
            port alarmInput : ~AlarmPort;
            attribute displayText : String;
            attribute knobPosition : Real;
            attribute buttonState : String;
        }

        connection gasToPatient : GasConnection connect pneumaticDelivery.gasOutput to patientCircuit;
        connection gasToSensor : GasConnection connect pneumaticDelivery.gasOutput to sensorArray.gasSampling;
        connection sensorToController : DataConnection connect sensorArray.sensorOutput to controller.sensorInput;
        connection controllerToPneumatic : CommandConnection connect controller.pneumaticControl to pneumaticDelivery.controlInput;
        connection controllerToAlarm : CommandConnection connect controller.alarmControl to alarmSystem.triggerInput;
        connection clinicianToController : SettingsConnection connect clinicianInterface to controller.settingsInput;
        connection uiToController : SettingsConnection connect userInterface.settingsOutput to controller.settingsInput;
        connection alarmToSystem : AlarmConnection connect alarmSystem.alarmOutput to systemAlarmOutput;
        connection alarmToUI : AlarmConnection connect alarmSystem.alarmOutput to userInterface.alarmInput;
    }

    // ===== Requirements =====
    requirement def ProtectiveVentilationRequirement {
        doc /* The system shall provide life-sustaining breathing support while actively preventing Ventilator-Associated Lung Injury */
        subject ventilatorSystem : ProtectiveVentilatorSystem;
    }

    requirement def PneumaticDeliveryRequirement :> ProtectiveVentilationRequirement {
        doc /* The pneumatic delivery system shall deliver controlled breathable gas to the patient */
        subject pneumaticSystem : PneumaticDeliverySystem;

        requirement DeliverPreciseVolume {
            doc /* The system shall deliver a precise tidal volume at a specified flow rate and pressure during inspiration */
        }

        requirement MaintainPEEP {
            doc /* The system shall maintain a constant positive end-expiratory pressure to prevent air sac collapse */
        }

        requirement ControlOxygenMix {
            doc /* The system shall deliver a controlled air-oxygen mixture at the specified FiO2 */
        }

        requirement EmergencyStopCapability {
            doc /* The system shall provide an emergency stop that immediately ceases inspiration and allows passive exhalation */
        }
    }

    requirement def SensorMonitoringRequirement :> ProtectiveVentilationRequirement {
        doc /* The sensor array shall continuously monitor the patient breathing circuit in real-time */
        subject sensorArray : SensorArray;

        requirement MeasureAirwayPressure {
            doc /* The system shall measure airway pressure continuously with accuracy of 1 cmH2O or better */
        }

        requirement MeasureTidalVolume {
            doc /* The system shall measure the volume of air delivered with each breath with accuracy of 5 mL or better */
        }

        requirement MeasureFlowRate {
            doc /* The system shall measure the rate of gas flow in the breathing circuit with accuracy of 0.5 L/min or better */
        }

        requirement MeasureOxygenConcentration {
            doc /* The system shall measure the oxygen concentration in the delivered gas */
        }

        requirement RealTimeMonitoring {
            doc /* All sensor measurements shall be available to the controller with minimal latency not exceeding 10 milliseconds */
        }
    }

    requirement def ControllerRequirement :> ProtectiveVentilationRequirement {
        doc /* The ventilator controller shall execute a protective ventilation strategy using clinical settings and patient parameters */
        subject controller : VentilatorController;

        requirement ReceiveClinicalSettings {
            doc /* The controller shall receive respiratory rate and oxygen concentration settings from a clinical user */
        }

        requirement UsePredictedBodyWeight {
            doc /* The controller shall use the patient predicted body weight to compute protective tidal volume limits at 8 mL/kg or less */
        }

        requirement EnforcePressureLimit {
            doc /* The controller shall trigger an alarm if measured airway pressure exceeds 30 cmH2O plateau pressure */
        }

        requirement EnforceVolumeLimit {
            doc /* The controller shall trigger an alarm if delivered tidal volume exceeds the computed safe limit for the patient size */
        }

        requirement ClosedLoopControl {
            doc /* The controller shall continuously analyze sensor feedback and adjust ventilation to maintain lung-protective parameters */
        }

        requirement OrchestrateBreathCycle {
            doc /* The controller shall orchestrate a breathing cycle of inspiration and expiration at the specified respiratory rate */
        }

        requirement ImmediateAlarmTrigger {
            doc /* The controller shall trigger the alarm system immediately upon detection of a safety limit violation */
        }
    }

    requirement def VALIPreventionRequirement :> ProtectiveVentilationRequirement {
        doc /* The system shall prevent ventilator-associated lung injury through protective ventilation strategies */

        requirement PreventBarotrauma {
            doc /* The system shall minimize the risk of barotrauma by enforcing strict pressure limits not exceeding 30 cmH2O */
        }

        requirement PreventVolutrauma {
            doc /* The system shall minimize the risk of volutrauma by enforcing strict volume limits based on predicted body weight */
        }

        requirement MaintainLungProtectiveRange {
            doc /* The closed-loop control system shall ensure ventilation is always within a lung-protective range */
        }
    }

    requirement def AlarmRequirement :> ProtectiveVentilationRequirement {
        doc /* The alarm system shall alert medical staff when safety limits are violated */
        subject alarmSystem : AlarmSystem;

        requirement ImmediateAlert {
            doc /* The alarm shall activate immediately upon detection of a safety violation */
        }

        requirement AudibleAndVisual {
            doc /* The alarm shall provide both audible and visual alerts to medical staff */
        }

        requirement AlarmEscalation {
            doc /* The alarm shall escalate in severity if not acknowledged within a specified time period */
        }

        requirement AlarmLogging {
            doc /* All alarm events shall be logged with timestamp and severity for clinical review */
        }
    }
}
