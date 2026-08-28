package BairHuggerForcedAirWarmingSystem {

    import ScalarValues::*;

    // ===== Value Types =====

    value def Temperature :> Real;
    value def Power :> Real;
    value def Voltage :> Real;
    value def FlowRate :> Real;
    value def RotationalSpeed :> Real;
    value def Length :> Real;
    value def Area :> Real;
    value def TimeValue :> Real;
    value def Percent :> Real;

    // ===== Items =====

    item def Air;
    item def AmbientAir :> Air;
    item def FilteredAir :> Air;
    item def HeatedAir :> Air;
    item def DistributedAir :> Air;

    // ===== Attribute Definitions =====

    attribute def TemperatureReading {
        value : Temperature;
        isValid : Boolean;
    }

    attribute def ControlCommand {
        targetTemp : Temperature;
        heaterDuty : Percent;
        blowerDuty : Percent;
    }

    attribute def AlarmEvent {
        alarmType : String;
        description : String;
        active : Boolean;
    }

    // ===== Port Definitions =====

    port def AirInPort {
        in item air : Air;
    }

    port def AirOutPort {
        out item air : Air;
    }

    port def CommandInPort {
        in command : ControlCommand;
    }

    port def CommandOutPort {
        out command : ControlCommand;
    }

    port def TempDataInPort {
        in reading : TemperatureReading;
    }

    port def TempDataOutPort {
        out reading : TemperatureReading;
    }

    port def PowerInPort {
        in voltage : Voltage;
    }

    port def PowerOutPort {
        out voltage : Voltage;
    }

    port def AlarmOutPort {
        out alarm : AlarmEvent;
    }

    port def AlarmInPort {
        in alarm : AlarmEvent;
    }

    // ===== Connection Definitions =====

    connection def AirFlow {
        end1 : AirOutPort;
        end2 : AirInPort;
    }

    connection def ControlLink {
        end1 : CommandOutPort;
        end2 : CommandInPort;
    }

    connection def TempLink {
        end1 : TempDataOutPort;
        end2 : TempDataInPort;
    }

    connection def PowerLink {
        end1 : PowerOutPort;
        end2 : PowerInPort;
    }

    connection def AlarmLink {
        end1 : AlarmOutPort;
        end2 : AlarmInPort;
    }

    // ===== Requirements =====

    requirement def WarmingSystemRequirement {
        doc
        ---
        The system shall deliver a continuous flow of temperature-controlled warm air through a disposable warming blanket to prevent and treat hypothermia in patients during surgical procedures.
        ---
    }

    requirement def TemperatureControlRequirement {
        doc
        ---
        The control module shall maintain patient body temperature within the specified tolerance of the clinician-set target temperature using a feedback loop from heater output and patient body temperature sensors, automatically adjusting heating element power and blower speed.
        ---
        attribute tolerance : Temperature = 0.5;
    }

    requirement def SafetyMonitoringRequirement {
        doc
        ---
        An independent safety monitor shall continuously check air and patient temperatures against safety thresholds. If a safety threshold is exceeded, the monitor shall trigger an immediate system shutdown to prevent patient injury.
        ---
        attribute maxAirTemp : Temperature = 43;
        attribute maxPatientTemp : Temperature = 38;
    }

    requirement def AirFiltrationRequirement {
        doc
        ---
        All ambient air drawn into the system shall pass through a high-efficiency filter before reaching the heating element and the patient.
        ---
        attribute minEfficiency : Percent = 99.97;
    }

    requirement def StateMachineRequirement {
        doc
        ---
        The system shall operate through states: power off, standby for initialization and self-testing, ready for operation, warming for active warming, and alarm to alert medical staff of any issues.
        ---
    }

    requirement def PowerSupplyRequirement {
        doc
        ---
        The system shall be powered by an internal power supply that converts standard wall outlet power for use by all system components.
        ---
        attribute inputVoltage : Voltage = 120;
        attribute outputVoltage : Voltage = 24;
    }

    // ===== Part Definitions =====

    part def AmbientAirSource {
        doc
        ---
        Represents the ambient air environment surrounding the Bair Hugger system.
        ---
        port airOut : AirOutPort;
        attribute ambientTemp : Temperature = 22;
    }

    part def HighEfficiencyFilter {
        doc
        ---
        High-efficiency particulate air filter that cleans ambient air before it enters the heating and patient pathway.
        ---
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port powerIn : PowerInPort;
        attribute efficiency : Percent = 99.97;
        attribute pressureDrop : Real = 50;
        attribute filterAge : TimeValue = 0;
        attribute needsReplacement : Boolean = false;

        action def filterAir {
            in unfiltered : Air;
            out filtered : FilteredAir;
        }
    }

    part def Blower {
        doc
        ---
        Motorized blower that propels filtered air across the heating element toward the delivery hose.
        ---
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port controlIn : CommandInPort;
        port powerIn : PowerInPort;
        attribute currentSpeed : RotationalSpeed = 3000;
        attribute maxSpeed : RotationalSpeed = 6000;
        attribute minSpeed : RotationalSpeed = 1000;
        attribute currentFlowRate : FlowRate = 15;

        action def regulateSpeed {
            in command : ControlCommand;
            out speed : RotationalSpeed;
        }

        action def propelAir {
            in input : FilteredAir;
            out output : FilteredAir;
        }
    }

    part def HeatingElement {
        doc
        ---
        Electric heating element that warms filtered air to a precise temperature controlled by the control module.
        ---
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port controlIn : CommandInPort;
        port powerIn : PowerInPort;
        attribute currentPower : Power = 500;
        attribute maxPower : Power = 1200;
        attribute outputAirTemp : Temperature = 38;

        action def regulatePower {
            in command : ControlCommand;
            out power : Power;
        }

        action def heatAir {
            in input : FilteredAir;
            out output : HeatedAir;
        }
    }

    part def PowerSupply {
        doc
        ---
        Internal power supply that converts standard wall outlet power for use by all system components.
        ---
        port mainsIn : PowerInPort;
        port componentPower : PowerOutPort;
        attribute inputVoltage : Voltage = 120;
        attribute outputVoltage : Voltage = 24;
        attribute active : Boolean = true;
        attribute maxOutputPower : Power = 1500;

        action def convertPower {
            in input : Voltage;
            out output : Voltage;
        }
    }

    part def UserInterface {
        doc
        ---
        Clinician-facing interface for setting target temperature and viewing system status and alarms.
        ---
        port targetOut : CommandOutPort;
        port alarmIn : AlarmInPort;
        attribute setTargetTemp : Temperature = 37;
        attribute currentDisplayState : String = "off";

        action def setTargetTemperature {
            in target : Temperature;
            out command : ControlCommand;
        }

        action def displayAlarm {
            in alarm : AlarmEvent;
        }
    }

    part def TemperatureSensor {
        doc
        ---
        Generic temperature sensor providing continuous temperature readings to the control and safety subsystems.
        ---
        port dataOut : TempDataOutPort;
        port powerIn : PowerInPort;
        attribute measuredTemp : Temperature = 22;
        attribute isValid : Boolean = true;

        action def measure {
            out reading : TemperatureReading;
        }
    }

    part def HeaterAirTempSensor :> TemperatureSensor {
        doc
        ---
        Temperature sensor measuring the temperature of air leaving the heating element.
        ---
        attribute sensorLocation : String = "heater_outlet";
    }

    part def PatientBodyTempSensor :> TemperatureSensor {
        doc
        ---
        Temperature sensor monitoring the patient body temperature via skin contact.
        ---
        attribute sensorLocation : String = "patient_skin";
        attribute contactType : String = "adhesive_pad";
    }

    part def SafetyMonitor {
        doc
        ---
        Independent safety monitor that continuously checks for dangerous conditions and can trigger immediate system shutdown.
        ---
        port heaterTempIn : TempDataInPort;
        port patientTempIn : TempDataInPort;
        port shutdownCommand : CommandOutPort;
        port alarmOut : AlarmOutPort;
        port powerIn : PowerInPort;
        attribute maxAirTempThreshold : Temperature = 43;
        attribute maxPatientTempThreshold : Temperature = 38;
        attribute independent : Boolean = true;
        attribute alarmActive : Boolean = false;
        attribute currentHeaterAirTemp : Temperature = 22;
        attribute currentPatientTemp : Temperature = 36.5;

        action def monitorConditions {
            in heaterAirTemp : Temperature;
            in patientTemp : Temperature;
            out alarm : AlarmEvent;
        }

        action def triggerShutdown {
            out command : ControlCommand;
        }
    }

    part def ControlModule {
        doc
        ---
        Central control module implementing the feedback loop that maintains the patient at the target temperature by adjusting heater power and blower speed.
        ---
        port uiInput : CommandInPort;
        port heaterTempInput : TempDataInPort;
        port patientTempInput : TempDataInPort;
        port heaterOutput : CommandOutPort;
        port blowerOutput : CommandOutPort;
        port safetyOverride : CommandInPort;
        port powerIn : PowerInPort;
        attribute targetTemp : Temperature = 37;
        attribute currentHeaterTemp : Temperature = 22;
        attribute currentPatientTemp : Temperature = 36.5;
        attribute proportionalGain : Real = 2.0;
        attribute integralGain : Real = 0.5;
        attribute integralError : Real = 0;
        attribute safetyShutdownActive : Boolean = false;

        action def computeControl {
            in target : Temperature;
            in heaterTemp : Temperature;
            in patientTemp : Temperature;
            out command : ControlCommand;
        }

        action def processSafetyOverride {
            in override : ControlCommand;
        }
    }

    part def DeliveryHose {
        doc
        ---
        Flexible hose that transports heated air from the warming unit to the disposable warming blanket.
        ---
        port airIn : AirInPort;
        port airOut : AirOutPort;
        attribute hoseLength : Length = 1.5;
        attribute innerDiameter : Length = 0.08;
        attribute insulationFactor : Real = 0.9;
        attribute isConnected : Boolean = true;
    }

    part def WarmingBlanket {
        doc
        ---
        Disposable warming blanket with a specific perforation pattern designed to distribute warm air evenly over the patient body.
        ---
        port airIn : AirInPort;
        attribute perforationPattern : String = "evenly_distributed";
        attribute surfaceArea : Area = 1.5;
        attribute numPerforations : Integer = 200;
        attribute isDisposable : Boolean = true;
        attribute blanketModel : String = "standard_adult";

        action def distributeAir {
            in heated : HeatedAir;
            out distributed : DistributedAir;
        }
    }

    part def Patient {
        doc
        ---
        The patient receiving forced-air warming therapy.
        ---
        attribute bodyTemp : Temperature = 36.5;
        attribute patientId : String;
        attribute weight : Real = 70;
        attribute isUnderCare : Boolean = true;
    }

    // ===== Top-Level System =====

    part def ForcedAirWarmingSystem {
        doc
        ---
        Bair Hugger forced-air warming system: a medical device that prevents and treats hypothermia by delivering temperature-controlled warm air through a disposable blanket placed over the patient.
        ---

        satisfy WarmingSystemRequirement;
        satisfy TemperatureControlRequirement;
        satisfy SafetyMonitoringRequirement;
        satisfy AirFiltrationRequirement;
        satisfy StateMachineRequirement;
        satisfy PowerSupplyRequirement;

        port mainsConnection : PowerInPort;

        part ambientAir : AmbientAirSource;
        part airFilter : HighEfficiencyFilter;
        part blower : Blower;
        part heatingElement : HeatingElement;
        part powerSupply : PowerSupply;
        part userInterface : UserInterface;
        part controller : ControlModule;
        part safetyMonitor : SafetyMonitor;
        part heaterAirSensor : HeaterAirTempSensor;
        part patientSensor : PatientBodyTempSensor;
        part hose : DeliveryHose;
        part blanket : WarmingBlanket;
        part patient : Patient;

        attribute selfTestPassed : Boolean = false;
        attribute warmingRequested : Boolean = false;
        attribute warmingActive : Boolean = false;
        attribute manualResetRequested : Boolean = false;

        constraint heaterOutputSafety {
            heatingElement.outputAirTemp <= safetyMonitor.maxAirTempThreshold
        }

        constraint targetTempRange {
            controller.targetTemp >= 36 and controller.targetTemp <= 39
        }

        constraint patientSafetyLimit {
            patient.bodyTemp <= safetyMonitor.maxPatientTempThreshold
        }

        constraint filterEfficiencyMinimum {
            airFilter.efficiency >= 99.97
        }

        // Air flow connections
        connection ambientToFilter : AirFlow connect ambientAir.airOut to airFilter.airIn;
        connection filterToBlower : AirFlow connect airFilter.airOut to blower.airIn;
        connection blowerToHeater : AirFlow connect blower.airOut to heatingElement.airIn;
        connection heaterToHose : AirFlow connect heatingElement.airOut to hose.airIn;
        connection hoseToBlanket : AirFlow connect hose.airOut to blanket.airIn;

        // Control connections
        connection uiToController : ControlLink connect userInterface.targetOut to controller.uiInput;
        connection controllerToHeater : ControlLink connect controller.heaterOutput to heatingElement.controlIn;
        connection controllerToBlower : ControlLink connect controller.blowerOutput to blower.controlIn;
        connection safetyToController : ControlLink connect safetyMonitor.shutdownCommand to controller.safetyOverride;

        // Temperature data connections
        connection heaterTempToController : TempLink connect heaterAirSensor.dataOut to controller.heaterTempInput;
        connection patientTempToController : TempLink connect patientSensor.dataOut to controller.patientTempInput;
        connection heaterTempToSafety : TempLink connect heaterAirSensor.dataOut to safetyMonitor.heaterTempIn;
        connection patientTempToSafety : TempLink connect patientSensor.dataOut to safetyMonitor.patientTempIn;

        // Alarm connection
        connection safetyAlarmToUI : AlarmLink connect safetyMonitor.alarmOut to userInterface.alarmIn;

        // Power connections
        connection mainsToPSU connect mainsConnection to powerSupply.mainsIn;
        connection psuToFilter : PowerLink connect powerSupply.componentPower to airFilter.powerIn;
        connection psuToBlower : PowerLink connect powerSupply.componentPower to blower.powerIn;
        connection psuToHeater : PowerLink connect powerSupply.componentPower to heatingElement.powerIn;
        connection psuToController : PowerLink connect powerSupply.componentPower to controller.powerIn;
        connection psuToSafety : PowerLink connect powerSupply.componentPower to safetyMonitor.powerIn;
        connection psuToHeaterSensor : PowerLink connect powerSupply.componentPower to heaterAirSensor.powerIn;
        connection psuToPatientSensor : PowerLink connect powerSupply.componentPower to patientSensor.powerIn;

        // State machine
        state systemStates {
            state PowerOff {
                entry action {
                    powerSupply.active = false;
                }
            }

            state Standby {
                entry action {
                    selfTestPassed = false;
                }
                do action {
                    safetyMonitor.monitorConditions;
                }
            }

            state Ready {
                entry action {
                    warmingRequested = false;
                }
            }

            state Warming {
                entry action {
                    warmingActive = true;
                }
                do action {
                    controller.computeControl;
                    blower.regulateSpeed;
                    heatingElement.regulatePower;
                    safetyMonitor.monitorConditions;
                }
                exit action {
                    warmingActive = false;
                }
            }

            state Alarm {
                entry action {
                    safetyMonitor.triggerShutdown;
                    userInterface.displayAlarm;
                }
            }

            transition from PowerOff to Standby when powerSupply.active;
            transition from Standby to Ready when selfTestPassed;
            transition from Standby to Alarm when safetyMonitor.alarmActive;
            transition from Ready to Warming when warmingRequested;
            transition from Warming to Ready when !warmingActive;
            transition from Warming to Alarm when safetyMonitor.alarmActive;
            transition from Ready to Alarm when safetyMonitor.alarmActive;
            transition from Alarm to PowerOff when manualResetRequested;
        }
    }
}
