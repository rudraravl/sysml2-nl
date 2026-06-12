package MedicalIndustryModel {
    package SmartInfusionTherapySystem {
        value def Milliliter;
        value def Hour;
        value def Minute;
        value def MilliliterPerHour;
        value def Milligram;
        value def Kilogram;
        value def MilligramPerKilogramHour;
        value def Kilopascal;
        value def Percent;
        value def Volt;
        value def Watt;
        value def Second;
        value def BeatsPerMinute;

        item def MedicationFluid {
            attribute medicationName : String;
            attribute concentration : MilligramPerMilliliter;
            attribute volumeRemaining : Milliliter;
            attribute lotNumber : String;
            attribute expirationTimestamp : String;
        }

        value def MilligramPerMilliliter;

        item def Prescription {
            attribute patientIdentifier : String;
            attribute medicationName : String;
            attribute orderedDoseRate : MilligramPerKilogramHour;
            attribute patientWeight : Kilogram;
            attribute maximumInfusionRate : MilliliterPerHour;
            attribute totalVolumeToInfuse : Milliliter;
            attribute therapyDuration : Hour;
            attribute prescriberIdentifier : String;
        }

        item def InfusionCommand {
            attribute targetFlowRate : MilliliterPerHour;
            attribute targetVolume : Milliliter;
            attribute commandTimestamp : String;
            attribute authorizedBy : String;
        }

        item def FlowMeasurement {
            attribute measuredFlowRate : MilliliterPerHour;
            attribute deliveredVolume : Milliliter;
            attribute samplePeriod : Second;
        }

        item def PressureMeasurement {
            attribute linePressure : Kilopascal;
            attribute pressureTrend : Kilopascal;
        }

        item def AirBubbleMeasurement {
            attribute detectedAirVolume : Milliliter;
            attribute detectionConfidence : Percent;
        }

        item def PatientVitals {
            attribute heartRate : BeatsPerMinute;
            attribute oxygenSaturation : Percent;
            attribute systolicPressure : Kilopascal;
            attribute diastolicPressure : Kilopascal;
        }

        item def AlarmSignal {
            attribute severity : AlarmSeverity;
            attribute alarmCode : String;
            attribute alarmMessage : String;
            attribute alarmTimestamp : String;
        }

        enum def AlarmSeverity {
            enum low;
            enum medium;
            enum high;
            enum critical;
        }

        item def AuditRecord {
            attribute eventIdentifier : String;
            attribute patientIdentifier : String;
            attribute actorIdentifier : String;
            attribute eventDescription : String;
            attribute eventTimestamp : String;
        }

        port def MedicationInletPort {
            in item fluidIn : MedicationFluid;
        }

        port def MedicationOutletPort {
            out item fluidOut : MedicationFluid;
        }

        port def PatientAccessPort {
            in item infusedMedication : MedicationFluid;
            out item patientVitals : PatientVitals;
        }

        port def PrescriptionDataPort {
            in item prescription : Prescription;
        }

        port def CommandDataPort {
            in item command : InfusionCommand;
        }

        port def SensorDataPort {
            out item flow : FlowMeasurement;
            out item pressure : PressureMeasurement;
            out item air : AirBubbleMeasurement;
        }

        port def AlarmPort {
            out item alarm : AlarmSignal;
        }

        port def AuditPort {
            out item auditRecord : AuditRecord;
        }

        port def PowerPort {
            in attribute supplyVoltage : Volt;
            in attribute availablePower : Watt;
        }

        port def NetworkPort {
            in item prescription : Prescription;
            out item auditRecord : AuditRecord;
            out item alarm : AlarmSignal;
        }

        part def SmartInfusionTherapySystem {
            port medicationInlet : MedicationInletPort;
            port patientOutlet : PatientAccessPort;
            port prescriptionInput : PrescriptionDataPort;
            port clinicianCommandInput : CommandDataPort;
            port network : NetworkPort;
            port alarmOutput : AlarmPort;
            port auditOutput : AuditPort;
            port powerInput : PowerPort;

            part reservoir : MedicationReservoir;
            part pump : PrecisionPumpMechanism;
            part flowSensor : FlowSensor;
            part pressureSensor : PressureSensor;
            part airDetector : AirInLineDetector;
            part controller : TherapyController;
            part userInterface : ClinicianUserInterface;
            part alarmManager : AlarmManager;
            part battery : MedicalBackupBattery;
            part networkGateway : HospitalNetworkGateway;
            part patientLine : SterilePatientLine;

            connect medicationInlet.fluidIn to reservoir.medicationIn.fluidIn;
            connect reservoir.medicationOut.fluidOut to pump.medicationIn.fluidIn;
            connect pump.medicationOut.fluidOut to flowSensor.medicationIn.fluidIn;
            connect flowSensor.medicationOut.fluidOut to pressureSensor.medicationIn.fluidIn;
            connect pressureSensor.medicationOut.fluidOut to airDetector.medicationIn.fluidIn;
            connect airDetector.medicationOut.fluidOut to patientLine.medicationIn.fluidIn;
            connect patientLine.patientAccess.infusedMedication to patientOutlet.infusedMedication;

            connect flowSensor.sensorOut.flow to controller.sensorIn.flow;
            connect pressureSensor.sensorOut.pressure to controller.sensorIn.pressure;
            connect airDetector.sensorOut.air to controller.sensorIn.air;

            connect prescriptionInput.prescription to controller.prescriptionIn.prescription;
            connect clinicianCommandInput.command to controller.commandIn.command;
            connect userInterface.commandOut.command to controller.commandIn.command;
            connect network.prescription to networkGateway.network.prescription;
            connect networkGateway.prescriptionOut.prescription to controller.prescriptionIn.prescription;

            connect controller.pumpCommand.command to pump.control.command;
            connect controller.alarmOut.alarm to alarmManager.alarmIn.alarm;
            connect alarmManager.alarmOut.alarm to alarmOutput.alarm;
            connect alarmManager.networkAlarm.alarm to network.alarm;

            connect controller.auditOut.auditRecord to auditOutput.auditRecord;
            connect controller.auditOut.auditRecord to network.auditRecord;

            connect powerInput.supplyVoltage to battery.externalPower.supplyVoltage;
            connect powerInput.availablePower to battery.externalPower.availablePower;
            connect battery.conditionedPower.supplyVoltage to controller.power.supplyVoltage;
            connect battery.conditionedPower.availablePower to pump.power.supplyVoltage;

            perform action deliverMedication : DeliverPrescribedMedication;
            exhibit state lifecycle : InfusionOperatingStateMachine;
        }

        part def MedicationReservoir {
            port medicationIn : MedicationInletPort;
            port medicationOut : MedicationOutletPort;
            attribute capacity : Milliliter;
            attribute currentVolume : Milliliter;
            attribute reservoirLocked : Boolean;
        }

        part def PrecisionPumpMechanism {
            port medicationIn : MedicationInletPort;
            port medicationOut : MedicationOutletPort;
            port control : CommandDataPort;
            port power : PowerPort;
            attribute minimumFlowRate : MilliliterPerHour;
            attribute maximumFlowRate : MilliliterPerHour;
            attribute commandedFlowRate : MilliliterPerHour;
            attribute deliveredVolume : Milliliter;
        }

        part def FlowSensor {
            port medicationIn : MedicationInletPort;
            port medicationOut : MedicationOutletPort;
            port sensorOut : SensorDataPort;
            attribute accuracy : Percent;
            attribute sampleInterval : Second;
        }

        part def PressureSensor {
            port medicationIn : MedicationInletPort;
            port medicationOut : MedicationOutletPort;
            port sensorOut : SensorDataPort;
            attribute occlusionPressureThreshold : Kilopascal;
            attribute sampleInterval : Second;
        }

        part def AirInLineDetector {
            port medicationIn : MedicationInletPort;
            port medicationOut : MedicationOutletPort;
            port sensorOut : SensorDataPort;
            attribute maximumPermittedAirVolume : Milliliter;
            attribute detectionSensitivity : Percent;
        }

        part def SterilePatientLine {
            port medicationIn : MedicationInletPort;
            port patientAccess : PatientAccessPort;
            attribute primedVolume : Milliliter;
            attribute sterileBarrierIntact : Boolean;
        }

        part def TherapyController {
            port prescriptionIn : PrescriptionDataPort;
            port commandIn : CommandDataPort;
            port sensorIn : SensorDataPort;
            port pumpCommand : CommandDataPort;
            port alarmOut : AlarmPort;
            port auditOut : AuditPort;
            port power : PowerPort;

            attribute activePrescription : Prescription;
            attribute calculatedFlowRate : MilliliterPerHour;
            attribute therapyEnabled : Boolean;
            attribute doseError : Percent;
            attribute cumulativeDeliveredVolume : Milliliter;

            perform action validatePrescription : ValidatePrescription;
            perform action calculateInfusionCommand : CalculateInfusionCommand;
            perform action monitorTherapySafety : MonitorTherapySafety;
            perform action recordClinicalEvent : RecordClinicalEvent;
        }

        part def ClinicianUserInterface {
            port commandOut : CommandDataPort;
            port alarmIn : AlarmPort;
            attribute authenticatedClinician : String;
            attribute displayBrightness : Percent;
            attribute touchInputEnabled : Boolean;
        }

        part def AlarmManager {
            port alarmIn : AlarmPort;
            port alarmOut : AlarmPort;
            port networkAlarm : AlarmPort;
            attribute audibleLevel : Percent;
            attribute visualIndicatorActive : Boolean;
            attribute alarmSilencedDuration : Minute;
        }

        part def MedicalBackupBattery {
            port externalPower : PowerPort;
            port conditionedPower : PowerPort;
            attribute stateOfCharge : Percent;
            attribute remainingRuntime : Hour;
            attribute nominalVoltage : Volt;
        }

        part def HospitalNetworkGateway {
            port network : NetworkPort;
            port prescriptionOut : PrescriptionDataPort;
            attribute connectedToElectronicHealthRecord : Boolean;
            attribute encryptedSessionActive : Boolean;
        }

        action def DeliverPrescribedMedication {
            in item prescription : Prescription;
            in item medication : MedicationFluid;
            out item auditRecord : AuditRecord;
            out item alarm : AlarmSignal;

            first start;
            then validate : ValidatePrescription;
            then calculate : CalculateInfusionCommand;
            then prime : PrimePatientLine;
            then infuse : InfuseMedication;
            then monitor : MonitorTherapySafety;
            then complete : CompleteTherapy;
        }

        action def ValidatePrescription {
            in item prescription : Prescription;
            out attribute accepted : Boolean;
            out item auditRecord : AuditRecord;
        }

        action def CalculateInfusionCommand {
            in item prescription : Prescription;
            out item command : InfusionCommand;
        }

        action def PrimePatientLine {
            in item medication : MedicationFluid;
            out attribute linePrimed : Boolean;
        }

        action def InfuseMedication {
            in item command : InfusionCommand;
            out item flowMeasurement : FlowMeasurement;
            out attribute deliveredVolume : Milliliter;
        }

        action def MonitorTherapySafety {
            in item flow : FlowMeasurement;
            in item pressure : PressureMeasurement;
            in item air : AirBubbleMeasurement;
            out item alarm : AlarmSignal;
            out attribute therapySafe : Boolean;
        }

        action def CompleteTherapy {
            out item auditRecord : AuditRecord;
            out attribute pumpStopped : Boolean;
        }

        action def RecordClinicalEvent {
            in item alarm : AlarmSignal;
            out item auditRecord : AuditRecord;
        }

        state def InfusionOperatingStateMachine {
            entry action initializeSystem;
            state off;
            state selfTest;
            state ready;
            state programming;
            state prescriptionValidated;
            state priming;
            state infusing;
            state paused;
            state completed;
            state occlusionAlarm;
            state airInLineAlarm;
            state emptyReservoirAlarm;
            state batteryAlarm;
            state faultSafe;

            transition initial then off;
            transition off_to_selfTest first off accept powerApplied then selfTest;
            transition selfTest_to_ready first selfTest accept selfTestPassed then ready;
            transition selfTest_to_faultSafe first selfTest accept selfTestFailed then faultSafe;
            transition ready_to_programming first ready accept prescriptionReceived then programming;
            transition programming_to_validated first programming accept prescriptionAccepted then prescriptionValidated;
            transition programming_to_ready first programming accept prescriptionRejected then ready;
            transition prescriptionValidated_to_priming first prescriptionValidated accept clinicianStart then priming;
            transition priming_to_infusing first priming accept linePrimed then infusing;
            transition infusing_to_paused first infusing accept clinicianPause then paused;
            transition paused_to_infusing first paused accept clinicianResume then infusing;
            transition infusing_to_completed first infusing accept targetVolumeDelivered then completed;
            transition infusing_to_occlusionAlarm first infusing accept occlusionDetected then occlusionAlarm;
            transition infusing_to_airInLineAlarm first infusing accept airDetected then airInLineAlarm;
            transition infusing_to_emptyReservoirAlarm first infusing accept reservoirEmpty then emptyReservoirAlarm;
            transition infusing_to_batteryAlarm first infusing accept batteryLow then batteryAlarm;
            transition occlusionAlarm_to_paused first occlusionAlarm accept alarmAcknowledged then paused;
            transition airInLineAlarm_to_paused first airInLineAlarm accept alarmAcknowledged then paused;
            transition emptyReservoirAlarm_to_paused first emptyReservoirAlarm accept reservoirReplaced then paused;
            transition batteryAlarm_to_infusing first batteryAlarm accept powerRestored then infusing;
            transition batteryAlarm_to_faultSafe first batteryAlarm accept batteryDepleted then faultSafe;
            transition completed_to_ready first completed accept therapyClosed then ready;
            transition any_to_faultSafe first infusing accept unrecoverableFault then faultSafe;
        }

        requirement def PrimaryFunctionRequirement {
            subject system : SmartInfusionTherapySystem;
            doc /* The system shall deliver prescribed intravenous medication to a patient at a controlled rate while continuously monitoring flow, pressure, air-in-line, power, and therapy status. */
        }

        requirement def PrescriptionValidationRequirement {
            subject controller : TherapyController;
            require constraint {
                controller.therapyEnabled == true implies controller.activePrescription.patientIdentifier != ""
            }
        }

        requirement def FlowAccuracyRequirement {
            subject pump : PrecisionPumpMechanism;
            require constraint {
                pump.commandedFlowRate <= pump.maximumFlowRate
            }
        }

        requirement def OcclusionSafetyRequirement {
            subject pressureSensor : PressureSensor;
            require constraint {
                pressureSensor.occlusionPressureThreshold > 0
            }
        }

        requirement def AirDetectionRequirement {
            subject detector : AirInLineDetector;
            require constraint {
                detector.maximumPermittedAirVolume > 0
            }
        }

        requirement def AuditabilityRequirement {
            subject system : SmartInfusionTherapySystem;
            doc /* The system shall record prescription validation, infusion start, pause, resume, alarm, completion, and fault events as audit records associated with the patient and clinician. */
        }

        requirement def NetworkSecurityRequirement {
            subject gateway : HospitalNetworkGateway;
            require constraint {
                gateway.connectedToElectronicHealthRecord == true implies gateway.encryptedSessionActive == true
            }
        }

        requirement def BackupPowerRequirement {
            subject battery : MedicalBackupBattery;
            require constraint {
                battery.stateOfCharge >= 20
            }
        }
    }
}