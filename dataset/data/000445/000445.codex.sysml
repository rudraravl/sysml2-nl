package EAT_SET_System_Model {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    value type MassValue :> Real {
        unit = kg;
    }

    value type LengthValue :> Real {
        unit = m;
    }

    value type TimeValue :> Real {
        unit = s;
    }

    value type TemperatureValue :> Real {
        unit = K;
    }

    value type PressureValue :> Real {
        unit = Pa;
    }

    value type PowerValue :> Real {
        unit = W;
    }

    value type EnergyValue :> Real {
        unit = J;
    }

    value type VoltageValue :> Real {
        unit = V;
    }

    value type DataRateValue :> Real {
        unit = bit / s;
    }

    value type PercentValue :> Real {
        unit = one;
    }

    enum def PatientAcuity {
        low;
        moderate;
        severe;
        critical;
    }

    enum def SystemMode {
        off;
        standby;
        assess;
        triage;
        stabilize;
        evacuate;
        handoff;
        fault;
    }

    enum def FaultSeverity {
        advisory;
        degraded;
        missionAbort;
    }

    item def IncidentRequest {
        attribute incidentId : String;
        attribute locationLatitude : Real;
        attribute locationLongitude : Real;
        attribute estimatedPatients : Integer;
        attribute requestedResponseTime : TimeValue;
    }

    item def PatientIdentity {
        attribute temporaryId : String;
        attribute estimatedAgeYears : Real;
        attribute massEstimate : MassValue;
    }

    item def VitalSigns {
        attribute heartRate : Real;
        attribute respiratoryRate : Real;
        attribute systolicBloodPressure : PressureValue;
        attribute diastolicBloodPressure : PressureValue;
        attribute bloodOxygenSaturation : PercentValue;
        attribute bodyTemperature : TemperatureValue;
        attribute consciousnessScore : Real;
    }

    item def InjuryAssessment {
        attribute bleedingDetected : Boolean;
        attribute airwayCompromised : Boolean;
        attribute mobilityImpaired : Boolean;
        attribute acuity : PatientAcuity;
        attribute confidence : PercentValue;
    }

    item def StabilizationCommand {
        attribute oxygenFlowEnabled : Boolean;
        attribute pressureBandageRequired : Boolean;
        attribute warmingRequired : Boolean;
        attribute immobilizationRequired : Boolean;
    }

    item def EvacuationOrder {
        attribute destinationFacilityId : String;
        attribute priority : PatientAcuity;
        attribute routeId : String;
        attribute maximumTransportTime : TimeValue;
    }

    item def HandoffRecord {
        attribute patientId : String;
        attribute finalAcuity : PatientAcuity;
        attribute treatmentSummary : String;
        attribute timestamp : TimeValue;
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute availablePower : PowerValue;
    }

    item def ThermalCondition {
        attribute internalTemperature : TemperatureValue;
        attribute patientCompartmentTemperature : TemperatureValue;
    }

    item def DiagnosticReport {
        attribute activeFault : Boolean;
        attribute severity : FaultSeverity;
        attribute message : String;
    }

    port def IncidentCommandPort {
        in item request : IncidentRequest;
        out item handoff : HandoffRecord;
        out item diagnostic : DiagnosticReport;
    }

    port def PatientCarePort {
        in item patientIdentity : PatientIdentity;
        inout item vitals : VitalSigns;
        out item treatment : StabilizationCommand;
    }

    port def EvacuationCoordinationPort {
        in item order : EvacuationOrder;
        out item handoffRecord : HandoffRecord;
    }

    port def PowerPort {
        inout item power : ElectricalPower;
    }

    port def ThermalPort {
        inout item condition : ThermalCondition;
    }

    part def PowerSubsystem {
        attribute batteryCapacity : EnergyValue = 3600000;
        attribute nominalBusVoltage : VoltageValue = 48;
        attribute maximumContinuousPower : PowerValue = 1200;
        attribute stateOfCharge : PercentValue;

        port bus : PowerPort;
    }

    part def SensorSubsystem {
        attribute vitalSamplePeriod : TimeValue = 2;
        attribute minimumOxygenAccuracy : PercentValue = 0.02;
        attribute bloodPressureAccuracy : PressureValue = 400;

        port patient : PatientCarePort;
        port power : PowerPort;
    }

    part def TriageProcessor {
        attribute processorPowerDraw : PowerValue = 45;
        attribute minimumClassificationConfidence : PercentValue = 0.85;
        attribute maximumAssessmentLatency : TimeValue = 10;

        port patient : PatientCarePort;
        port command : IncidentCommandPort;
        port power : PowerPort;
    }

    part def StabilizationSubsystem {
        attribute oxygenReservoirCapacity : Real = 680;
        attribute thermalBlanketPower : PowerValue = 90;
        attribute hemorrhageControlResponseTime : TimeValue = 30;

        port patient : PatientCarePort;
        port power : PowerPort;
        port thermal : ThermalPort;
    }

    part def EvacuationSubsystem {
        attribute payloadCapacity : MassValue = 160;
        attribute maximumRange : LengthValue = 5000;
        attribute cruiseSpeed : Real = 1.8;
        attribute maximumSlopeGrade : PercentValue = 0.12;

        port evacuation : EvacuationCoordinationPort;
        port power : PowerPort;
    }

    part def ThermalManagementSubsystem {
        attribute minimumCompartmentTemperature : TemperatureValue = 291;
        attribute maximumCompartmentTemperature : TemperatureValue = 303;
        attribute heatRejectionCapacity : PowerValue = 250;

        port thermal : ThermalPort;
        port power : PowerPort;
    }

    part def CommunicationsSubsystem {
        attribute commandLinkDataRate : DataRateValue = 1000000;
        attribute medicalRecordLinkDataRate : DataRateValue = 250000;
        attribute maximumLinkLatency : TimeValue = 5;

        port command : IncidentCommandPort;
        port evacuation : EvacuationCoordinationPort;
        port power : PowerPort;
    }

    part def EAT_SET {
        doc /* Emergency Assessment, Triage, Stabilization, and Evacuation Transport system. Its primary function is to receive an incident request, assess a patient, assign acuity, perform immediate stabilization, and coordinate evacuation handoff. */

        attribute operatingMode : SystemMode;
        attribute curbMass : MassValue = 92;
        attribute deploymentTime : TimeValue;
        attribute missionEndurance : TimeValue = 7200;

        port incidentCommand : IncidentCommandPort;
        port patientInterface : PatientCarePort;
        port evacuationInterface : EvacuationCoordinationPort;

        part powerSubsystem : PowerSubsystem;
        part sensorSubsystem : SensorSubsystem;
        part triageProcessor : TriageProcessor;
        part stabilizationSubsystem : StabilizationSubsystem;
        part evacuationSubsystem : EvacuationSubsystem;
        part thermalManagementSubsystem : ThermalManagementSubsystem;
        part communicationsSubsystem : CommunicationsSubsystem;

        connect powerSubsystem.bus to sensorSubsystem.power;
        connect powerSubsystem.bus to triageProcessor.power;
        connect powerSubsystem.bus to stabilizationSubsystem.power;
        connect powerSubsystem.bus to evacuationSubsystem.power;
        connect powerSubsystem.bus to thermalManagementSubsystem.power;
        connect powerSubsystem.bus to communicationsSubsystem.power;

        connect patientInterface to sensorSubsystem.patient;
        connect sensorSubsystem.patient to triageProcessor.patient;
        connect triageProcessor.patient to stabilizationSubsystem.patient;

        connect incidentCommand to communicationsSubsystem.command;
        connect communicationsSubsystem.command to triageProcessor.command;

        connect evacuationInterface to communicationsSubsystem.evacuation;
        connect communicationsSubsystem.evacuation to evacuationSubsystem.evacuation;

        connect stabilizationSubsystem.thermal to thermalManagementSubsystem.thermal;
    }

    action def AssessPatient {
        in item identity : PatientIdentity;
        in item measuredVitals : VitalSigns;
        out item assessment : InjuryAssessment;
    }

    action def ClassifyAcuity {
        in item assessment : InjuryAssessment;
        out item acuity : PatientAcuity;
    }

    action def GenerateStabilizationCommand {
        in item assessment : InjuryAssessment;
        out item command : StabilizationCommand;
    }

    action def StabilizePatient {
        in item command : StabilizationCommand;
        inout item vitals : VitalSigns;
        out item stabilizedVitals : VitalSigns;
    }

    action def CoordinateEvacuation {
        in item request : IncidentRequest;
        in item acuity : PatientAcuity;
        out item order : EvacuationOrder;
    }

    action def ProduceHandoffRecord {
        in item identity : PatientIdentity;
        in item acuity : PatientAcuity;
        in item vitals : VitalSigns;
        out item record : HandoffRecord;
    }

    action def ExecutePrimaryEATSETFunction {
        in item request : IncidentRequest;
        in item patientIdentity : PatientIdentity;
        in item initialVitals : VitalSigns;
        out item evacuationOrder : EvacuationOrder;
        out item handoffRecord : HandoffRecord;

        action assess : AssessPatient {
            in item identity = patientIdentity;
            in item measuredVitals = initialVitals;
        }

        action classify : ClassifyAcuity {
            in item assessment = assess.assessment;
        }

        action commandTreatment : GenerateStabilizationCommand {
            in item assessment = assess.assessment;
        }

        action stabilize : StabilizePatient {
            in item command = commandTreatment.command;
            inout item vitals = initialVitals;
        }

        action evacuate : CoordinateEvacuation {
            in item request = request;
            in item acuity = classify.acuity;
        }

        action handoff : ProduceHandoffRecord {
            in item identity = patientIdentity;
            in item acuity = classify.acuity;
            in item vitals = stabilize.stabilizedVitals;
        }

        bind evacuationOrder = evacuate.order;
        bind handoffRecord = handoff.record;
    }

    state def EAT_SET_OperationalStates {
        entry action initializeDiagnostics;

        state Off;
        state Standby;
        state Assessing;
        state Triaging;
        state Stabilizing;
        state Evacuating;
        state Handoff;
        state FaultManagement;

        transition initial then Off;
        transition Off_to_Standby
            first Off
            accept IncidentRequest
            then Standby;

        transition Standby_to_Assessing
            first Standby
            if powerAvailable
            then Assessing;

        transition Assessing_to_Triaging
            first Assessing
            if vitalSignsComplete
            then Triaging;

        transition Triaging_to_Stabilizing
            first Triaging
            if acuityAssigned
            then Stabilizing;

        transition Stabilizing_to_Evacuating
            first Stabilizing
            if immediateThreatControlled
            then Evacuating;

        transition Evacuating_to_Handoff
            first Evacuating
            if destinationReached
            then Handoff;

        transition Handoff_to_Standby
            first Handoff
            if handoffRecordAccepted
            then Standby;

        transition Any_to_Fault
            first Off, Standby, Assessing, Triaging, Stabilizing, Evacuating, Handoff
            if criticalFaultDetected
            then FaultManagement;

        transition Fault_to_Standby
            first FaultManagement
            if faultCleared
            then Standby;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : EAT_SET;
        doc /* The system shall assess, triage, stabilize, and coordinate evacuation for an incident patient from a single incident request. */
        require constraint {
            system.missionEndurance >= 7200 [s]
        }
    }

    requirement def AssessmentLatencyRequirement {
        subject processor : TriageProcessor;
        doc /* The system shall complete patient assessment and acuity classification within 10 seconds after valid vital signs are available. */
        require constraint {
            processor.maximumAssessmentLatency <= 10 [s]
        }
    }

    requirement def StabilizationResponseRequirement {
        subject stabilization : StabilizationSubsystem;
        doc /* The system shall initiate hemorrhage control, warming, oxygen support, or immobilization within 30 seconds after triage command generation. */
        require constraint {
            stabilization.hemorrhageControlResponseTime <= 30 [s]
        }
    }

    requirement def EvacuationPayloadRequirement {
        subject evacuation : EvacuationSubsystem;
        doc /* The evacuation subsystem shall transport a patient and attached stabilization equipment with total payload mass up to 160 kg. */
        require constraint {
            evacuation.payloadCapacity >= 160 [kg]
        }
    }

    requirement def PatientThermalSafetyRequirement {
        subject thermal : ThermalManagementSubsystem;
        doc /* The patient compartment shall be maintained between 291 K and 303 K during stabilization and evacuation. */
        require constraint {
            thermal.minimumCompartmentTemperature >= 291 [K] and
            thermal.maximumCompartmentTemperature <= 303 [K]
        }
    }

    requirement def CommunicationsLatencyRequirement {
        subject communications : CommunicationsSubsystem;
        doc /* The command and handoff data link shall support transmission of incident requests, evacuation orders, diagnostics, and handoff records with no more than 5 seconds latency. */
        require constraint {
            communications.maximumLinkLatency <= 5 [s]
        }
    }

    part eatSetSystem : EAT_SET;

    satisfy PrimaryFunctionRequirement by eatSetSystem;
    satisfy AssessmentLatencyRequirement by eatSetSystem.triageProcessor;
    satisfy StabilizationResponseRequirement by eatSetSystem.stabilizationSubsystem;
    satisfy EvacuationPayloadRequirement by eatSetSystem.evacuationSubsystem;
    satisfy PatientThermalSafetyRequirement by eatSetSystem.thermalManagementSubsystem;
    satisfy CommunicationsLatencyRequirement by eatSetSystem.communicationsSubsystem;
}