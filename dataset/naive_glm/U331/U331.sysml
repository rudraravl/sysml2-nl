package NurseCallSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value type VoltageValue :> Real {
        unit 'V';
    }

    value type CurrentValue :> Real {
        unit 'A';
    }

    value type TimeDuration :> Real {
        unit 's';
    }

    value type RoomNumber :> Integer;
    value type BedNumber :> Integer;
    value type CallId :> Integer;

    enumeration CallStatus {
        inactive;
        active;
        acknowledged;
        cancelled;
    }

    enumeration AlertLevel {
        off;
        dim;
        full;
    }

    // ===== Item Types =====

    item def CallRequest {
        attribute callId : CallId;
        attribute room : RoomNumber;
        attribute bed : BedNumber;
        attribute timestamp : TimeInstant;
        attribute status : CallStatus := CallStatus::inactive;
    }

    item def AcknowledgeSignal {
        attribute callId : CallId;
        attribute room : RoomNumber;
        attribute timestamp : TimeInstant;
    }

    item def CancelSignal {
        attribute callId : CallId;
        attribute room : RoomNumber;
        attribute timestamp : TimeInstant;
    }

    item def AlertControl {
        attribute room : RoomNumber;
        attribute level : AlertLevel;
    }

    item def CallLogEntry {
        attribute callId : CallId;
        attribute room : RoomNumber;
        attribute bed : BedNumber;
        attribute requestTime : TimeInstant;
        attribute acknowledgeTime : TimeInstant[0..1];
        attribute cancelTime : TimeInstant[0..1];
        attribute finalStatus : CallStatus;
    }

    item def NetworkPacket {
        attribute payload : Anything;
        attribute sourceId : String;
        attribute destinationId : String;
        attribute timestamp : TimeInstant;
    }

    // ===== Port Definitions =====

    port def CallOutPort {
        out callRequest : CallRequest;
        in resetSignal : Boolean;
    }

    port def AlertControlPort {
        in alertControl : AlertControl;
    }

    port def StationCallPort {
        in incomingCall : CallRequest;
        out acknowledge : AcknowledgeSignal;
        out cancel : CancelSignal;
    }

    port def ControllerNetworkPort {
        in callRequest : CallRequest;
        in acknowledge : AcknowledgeSignal;
        in cancel : CancelSignal;
        out routedCall : CallRequest;
        out routedAck : AcknowledgeSignal;
        out routedCancel : CancelSignal;
        out alertControl : AlertControl;
        out reset : Boolean;
    }

    port def PowerPort {
        in voltage : VoltageValue;
        in current : CurrentValue;
    }

    // ===== Interfaces =====

    interface def CallTransmissionInterface {
        end source : CallOutPort;
        end destination : ControllerNetworkPort;
        flow callRequest from source.callRequest to destination.callRequest;
    }

    interface def AckCancelInterface {
        end source : StationCallPort;
        end destination : ControllerNetworkPort;
        flow acknowledge from source.acknowledge to destination.acknowledge;
        flow cancel from source.cancel to destination.cancel;
    }

    interface def AlertControlInterface {
        end source : ControllerNetworkPort;
        end destination : AlertControlPort;
        flow alertControl from source.alertControl to destination.alertControl;
    }

    // ===== Parts =====

    part def CallButton {
        attribute room : RoomNumber;
        attribute bed : BedNumber;
        attribute buttonId : String;
        attribute supplyVoltage : VoltageValue := 12.0 [V];

        port callOut : CallOutPort;
        port power : PowerPort;

        attribute currentCallId : CallId[0..1];

        state buttonStateMachine {
            entry;
            then Idle;

            state Idle {
                entry;
            }

            state Pressed {
                entry {
                    currentCallId := generateCallId();
                    callOut.callRequest := CallRequest{
                        callId = currentCallId,
                        room = room,
                        bed = bed,
                        timestamp = now(),
                        status = CallStatus::active
                    };
                }
            }

            state Reset {
                entry {
                    currentCallId := null;
                }
                then Idle;
            }

            transition Idle_to_Pressed
                first Idle
                accept PressEvent
                then Pressed;

            transition Pressed_to_Reset
                first Pressed
                accept callOut.resetSignal
                then Reset;
        }

        private generateCallId() : CallId {
            // deterministic unique id based on room/bed/timestamp
            return room * 1000 + bed;
        }
    }

    part def RoomAlertPanel {
        attribute room : RoomNumber;
        attribute panelId : String;

        port alertControlPort : AlertControlPort;
        port power : PowerPort;

        attribute currentLevel : AlertLevel := AlertLevel::off;

        part buzzer {
            attribute active : Boolean := false;
            attribute soundLevel : Real := 75.0;
        }

        part flashingLight {
            attribute active : Boolean := false;
            attribute color : String := "red";
            attribute flashRate : Real := 1.0;
        }

        state alertStateMachine {
            entry;
            then Off;

            state Off {
                entry {
                    currentLevel := AlertLevel::off;
                    buzzer.active := false;
                    flashingLight.active := false;
                }
            }

            state FullAlert {
                entry {
                    currentLevel := AlertLevel::full;
                    buzzer.active := true;
                    flashingLight.active := true;
                    flashingLight.color := "red";
                }
            }

            state DimAlert {
                entry {
                    currentLevel := AlertLevel::dim;
                    buzzer.active := false;
                    flashingLight.active := true;
                    flashingLight.color := "yellow";
                    flashingLight.flashRate := 0.5;
                }
            }

            transition Off_to_Full
                first Off
                accept alertControlPort.alertControl
                if alertControlPort.alertControl.level == AlertLevel::full
                then FullAlert;

            transition Full_to_Dim
                first FullAlert
                accept alertControlPort.alertControl
                if alertControlPort.alertControl.level == AlertLevel::dim
                then DimAlert;

            transition Dim_to_Full
                first DimAlert
                accept alertControlPort.alertControl
                if alertControlPort.alertControl.level == AlertLevel::full
                then FullAlert;

            transition Any_to_Off
                first FullAlert | DimAlert
                accept alertControlPort.alertControl
                if alertControlPort.alertControl.level == AlertLevel::off
                then Off;
        }
    }

    part def NurseStationConsole {
        attribute consoleId : String;
        attribute maxCalls : Integer := 100;

        port stationPort : StationCallPort;
        port power : PowerPort;

        attribute activeCalls : CallRequest[0..*] := {};
        attribute callLog : CallLogEntry[0..*] := {};

        part display {
            attribute activeCallList : CallRequest[0..*];
        }

        part audioIndicator {
            attribute active : Boolean := false;
        }

        action def AcknowledgeCallAction {
            in callId : CallId;
            out ackSignal : AcknowledgeSignal;
        }

        action def CancelCallAction {
            in callId : CallId;
            out cancelSignal : CancelSignal;
        }

        action def LogCallAction {
            in entry : CallLogEntry;
        }

        state consoleStateMachine {
            entry;
            then Monitoring;

            state Monitoring {
                entry {
                    display.activeCallList := activeCalls;
                    audioIndicator.active := (activeCalls->size() > 0);
                }

                do {
                    accept stationPort.incomingCall {
                        activeCalls := activeCalls.append(stationPort.incomingCall);
                        display.activeCallList := activeCalls;
                        audioIndicator.active := true;
                    }
                }
            }

            state Acknowledging {
                entry {
                    perform AcknowledgeCallAction {
                        in callId = selectedCallId;
                        out ackSignal = stationPort.acknowledge;
                    }
                    activeCalls := activeCalls.select(c | c.callId != selectedCallId).collect(c | CallRequest{
                        callId = c.callId,
                        room = c.room,
                        bed = c.bed,
                        timestamp = c.timestamp,
                        status = CallStatus::acknowledged
                    });
                    display.activeCallList := activeCalls;
                }
                then Monitoring;
            }

            state Cancelling {
                entry {
                    perform CancelCallAction {
                        in callId = selectedCallId;
                        out cancelSignal = stationPort.cancel;
                    }
                    activeCalls := activeCalls.select(c | c.callId != selectedCallId);
                    perform LogCallAction {
                        in entry = CallLogEntry{
                            callId = selectedCallId,
                            room = selectedRoom,
                            bed = selectedBed,
                            requestTime = selectedRequestTime,
                            acknowledgeTime = selectedAckTime,
                            cancelTime = now(),
                            finalStatus = CallStatus::cancelled
                        };
                    }
                    callLog := callLog.append(LogCallAction.entry);
                    display.activeCallList := activeCalls;
                    audioIndicator.active := (activeCalls->size() > 0);
                }
                then Monitoring;
            }

            transition Monitoring_to_Acknowledging
                first Monitoring
                accept AcknowledgeCommandEvent
                then Acknowledging;

            transition Monitoring_to_Cancelling
                first Monitoring
                accept CancelCommandEvent
                then Cancelling;
        }

        attribute selectedCallId : CallId;
        attribute selectedRoom : RoomNumber;
        attribute selectedBed : BedNumber;
        attribute selectedRequestTime : TimeInstant;
        attribute selectedAckTime : TimeInstant[0..1];
    }

    part def CommunicationController {
        attribute controllerId : String;
        attribute networkAvailable : Boolean := true;

        port networkPort : ControllerNetworkPort;
        port power : PowerPort;

        part router {
            attribute routingTable : String[0..*];
        }

        part eventLogger {
            attribute logBuffer : CallLogEntry[0..*];

            action def LogEventAction {
                in entry : CallLogEntry;
            }
        }

        state controllerStateMachine {
            entry;
            then Operational;

            state Operational {
                entry {
                    networkAvailable := true;
                }

                do {
                    accept networkPort.callRequest {
                        networkPort.routedCall := networkPort.callRequest;
                        networkPort.alertControl := AlertControl{
                            room = networkPort.callRequest.room,
                            level = AlertLevel::full
                        };
                    }
                    or accept networkPort.acknowledge {
                        networkPort.routedAck := networkPort.acknowledge;
                        networkPort.alertControl := AlertControl{
                            room = networkPort.acknowledge.room,
                            level = AlertLevel::dim
                        };
                    }
                    or accept networkPort.cancel {
                        networkPort.routedCancel := networkPort.cancel;
                        networkPort.alertControl := AlertControl{
                            room = networkPort.cancel.room,
                            level = AlertLevel::off
                        };
                        networkPort.reset := true;
                    }
                }
            }

            state Fault {
                entry {
                    networkAvailable := false;
                }
            }

            transition Operational_to_Fault
                first Operational
                accept NetworkFailureEvent
                then Fault;

            transition Fault_to_Operational
                first Fault
                accept NetworkRecoveryEvent
                then Operational;
        }
    }

    part def PowerSupply {
        attribute supplyId : String;
        attribute nominalVoltage : VoltageValue := 12.0 [V];
        attribute maxCurrent : CurrentValue := 10.0 [A];
        attribute active : Boolean := true;

        port powerOut : PowerPort;
    }

    // ===== System Assembly =====

    part def NurseCallSystem {

        part powerSupply : PowerSupply;

        part controller : CommunicationController;

        part station : NurseStationConsole;

        part patientRoomUnits[0..*] :> PatientRoomUnit;

        part def PatientRoomUnit {
            attribute room : RoomNumber;
            attribute bedCount : Integer;

            part callButtons[1..*] : CallButton {
                redefines room = PatientRoomUnit::room;
            }

            part alertPanel : RoomAlertPanel {
                redefines room = PatientRoomUnit::room;
            }
        }

        connection powerToController connect powerSupply.powerOut to controller.power;
        connection powerToStation connect powerSupply.powerOut to station.power;

        connection callToController connect patientRoomUnits.callButtons.callOut to controller.networkPort;
        connection controllerToStation connect controller.networkPort.routedCall to station.stationPort.incomingCall;
        connection stationToController connect station.stationPort.acknowledge to controller.networkPort.acknowledge;
        connection stationToControllerCancel connect station.stationPort.cancel to controller.networkPort.cancel;
        connection controllerToPanel connect controller.networkPort.alertControl to patientRoomUnits.alertPanel.alertControlPort;
        connection controllerToButtonReset connect controller.networkPort.reset to patientRoomUnits.callButtons.callOut.resetSignal;

        connection powerToButtons connect powerSupply.powerOut to patientRoomUnits.callButtons.power;
        connection powerToPanels connect powerSupply.powerOut to patientRoomUnits.alertPanel.power;
    }

    // ===== Requirements =====

    requirement def RapidAlertActivationRequirement {
        doc {
            The system shall activate the room alert panel and notify the nurse station
            console within two seconds of a patient pressing the call button.
        }
        attribute maxActivationTime : TimeDuration := 2.0 [s];
        subject : NurseCallSystem;
        require constraint { 
            // Time from button press to panel activation <= 2 seconds
            true
        }
    }

    requirement def NetworkAvailabilityRequirement {
        doc {
            The communication network shall maintain continuous availability to ensure
            call signals are reliably transmitted between call buttons, the nurse station
            console, and room alert panels at all times.
        }
        subject : CommunicationController;
        require constraint {
            controller.networkAvailable == true
        }
    }

    requirement def LowVoltageOperationRequirement {
        doc {
            All system components shall operate at a safe low voltage not exceeding
            24 volts DC to ensure patient and staff safety.
        }
        attribute maxVoltage : VoltageValue := 24.0 [V];
        subject : NurseCallSystem;
        require constraint {
            powerSupply.nominalVoltage <= maxVoltage
        }
    }

    requirement def EventLoggingRequirement {
        doc {
            The system shall log all call events including request time, acknowledgement
            time, and cancellation time for quality assurance and record-keeping purposes.
        }
        subject : NurseStationConsole;
        require constraint {
            station.callLog->size() >= 0
        }
    }

    requirement def SimultaneousNotificationRequirement {
        doc {
            Upon a patient pressing the call button, the system shall simultaneously
            activate the room alert panel and transmit the call signal to the nurse
            station console.
        }
        subject : NurseCallSystem;
        require constraint {
            true
        }
    }

    requirement def AcknowledgementResponseRequirement {
        doc {
            When a staff member acknowledges a call at the nurse station console, the
            system shall update the call status and reduce the room alert panel to a
            dimmed level indicating a response is underway.
        }
        subject : NurseCallSystem;
        require constraint {
            true
        }
    }

    requirement def CancellationResetRequirement {
        doc {
            When a staff member cancels a call, the system shall deactivate the room
            alert panel and reset the patient call button to its idle state.
        }
        subject : NurseCallSystem;
        require constraint {
            true
        }
    }

    requirement def RoomBedIdentificationRequirement {
        doc {
            Each call button shall be identifiable by a specific room number and bed
            number, and this identification shall be included in all call signals.
        }
        subject : CallButton;
        require constraint {
            callButton.room != null and callButton.bed != null
        }
    }

    requirement def ActiveCallListRequirement {
        doc {
            The nurse station console shall maintain an active list of calls showing
            which patient is calling from which room.
        }
        subject : NurseStationConsole;
        require constraint {
            station.activeCalls->size() >= 0
        }
    }

    // ===== Requirement Satisfaction =====

    satisfaction satisfyRapidAlert : RapidAlertActivationRequirement {
        subject : NurseCallSystem;
    }

    satisfaction satisfyNetworkAvailability : NetworkAvailabilityRequirement {
        subject : CommunicationController;
    }

    satisfaction satisfyLowVoltage : LowVoltageOperationRequirement {
        subject : NurseCallSystem;
    }

    satisfaction satisfyEventLogging : EventLoggingRequirement {
        subject : NurseStationConsole;
    }

    satisfaction satisfySimultaneousNotification : SimultaneousNotificationRequirement {
        subject : NurseCallSystem;
    }

    satisfaction satisfyAcknowledgement : AcknowledgementResponseRequirement {
        subject : NurseCallSystem;
    }

    satisfaction satisfyCancellation : CancellationResetRequirement {
        subject : NurseCallSystem;
    }

    satisfaction satisfyRoomBedId : RoomBedIdentificationRequirement {
        subject : CallButton;
    }

    satisfaction satisfyActiveCallList : ActiveCallListRequirement {
        subject : NurseStationConsole;
    }

}
