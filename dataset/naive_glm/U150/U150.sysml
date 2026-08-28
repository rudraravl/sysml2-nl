package AtelectotraumaPreventionVentilator {
    import ScalarValues::*;
    import ISQ::*;

    // ─── Value Types with Units ───
    value def PressureValue :> Real {
        unit 'cmH2O';
        attribute min : PressureValue = 0.0;
        attribute max : PressureValue = 100.0;
    }

    value def VolumeValue :> Real {
        unit 'mL';
        attribute min : VolumeValue = 0.0;
        attribute max : VolumeValue = 2000.0;
    }

    value def FlowValue :> Real {
        unit 'L/min';
    }

    value def FractionValue :> Real {
        unit '1';
        attribute min : FractionValue = 0.21;
        attribute max : FractionValue = 1.0;
    }

    value def FrequencyValue :> Real {
        unit 'breaths/min';
    }

    value def DurationValue :> Real {
        unit 's';
    }

    value def StabilityIndex :> Real {
        unit '1';
        attribute collapseThreshold : StabilityIndex = 0.7;
    }

    value def RiskLevel :> Real {
        unit '1';
        attribute lowRisk : RiskLevel = 0.3;
        attribute highRisk : RiskLevel = 0.7;
    }

    // ─── Item Definitions ───
    item def GasMixture {
        attribute oxygenFraction : FractionValue = 0.21;
        attribute totalFlow : FlowValue;
        attribute pressure : PressureValue;
    }

    item def PressureReading {
        attribute airwayPressure : PressureValue;
        attribute plateauPressure : PressureValue;
        attribute peepPressure : PressureValue;
        attribute timestamp : DurationValue;
    }

    item def VolumeReading {
        attribute tidalVolume : VolumeValue;
        attribute minuteVolume : VolumeValue;
        attribute timestamp : DurationValue;
    }

    item def VentilatorCommand {
        attribute targetPEEP : PressureValue;
        attribute targetFlow : FlowValue;
        attribute targetOxygenFraction : FractionValue;
        attribute inspirationTime : DurationValue;
        attribute expirationTime : DurationValue;
    }

    item def AlarmEvent {
        attribute alarmType : String;
        attribute severity : String;
        attribute description : String;
        attribute timestamp : DurationValue;
    }

    item def LungMechanicsData {
        attribute compliance : Real;
        attribute resistance : Real;
        attribute recruitmentLevel : Real;
        attribute stabilityIndex : StabilityIndex;
        attribute riskLevel : RiskLevel;
    }

    // ─── Port Definitions ───
    port def PressureDataPort {
        out pressureReading : PressureReading;
    }

    port def VolumeDataPort {
        out volumeReading : VolumeReading;
    }

    port def CommandOutputPort {
        out command : VentilatorCommand;
    }

    port def CommandInputPort {
        in command : VentilatorCommand;
    }

    port def GasOutputPort {
        out deliveredGas : GasMixture;
    }

    port def GasInputPort {
        in deliveredGas : GasMixture;
    }

    port def AlarmOutputPort {
        out alarmEvent : AlarmEvent;
    }

    port def AlarmInputPort {
        in alarmEvent : AlarmEvent;
    }

    // ─── Requirements ───
    requirement def PreventAtelectotrauma {
        doc {
            The ventilator shall prevent atelectotrauma by maintaining alveolar
            recruitment through adaptive PEEP management that responds to real-time
            lung mechanics data.
        }
        attribute maxCollapseEvents : Integer = 0;
        attribute minRecruitmentLevel : Real = 0.85;
        objective {
            /* Alveolar collapse events per hour shall not exceed maxCollapseEvents
               and alveolar recruitment shall remain above minRecruitmentLevel. */
        }
    }

    requirement def ClosedLoopFeedbackControl {
        doc {
            The control processor shall implement closed-loop feedback control
            using continuous pressure and volume sensor data to dynamically
            adjust PEEP and gas delivery.
        }
        attribute maxResponseTime : DurationValue = 0.5;
        attribute minSamplingRate : FrequencyValue = 100.0;
        objective {
            /* PEEP adjustment shall occur within maxResponseTime of detecting
               instability, and sensors shall sample at minSamplingRate. */
        }
    }

    requirement def SafetyLimitsRequirement {
        doc {
            The system shall operate within defined pressure and volume limits
            to prevent barotrauma, volutrauma, and other forms of lung injury.
        }
        attribute maxAirwayPressure : PressureValue = 40.0;
        attribute maxPlateauPressure : PressureValue = 30.0;
        attribute minPEEP : PressureValue = 5.0;
        attribute maxPEEP : PressureValue = 20.0;
        attribute maxTidalVolumePerKg : VolumeValue = 8.0;
        attribute maxMinuteVolume : VolumeValue = 15.0;
        objective {
            /* Airway pressure shall not exceed maxAirwayPressure, plateau pressure
               shall not exceed maxPlateauPressure, PEEP shall remain between
               minPEEP and maxPEEP, and tidal volume shall not exceed
               maxTidalVolumePerKg per kilogram of patient body weight. */
        }
    }

    requirement def AlarmSystemRequirement {
        doc {
            The system shall immediately alert medical staff when atelectotrauma
            risk is high or when critical parameters exceed safe ranges.
        }
        attribute maxAlarmLatency : DurationValue = 2.0;
        attribute alarmTypes : String = "HighPressure, LowPEEP, HighRisk, SensorFault, Apnea";
        objective {
            /* Alarm shall activate within maxAlarmLatency of detecting an
               unsafe condition. */
        }
    }

    requirement def BreathingCycleRequirement {
        doc {
            The ventilator shall operate through distinct states in the breathing
            cycle: inspiration, expiration, and PEEP maintenance.
        }
        attribute inspirationDuration : DurationValue = 1.0;
        attribute expirationDuration : DurationValue = 2.0;
        attribute peepMaintenanceDuration : DurationValue = 0.5;
        objective {
            /* Each breathing cycle shall include all three phases with durations
               appropriate to patient condition. */
        }
    }

    // ─── Part Definitions ───

    part def PressureSensor {
        port pressureOut : PressureDataPort;
        attribute samplingRate : FrequencyValue = 100.0;
        attribute measurementRange : PressureValue = 0.0 to 100.0;
        attribute accuracy : PressureValue = 0.5;
        attribute isCalibrated : Boolean = true;

        action def measurePressure :> Action {
            in sensorInput : PressureValue;
            out reading : PressureReading;
        }

        perform measurePressure;
    }

    part def VolumeSensor {
        port volumeOut : VolumeDataPort;
        attribute samplingRate : FrequencyValue = 100.0;
        attribute measurementRange : VolumeValue = 0.0 to 2000.0;
        attribute accuracy : VolumeValue = 10.0;
        attribute isCalibrated : Boolean = true;

        action def measureVolume :> Action {
            in sensorInput : VolumeValue;
            out reading : VolumeReading;
        }

        perform measureVolume;
    }

    part def ControlProcessor {
        port pressureIn : PressureDataPort;
        port volumeIn : VolumeDataPort;
        port commandOut : CommandOutputPort;
        port alarmOut : AlarmOutputPort;

        attribute currentPEEP : PressureValue = 5.0;
        attribute targetPEEP : PressureValue = 5.0;
        attribute currentFlow : FlowValue = 30.0;
        attribute currentOxygenFraction : FractionValue = 0.40;
        attribute alveolarStabilityIndex : StabilityIndex = 1.0;
        attribute atelectotraumaRisk : RiskLevel = 0.0;
        attribute lungMechanics : LungMechanicsData;

        // Safety limit attributes
        attribute maxAirwayPressure : PressureValue = 40.0;
        attribute maxPlateauPressure : PressureValue = 30.0;
        attribute minPEEPLimit : PressureValue = 5.0;
        attribute maxPEEPLimit : PressureValue = 20.0;
        attribute maxTidalVolume : VolumeValue = 500.0;
        attribute maxMinuteVolume : VolumeValue = 15.0;

        action def analyzeAlveolarStability :> Action {
            in pressureReading : PressureReading;
            in volumeReading : VolumeReading;
            out stabilityIndex : StabilityIndex;
            out riskLevel : RiskLevel;
            out mechanics : LungMechanicsData;
        }

        action def calculateOptimalPEEP :> Action {
            in stabilityIndex : StabilityIndex;
            in currentPEEP : PressureValue;
            in pressureReading : PressureReading;
            out newPEEP : PressureValue;
        }

        action def generateVentilatorCommand :> Action {
            in targetPEEP : PressureValue;
            in targetFlow : FlowValue;
            in oxygenFraction : FractionValue;
            out command : VentilatorCommand;
        }

        action def evaluateSafety :> Action {
            in pressureReading : PressureReading;
            in volumeReading : VolumeReading;
            in riskLevel : RiskLevel;
            out alarmNeeded : Boolean;
            out alarmEvent : AlarmEvent;
        }

        state machine def ControlLoop {
            entry {
                /* Initialize control processor and set default PEEP. */
            }

            state Monitoring {
                doc {
                    Continuously read sensor data and analyze alveolar stability.
                }
                entry {
                    /* Read pressure and volume sensors. */
                }
                do {
                    analyzeAlveolarStability;
                }
                transition to Evaluating
                    when { pressureReading.received and volumeReading.received };
            }

            state Evaluating {
                doc {
                    Evaluate alveolar stability and determine if PEEP adjustment
                    is needed.
                }
                do {
                    calculateOptimalPEEP;
                    evaluateSafety;
                }
                transition to Commanding
                    when { alveolarStabilityIndex < 0.7 or atelectotraumaRisk > 0.7 };
                transition to Monitoring
                    when { alveolarStabilityIndex >= 0.7 and atelectotraumaRisk <= 0.3 };
                transition to AlarmState
                    when { alarmNeeded == true };
            }

            state Commanding {
                doc {
                    Generate and send new ventilator commands to the gas
                    delivery unit.
                }
                do {
                    generateVentilatorCommand;
                }
                transition to Monitoring
                    when { command.sent };
            }

            state AlarmState {
                doc {
                    Emit alarm event and await acknowledgment.
                }
                entry {
                    /* Send alarm event to alarm system. */
                }
                transition to Monitoring
                    when { alarmAcknowledged };
            }
        }

        perform ControlLoop;
    }

    part def GasDeliveryUnit {
        port commandIn : CommandInputPort;
        port gasOut : GasOutputPort;

        attribute currentFlow : FlowValue = 30.0;
        attribute currentOxygenFraction : FractionValue = 0.40;
        attribute currentPEEP : PressureValue = 5.0;
        attribute inspiratoryValveOpen : Boolean = false;
        attribute expiratoryValveOpen : Boolean = true;
        attribute maxFlow : FlowValue = 120.0;

        action def adjustGasDelivery :> Action {
            in command : VentilatorCommand;
            out gas : GasMixture;
        }

        action def deliverInspiratoryGas :> Action {
            in gas : GasMixture;
        }

        action def maintainPEEP :> Action {
            in targetPEEP : PressureValue;
            out gas : GasMixture;
        }

        action def allowExpiration :> Action {
            out gas : GasMixture;
        }

        state machine def DeliveryControl {
            state Idle {
                entry {
                    /* Wait for command from control processor. */
                }
                transition to Adjusting
                    when { command.received };
            }

            state Adjusting {
                do {
                    adjustGasDelivery;
                }
                transition to Idle
                    when { gas.delivered };
            }
        }

        perform DeliveryControl;
    }

    part def AlarmSystem {
        port alarmIn : AlarmInputPort;
        port alarmOut : AlarmOutputPort;

        attribute activeAlarms : AlarmEvent[0..*];
        attribute alarmEnabled : Boolean = true;
        attribute visualAlarmActive : Boolean = false;
        attribute auditoryAlarmActive : Boolean = false;
        attribute maxAlarmLatency : DurationValue = 2.0;

        action def triggerAlarm :> Action {
            in event : AlarmEvent;
            out visualAlarm : Boolean;
            out auditoryAlarm : Boolean;
        }

        action def clearAlarm :> Action {
            in event : AlarmEvent;
        }

        action def escalateAlarm :> Action {
            in event : AlarmEvent;
            out escalatedEvent : AlarmEvent;
        }

        state machine def AlarmManagement {
            state NoAlarm {
                transition to AlarmTriggered
                    when { alarmEvent.received };
            }

            state AlarmTriggered {
                entry {
                    triggerAlarm;
                }
                transition to AlarmActive
                    when { visualAlarmActive or auditoryAlarmActive };
            }

            state AlarmActive {
                do {
                    escalateAlarm;
                }
                transition to NoAlarm
                    when { alarmAcknowledged };
            }
        }

        perform AlarmManagement;
    }

    part def PatientInterface {
        port gasIn : GasInputPort;
        port pressureOut : PressureDataPort;
        port volumeOut : VolumeDataPort;

        attribute lungCompliance : Real = 50.0;
        attribute lungResistance : Real = 5.0;
        attribute alveolarRecruitment : Real = 0.90;
        attribute patientWeight : Real = 70.0;
        attribute currentAirwayPressure : PressureValue = 5.0;
        attribute currentTidalVolume : VolumeValue = 0.0;
    }

    part def PowerSupply {
        attribute inputVoltage : Real = 120.0;
        attribute outputVoltage : Real = 24.0;
        attribute batteryBackupMinutes : Real = 120.0;
        attribute isOnBackupPower : Boolean = false;
    }

    part def UserInterface {
        attribute displayActive : Boolean = true;
        attribute currentMode : String = "AdaptivePEEP";
        attribute currentPEEPDisplay : PressureValue;
        attribute currentPressureDisplay : PressureValue;
        attribute currentVolumeDisplay : VolumeValue;
        attribute alarmMessages : String[0..*];
    }

    // ─── Main Ventilator System ───
    part def Ventilator {
        part controlProcessor : ControlProcessor;
        part pressureSensor : PressureSensor;
        part volumeSensor : VolumeSensor;
        part gasDeliveryUnit : GasDeliveryUnit;
        part alarmSystem : AlarmSystem;
        part patientInterface : PatientInterface;
        part powerSupply : PowerSupply;
        part userInterface : UserInterface;

        // Safety limit attributes at system level
        attribute systemMaxPressure : PressureValue = 40.0;
        attribute systemMaxTidalVolume : VolumeValue = 500.0;
        attribute systemMinPEEP : PressureValue = 5.0;
        attribute systemMaxPEEP : PressureValue = 20.0;

        // Connections forming the closed-loop feedback system
        connection pressureSensorToProcessor connect
            pressureSensor.pressureOut to controlProcessor.pressureIn;

        connection volumeSensorToProcessor connect
            volumeSensor.volumeOut to controlProcessor.volumeIn;

        connection processorToGasDelivery connect
            controlProcessor.commandOut to gasDeliveryUnit.commandIn;

        connection gasDeliveryToPatient connect
            gasDeliveryUnit.gasOut to patientInterface.gasIn;

        connection patientToPressureSensor connect
            patientInterface.pressureOut to pressureSensor.pressureOut;

        connection patientToVolumeSensor connect
            patientInterface.volumeOut to volumeSensor.volumeOut;

        connection processorToAlarm connect
            controlProcessor.alarmOut to alarmSystem.alarmIn;

        // Breathing cycle state machine
        state machine def BreathingCycle {
            doc {
                The ventilator breathing cycle consists of three distinct phases:
                inspiration, expiration, and PEEP maintenance. The PEEP maintenance
                phase is critical for preventing alveolar collapse between breaths.
            }

            attribute inspirationDuration : DurationValue = 1.0;
            attribute expirationDuration : DurationValue = 2.0;
            attribute peepMaintenanceDuration : DurationValue = 0.5;
            attribute respiratoryRate : FrequencyValue = 20.0;
            attribute ieRatio : Real = 1.0 / 2.0;

            state Inspiration {
                doc {
                    Delivering a breath to the patient. Gas flows from the
                    delivery unit through the patient interface into the lungs.
                }
                entry {
                    /* Open inspiratory valve, close expiratory valve.
                       Begin gas delivery at target flow. */
                }
                do {
                    gasDeliveryUnit.deliverInspiratoryGas;
                }
                exit {
                    /* Close inspiratory valve. */
                }
                transition to Expiration
                    when { currentTidalVolume >= maxTidalVolume or inspirationTime >= inspirationDuration };
            }

            state Expiration {
                doc {
                    Allowing passive exhalation. Expiratory valve is open to
                    permit gas to exit the lungs.
                }
                entry {
                    /* Open expiratory valve for passive exhalation. */
                }
                do {
                    gasDeliveryUnit.allowExpiration;
                }
                transition to PEEDMaintenance
                    when { expirationTime >= expirationDuration };
            }

            state PEEDMaintenance {
                doc {
                    PEEP maintenance phase. The system holds a minimum pressure
                    in the airway to keep alveoli open and prevent collapse.
                    This is the critical anti-atelectotrauma phase.
                }
                entry {
                    /* Adjust expiratory valve to maintain target PEEP. */
                }
                do {
                    gasDeliveryUnit.maintainPEEP;
                    controlProcessor.analyzeAlveolarStability;
                }
                transition to Inspiration
                    when { peepMaintenanceTime >= peepMaintenanceDuration and respiratoryCycleComplete };
            }
        }

        perform BreathingCycle;
    }

    // ─── Requirement Satisfaction ───
    satisfy PreventAtelectotrauma by Ventilator;
    satisfy ClosedLoopFeedbackControl by Ventilator::controlProcessor;
    satisfy SafetyLimitsRequirement by Ventilator;
    satisfy AlarmSystemRequirement by Ventilator::alarmSystem;
    satisfy BreathingCycleRequirement by Ventilator;
}
