package TechnologicalConvergenceSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Percent :> Real {
    unit = "%";
  }

  attribute def WattHour :> Real {
    unit = "W*h";
  }

  attribute def MegabitPerSecond :> Real {
    unit = "Mbit/s";
  }

  attribute def Millisecond :> Real {
    unit = "ms";
  }

  attribute def Kilometer :> Real {
    unit = "km";
  }

  attribute def Celsius :> Real {
    unit = "degC";
  }

  item def VitalSignPacket {
    attribute patientId : String;
    attribute heartRate : Real;
    attribute bloodOxygen : Percent;
    attribute bodyTemperature : Celsius;
    attribute systolicPressure : Real;
    attribute diastolicPressure : Real;
    attribute sampleTime : String;
  }

  item def DiagnosticAssessment {
    attribute patientId : String;
    attribute triageScore : Real;
    attribute riskClass : String;
    attribute recommendedAction : String;
    attribute confidence : Percent;
  }

  item def FlightCommand {
    attribute destinationLatitude : Real;
    attribute destinationLongitude : Real;
    attribute altitude : Real;
    attribute priority : String;
  }

  item def MedicalPayload {
    attribute kitId : String;
    attribute contents : String;
    attribute mass : Real;
    attribute storageTemperature : Celsius;
  }

  item def EncryptedClinicalRecord {
    attribute patientId : String;
    attribute payloadHash : String;
    attribute encryptionScheme : String;
    attribute consentToken : String;
  }

  port def VitalDataPort {
    out item vitalSigns : VitalSignPacket;
  }

  port def DiagnosticPort {
    in item vitalSigns : VitalSignPacket;
    out item assessment : DiagnosticAssessment;
  }

  port def NetworkPort {
    in item uplinkRecord : EncryptedClinicalRecord;
    out item downlinkAssessment : DiagnosticAssessment;
    out item dispatchCommand : FlightCommand;
  }

  port def PayloadPort {
    in item medicalPayload : MedicalPayload;
    out item deliveredPayload : MedicalPayload;
  }

  port def FlightControlPort {
    in item command : FlightCommand;
  }

  part def WearableBiosensor {
    attribute batteryCapacity : WattHour = 12.0;
    attribute sampleInterval : Millisecond = 500.0;
    attribute sensorAccuracy : Percent = 96.5;
    port vitalPort : VitalDataPort;

    action collectVitals {
      out item currentVitals : VitalSignPacket;
    }

    state def BiosensorState {
      state Off;
      state Pairing;
      state Monitoring;
      state LowBattery;
      state Fault;

      transition first Off then Pairing;
      transition Pairing then Monitoring;
      transition Monitoring then LowBattery
        if batteryCapacity < 1.8;
      transition Monitoring then Fault
        if sensorAccuracy < 85.0;
      transition LowBattery then Monitoring
        if batteryCapacity >= 6.0;
    }
  }

  part def EdgeAIDiagnosticNode {
    attribute inferenceLatency : Millisecond = 140.0;
    attribute minimumConfidence : Percent = 88.0;
    attribute modelVersion : String = "cardio-respiratory-triage-4.2";
    port diagnosticPort : DiagnosticPort;

    action inferCondition {
      in item measuredVitals : VitalSignPacket;
      out item assessment : DiagnosticAssessment;
    }

    action anonymizeAndEncrypt {
      in item assessment : DiagnosticAssessment;
      out item record : EncryptedClinicalRecord;
    }

    state def DiagnosticState {
      state Idle;
      state ReceivingVitals;
      state RunningInference;
      state PublishingAssessment;
      state Escalating;

      transition first Idle then ReceivingVitals;
      transition ReceivingVitals then RunningInference;
      transition RunningInference then PublishingAssessment;
      transition RunningInference then Escalating
        if minimumConfidence > 95.0;
      transition PublishingAssessment then Idle;
      transition Escalating then Idle;
    }
  }

  part def FiveGHealthNetwork {
    attribute coverageRadius : Kilometer = 25.0;
    attribute uplinkBandwidth : MegabitPerSecond = 120.0;
    attribute roundTripLatency : Millisecond = 18.0;
    port networkPort : NetworkPort;

    action transmitClinicalRecord {
      in item record : EncryptedClinicalRecord;
    }

    action distributeCareDecision {
      out item assessment : DiagnosticAssessment;
      out item command : FlightCommand;
    }
  }

  part def AutonomousMedicalDrone {
    attribute maximumRange : Kilometer = 18.0;
    attribute cruiseSpeed : Real = 16.0;
    attribute batteryEnergy : WattHour = 620.0;
    attribute payloadCapacity : Real = 2.5;
    port flightPort : FlightControlPort;
    port payloadPort : PayloadPort;

    part navigationComputer {
      attribute positioningAccuracy : Real = 0.4;
      attribute obstacleDetectionRange : Real = 80.0;
    }

    part coldChainBay {
      attribute setPointTemperature : Celsius = 4.0;
      attribute temperatureTolerance : Celsius = 1.5;
    }

    action planRoute {
      in item command : FlightCommand;
    }

    action deliverMedicalPayload {
      in item payload : MedicalPayload;
      out item delivered : MedicalPayload;
    }

    state def DroneMissionState {
      state Docked;
      state LoadingPayload;
      state PlanningRoute;
      state FlyingToPatient;
      state DeliveringPayload;
      state ReturningToBase;
      state Charging;
      state EmergencyLanding;

      transition first Docked then LoadingPayload;
      transition LoadingPayload then PlanningRoute;
      transition PlanningRoute then FlyingToPatient;
      transition FlyingToPatient then DeliveringPayload;
      transition DeliveringPayload then ReturningToBase;
      transition ReturningToBase then Charging;
      transition Charging then Docked;
      transition FlyingToPatient then EmergencyLanding
        if batteryEnergy < 90.0;
    }
  }

  part def ClinicianConsole {
    attribute displayRefreshLatency : Millisecond = 250.0;
    attribute operatorAuthenticated : Boolean = false;
    port consoleNetworkPort : NetworkPort;

    action reviewAssessment {
      in item assessment : DiagnosticAssessment;
    }

    action authorizeDispatch {
      out item command : FlightCommand;
    }
  }

  part def ConvergedRemoteCareSystem {
    attribute primaryFunction : String =
      "Detect patient deterioration, generate AI-assisted triage decisions, and autonomously dispatch medical supplies through a converged cyber-physical healthcare network.";

    part biosensor : WearableBiosensor;
    part aiNode : EdgeAIDiagnosticNode;
    part healthNetwork : FiveGHealthNetwork;
    part drone : AutonomousMedicalDrone;
    part clinicianConsole : ClinicianConsole;

    part emergencyKit : MedicalPayload {
      attribute kitId = "EK-RESP-001";
      attribute contents = "pulse oximeter, bronchodilator, epinephrine auto-injector, sterile dressing, rapid test cartridge";
      attribute mass = 1.7;
      attribute storageTemperature = 4.0;
    }

    connection vitalFlow connect biosensor.vitalPort to aiNode.diagnosticPort;
    connection assessmentFlow connect aiNode.diagnosticPort to healthNetwork.networkPort;
    connection consoleFlow connect healthNetwork.networkPort to clinicianConsole.consoleNetworkPort;
    connection dispatchFlow connect healthNetwork.networkPort to drone.flightPort;
    connection payloadTransfer connect emergencyKit to drone.payloadPort;

    action performRemoteCare {
      first startBiosensing;
      then runEdgeDiagnosis;
      then transmitAssessment;
      then authorizeDroneDispatch;
      then deliverEmergencyKit;

      action startBiosensing {
        out item vitals : VitalSignPacket;
      }

      action runEdgeDiagnosis {
        in item vitals : VitalSignPacket;
        out item assessment : DiagnosticAssessment;
      }

      action transmitAssessment {
        in item assessment : DiagnosticAssessment;
        out item record : EncryptedClinicalRecord;
      }

      action authorizeDroneDispatch {
        in item assessment : DiagnosticAssessment;
        out item command : FlightCommand;
      }

      action deliverEmergencyKit {
        in item command : FlightCommand;
        in item payload : MedicalPayload;
        out item delivered : MedicalPayload;
      }
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : ConvergedRemoteCareSystem;
    doc /* The system shall combine wearable sensing, edge artificial intelligence, high-speed wireless networking, clinician oversight, and autonomous aerial logistics to provide rapid remote triage and medical payload delivery. */
  }

  requirement def LatencyRequirement {
    subject network : FiveGHealthNetwork;
    attribute maxRoundTripLatency : Millisecond = 50.0;
    require constraint { network.roundTripLatency <= maxRoundTripLatency }
  }

  requirement def DiagnosticConfidenceRequirement {
    subject ai : EdgeAIDiagnosticNode;
    attribute minimumAcceptedConfidence : Percent = 88.0;
    require constraint { ai.minimumConfidence >= minimumAcceptedConfidence }
  }

  requirement def DroneRangeRequirement {
    subject drone : AutonomousMedicalDrone;
    attribute requiredOperationalRadius : Kilometer = 15.0;
    require constraint { drone.maximumRange >= requiredOperationalRadius }
  }

  requirement def PayloadCapacityRequirement {
    subject drone : AutonomousMedicalDrone;
    attribute minimumPayloadCapacity : Real = 2.0;
    require constraint { drone.payloadCapacity >= minimumPayloadCapacity }
  }

  requirement def BiosensorSamplingRequirement {
    subject sensor : WearableBiosensor;
    attribute maximumSampleInterval : Millisecond = 1000.0;
    require constraint { sensor.sampleInterval <= maximumSampleInterval }
  }

  requirement def PrivacyRequirement {
    subject system : ConvergedRemoteCareSystem;
    doc /* The system shall transmit clinical information only as encrypted clinical records bound to an explicit consent token. */
  }

  satisfy PrimaryFunctionRequirement by ConvergedRemoteCareSystem;
  satisfy LatencyRequirement by ConvergedRemoteCareSystem.healthNetwork;
  satisfy DiagnosticConfidenceRequirement by ConvergedRemoteCareSystem.aiNode;
  satisfy DroneRangeRequirement by ConvergedRemoteCareSystem.drone;
  satisfy PayloadCapacityRequirement by ConvergedRemoteCareSystem.drone;
  satisfy BiosensorSamplingRequirement by ConvergedRemoteCareSystem.biosensor;
  satisfy PrivacyRequirement by ConvergedRemoteCareSystem;

}