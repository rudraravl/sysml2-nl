package NurseCallButtonSystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    attribute def ElectricPotential :> Real {
        unit = "V";
    }

    attribute def ElectricCurrent :> Real {
        unit = "mA";
    }

    attribute def SoundPressureLevel :> Real {
        unit = "dB";
    }

    attribute def Percentage :> Real {
        unit = "%";
    }

    enum def CallPriority {
        enum normal;
        enum urgent;
        enum cancel;
        enum fault;
    }

    enum def CallStatus {
        enum idle;
        enum pending;
        enum acknowledged;
        enum cleared;
        enum failed;
    }

    enum def IndicatorColor {
        enum off;
        enum amber;
        enum red;
        enum green;
        enum white;
    }

    item def ButtonPress {
        attribute pressDuration : TimeDuration;
        attribute priority : CallPriority;
        attribute patientStationId : String;
    }

    item def CallRequest {
        attribute requestId : String;
        attribute stationId : String;
        attribute bedId : String;
        attribute priority : CallPriority;
        attribute createdAt : String;
    }

    item def CallAcknowledgement {
        attribute requestId : String;
        attribute nurseId : String;
        attribute acknowledgedAt : String;
    }

    item def CallClearance {
        attribute requestId : String;
        attribute clearedBy : String;
        attribute clearedAt : String;
    }

    item def FaultReport {
        attribute stationId : String;
        attribute faultCode : String;
        attribute detectedAt : String;
    }

    port def PatientInputPort {
        in item press : ButtonPress;
    }

    port def CallNetworkPort {
        out item call : CallRequest;
        out item fault : FaultReport;
        in item acknowledgement : CallAcknowledgement;
        in item clearance : CallClearance;
    }

    port def IndicatorPort {
        out attribute visualColor : IndicatorColor;
        out attribute audibleLevel : SoundPressureLevel;
    }

    port def PowerInputPort {
        in attribute supplyVoltage : ElectricPotential;
        in attribute supplyCurrent : ElectricCurrent;
    }

    port def StaffConsolePort {
        in item call : CallRequest;
        in item fault : FaultReport;
        out item acknowledgement : CallAcknowledgement;
        out item clearance : CallClearance;
    }

    action def DetectButtonPress {
        in item patientPress : ButtonPress;
        out item detectedPress : ButtonPress;
    }

    action def CreateCallRequest {
        in item detectedPress : ButtonPress;
        in attribute stationId : String;
        in attribute bedId : String;
        out item request : CallRequest;
    }

    action def TransmitCallRequest {
        in item request : CallRequest;
        out item transmittedRequest : CallRequest;
    }

    action def ActivateLocalIndicators {
        in attribute status : CallStatus;
        in attribute priority : CallPriority;
        out attribute visualColor : IndicatorColor;
        out attribute audibleLevel : SoundPressureLevel;
    }

    action def RegisterAcknowledgement {
        in item acknowledgement : CallAcknowledgement;
        out attribute status : CallStatus;
    }

    action def ClearCall {
        in item clearance : CallClearance;
        out attribute status : CallStatus;
    }

    action def DetectCommunicationFault {
        in attribute elapsedWithoutAck : TimeDuration;
        out item fault : FaultReport;
    }

    state def NurseCallControllerStateMachine {
        attribute status : CallStatus;

        state idle;
        state callPending;
        state callAcknowledged;
        state faulted;

        entry action initialize {
            status = CallStatus::idle;
        }

        transition idle_to_callPending
            first idle
            then callPending
            accept ButtonPress
            do CreateCallRequest;

        transition callPending_to_callAcknowledged
            first callPending
            then callAcknowledged
            accept CallAcknowledgement
            do RegisterAcknowledgement;

        transition callAcknowledged_to_idle
            first callAcknowledged
            then idle
            accept CallClearance
            do ClearCall;

        transition callPending_to_faulted
            first callPending
            then faulted
            accept TimeDuration
            if elapsedWithoutAck > 30.0 [s]
            do DetectCommunicationFault;

        transition faulted_to_idle
            first faulted
            then idle
            accept CallClearance
            do ClearCall;
    }

    part def NurseCallButton {
        attribute stationId : String;
        attribute bedId : String;
        attribute supplyVoltage : ElectricPotential = 24.0 [V];
        attribute standbyCurrent : ElectricCurrent = 20.0 [mA];
        attribute activeCurrent : ElectricCurrent = 75.0 [mA];
        attribute minimumPressDuration : TimeDuration = 0.2 [s];
        attribute callStatus : CallStatus = CallStatus::idle;

        port patientInput : PatientInputPort;
        port network : CallNetworkPort;
        port indicator : IndicatorPort;
        port power : PowerInputPort;

        part actuator {
            attribute requiredActuationForce : Real = 3.0;
            attribute debounceTime : TimeDuration = 0.05 [s];
            port input : PatientInputPort;
        }

        part controller {
            attribute firmwareVersion : String = "2.4.1";
            attribute acknowledgementTimeout : TimeDuration = 30.0 [s];
            perform state NurseCallControllerStateMachine;
        }

        part visualIndicator {
            attribute color : IndicatorColor = IndicatorColor::off;
            attribute flashPeriod : TimeDuration = 1.0 [s];
            port indication : IndicatorPort;
        }

        part audibleIndicator {
            attribute level : SoundPressureLevel = 65.0 [dB];
            attribute enabled : Boolean = false;
            port indication : IndicatorPort;
        }

        part powerConditioner {
            attribute nominalInputVoltage : ElectricPotential = 24.0 [V];
            attribute minimumOperatingVoltage : ElectricPotential = 18.0 [V];
            attribute maximumOperatingVoltage : ElectricPotential = 30.0 [V];
            port inputPower : PowerInputPort;
        }

        flow patientInput.press to actuator.input.press;
        flow power.supplyVoltage to powerConditioner.inputPower.supplyVoltage;
        flow power.supplyCurrent to powerConditioner.inputPower.supplyCurrent;
        flow visualIndicator.indication.visualColor to indicator.visualColor;
        flow audibleIndicator.indication.audibleLevel to indicator.audibleLevel;
    }

    part def NurseStaffConsole {
        attribute consoleId : String;
        attribute activeCallCount : Integer = 0;
        attribute maximumDisplayedCalls : Integer = 64;

        port staffNetwork : StaffConsolePort;

        part callQueue {
            attribute queuedCalls : Integer = 0;
            attribute normalCallEscalationTime : TimeDuration = 120.0 [s];
        }

        part display {
            attribute brightness : Percentage = 80.0 [%];
            attribute alarmColor : IndicatorColor = IndicatorColor::red;
        }

        part acknowledgementControl {
            attribute requiresAuthenticatedNurse : Boolean = true;
        }
    }

    part def FacilityCallNetwork {
        attribute networkId : String;
        attribute maximumLatency : TimeDuration = 2.0 [s];
        attribute availabilityTarget : Percentage = 99.9 [%];

        port buttonSide : CallNetworkPort;
        port consoleSide : StaffConsolePort;

        flow buttonSide.call to consoleSide.call;
        flow buttonSide.fault to consoleSide.fault;
        flow consoleSide.acknowledgement to buttonSide.acknowledgement;
        flow consoleSide.clearance to buttonSide.clearance;
    }

    part def PatientRoomStation {
        attribute roomId : String;
        attribute bedId : String;

        part callButton : NurseCallButton {
            stationId = roomId;
            bedId = bedId;
        }

        part wallPower {
            attribute voltage : ElectricPotential = 24.0 [V];
            attribute availableCurrent : ElectricCurrent = 500.0 [mA];
        }

        port patientInput : PatientInputPort;
        port network : CallNetworkPort;

        flow patientInput.press to callButton.patientInput.press;
        flow wallPower.voltage to callButton.power.supplyVoltage;
        flow wallPower.availableCurrent to callButton.power.supplyCurrent;
        flow callButton.network.call to network.call;
        flow callButton.network.fault to network.fault;
        flow network.acknowledgement to callButton.network.acknowledgement;
        flow network.clearance to callButton.network.clearance;
    }

    part def NurseCallSystem {
        attribute systemName : String = "Patient Nurse Call Button System";
        attribute primaryFunction : String = "Allow a patient to request nurse assistance by pressing a bedside button, transmit the request to staff, provide local confirmation, support acknowledgement, and clear the call after response.";

        part roomStation : PatientRoomStation {
            roomId = "Room-214";
            bedId = "Bed-A";
        }

        part callNetwork : FacilityCallNetwork {
            networkId = "Ward-2-East-Call-Network";
        }

        part nurseConsole : NurseStaffConsole {
            consoleId = "Nurse-Desk-2E";
        }

        connect roomStation.network to callNetwork.buttonSide;
        connect callNetwork.consoleSide to nurseConsole.staffNetwork;
    }

    requirement def PatientAccessibleCallInitiation {
        doc /* The system shall allow a patient at the bedside to initiate a nurse call using a single button press. */
        attribute maximumPressDurationRequired : TimeDuration = 0.2 [s];
        require constraint { maximumPressDurationRequired <= 0.2 [s] }
    }

    requirement def CallTransmissionLatency {
        doc /* The system shall deliver a valid call request from the patient room station to the nurse staff console within two seconds. */
        attribute maximumAllowedLatency : TimeDuration = 2.0 [s];
        require constraint { maximumAllowedLatency <= 2.0 [s] }
    }

    requirement def LocalCallConfirmation {
        doc /* The call button shall provide visible confirmation when a call request is pending or acknowledged. */
        attribute pendingColor : IndicatorColor = IndicatorColor::red;
        attribute acknowledgedColor : IndicatorColor = IndicatorColor::green;
    }

    requirement def StaffAcknowledgement {
        doc /* The nurse staff console shall support acknowledgement of a received call, and the call button shall change state after acknowledgement is received. */
        attribute acknowledgementTimeout : TimeDuration = 30.0 [s];
        require constraint { acknowledgementTimeout <= 30.0 [s] }
    }

    requirement def FaultNotification {
        doc /* The system shall report a communication fault if a pending call is not acknowledged within the configured timeout. */
        attribute faultDetectionTime : TimeDuration = 30.0 [s];
        require constraint { faultDetectionTime <= 30.0 [s] }
    }

    requirement def SafeLowVoltageOperation {
        doc /* The bedside button shall operate from a nominal twenty-four volt low-voltage supply. */
        attribute nominalVoltage : ElectricPotential = 24.0 [V];
        attribute minimumVoltage : ElectricPotential = 18.0 [V];
        attribute maximumVoltage : ElectricPotential = 30.0 [V];
        require constraint { minimumVoltage <= nominalVoltage and nominalVoltage <= maximumVoltage }
    }

    satisfy PatientAccessibleCallInitiation by NurseCallSystem::roomStation::callButton;
    satisfy CallTransmissionLatency by NurseCallSystem::callNetwork;
    satisfy LocalCallConfirmation by NurseCallSystem::roomStation::callButton::visualIndicator;
    satisfy StaffAcknowledgement by NurseCallSystem::nurseConsole;
    satisfy FaultNotification by NurseCallSystem::roomStation::callButton::controller;
    satisfy SafeLowVoltageOperation by NurseCallSystem::roomStation::callButton::powerConditioner;

}