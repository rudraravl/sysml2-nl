package 'Nurse Call Button System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RoomIdentifier {
        attribute roomNumber : String;
        attribute bedPosition : String;
    }
    
    attribute def CallPriorityLevel {
        attribute level : Integer;
        attribute description : String;
    }
    
    enum def CallStatusKind {
        enum idle;
        enum active;
        enum acknowledged;
        enum cancelled;
    }
    
    enum def AlertTypeKind {
        enum routine;
        enum urgent;
        enum emergency;
    }
    
    item def CallSignal {
        attribute roomId : RoomIdentifier;
        attribute priority : CallPriorityLevel;
        attribute status : CallStatusKind;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def AcknowledgementSignal {
        attribute roomId : RoomIdentifier;
        attribute nurseId : String;
        attribute responseTime : ISQ::TimeValue;
    }
    
    item def CancellationSignal {
        attribute roomId : RoomIdentifier;
        attribute cancelledBy : String;
    }
    
    attribute def ElectricalVoltage :> ISQ::ElectricPotentialValue;
    attribute def SignalFrequency :> ISQ::FrequencyValue;
    attribute def LightIntensity :> ISQ::LuminousIntensityValue;
    attribute def SoundLevel :> ISQ::PowerValue;
    
    port def CallButtonPort {
        out callRequest : CallSignal;
        in acknowledgement : AcknowledgementSignal;
        in cancellation : CancellationSignal;
    }
    
    port def AlertDisplayPort {
        in callNotification : CallSignal;
        out visualIndicator : LightIntensity;
        out audioIndicator : SoundLevel;
    }
    
    port def NurseStationPort {
        in incomingCall : CallSignal;
        out ackSignal : AcknowledgementSignal;
        out cancelSignal : CancellationSignal;
    }
    
    port def CommunicationBusPort {
        inout callData : CallSignal;
        inout ackData : AcknowledgementSignal;
        inout cancelData : CancellationSignal;
    }
    
    part def CallButton {
        attribute roomIdentifier : RoomIdentifier;
        attribute buttonPressed : Boolean;
        attribute pressureThreshold : ISQ::PressureValue;
        
        port buttonPort : CallButtonPort;
        
        action def GenerateCallSignal {
            in roomId : RoomIdentifier;
            out signal : CallSignal;
        }
        
        state machine CallButtonStateMachine {
            in roomId : RoomIdentifier;
            
            entry; then idle;
            
            state idle {
                entry assign buttonPressed := false;
                accept buttonPress;
                transition to activated;
            }
            
            state activated {
                entry assign buttonPressed := true;
                do action generateCall : GenerateCallSignal {
                    in roomId = CallButtonStateMachine::roomId;
                    out signal;
                }
                accept ack : AcknowledgementSignal;
                transition to acknowledged;
                accept cancel : CancellationSignal;
                transition to idle;
            }
            
            state acknowledged {
                accept cancel : CancellationSignal;
                transition to idle;
            }
        }
    }
    
    part def RoomAlertPanel {
        attribute panelId : String;
        attribute currentStatus : CallStatusKind;
        
        port alertPort : AlertDisplayPort;
        
        action def DisplayAlert {
            in callData : CallSignal;
            out visualOutput : LightIntensity;
            out audioOutput : SoundLevel;
        }
        
        action manageAlertDisplay {
            first start;
            then merge monitoringState;
            
            action waitForCall;
            accept incomingCall : CallSignal;
            
            then action activateAlert : DisplayAlert {
                in callData = incomingCall;
                out visualOutput;
                out audioOutput;
            }
            
            then assign currentStatus := CallStatusKind::active;
            
            then merge alertActiveLoop;
            action maintainAlert;
            
            then decide;
                if currentStatus == CallStatusKind::acknowledged then dimAlert;
                if currentStatus == CallStatusKind::cancelled then deactivateAlert;
                if currentStatus == CallStatusKind::active then alertActiveLoop;
            
            action dimAlert {
                out reducedVisual : LightIntensity;
            }
            then alertActiveLoop;
            
            action deactivateAlert {
                out zeroVisual : LightIntensity;
                out zeroAudio : SoundLevel;
            }
            then assign currentStatus := CallStatusKind::idle;
            then monitoringState;
        }
    }
    
    part def NurseStationConsole {
        attribute stationId : String;
        attribute activeCallList : CallSignal[*];
        attribute onDutyStaff : String[*];
        
        port consolePort : NurseStationPort;
        
        action def ProcessIncomingCall {
            in call : CallSignal;
            out displayUpdate : Boolean;
        }
        
        action def GenerateAcknowledgement {
            in call : CallSignal;
            in nurseId : String;
            out ack : AcknowledgementSignal;
        }
        
        action def GenerateCancellation {
            in roomId : RoomIdentifier;
            in staffId : String;
            out cancel : CancellationSignal;
        }
        
        action operateConsole {
            first start;
            then merge readyState;
            
            action monitorCalls;
            accept newCall : CallSignal;
            
            then action processCall : ProcessIncomingCall {
                in call = newCall;
                out displayUpdate;
            }
            
            then action updateActiveList {
                assign activeCallList := activeCallList->including(newCall);
            }
            
            then action notifyStaff;
            
            then merge awaitResponse;
            
            action waitForStaffAction;
            
            then decide;
                if staffAcknowledges then sendAcknowledgement;
                if staffCancels then sendCancellation;
            
            action sendAcknowledgement : GenerateAcknowledgement {
                in call = newCall;
                in nurseId;
                out ack;
            }
            then action removeFromActive {
                assign activeCallList := activeCallList->excluding(newCall);
            }
            then readyState;
            
            action sendCancellation : GenerateCancellation {
                in roomId = newCall.roomId;
                in staffId;
                out cancel;
            }
            then action clearFromActive {
                assign activeCallList := activeCallList->excluding(newCall);
            }
            then readyState;
        }
    }
    
    part def CommunicationController {
        attribute controllerId : String;
        attribute networkStatus : Boolean;
        attribute messageQueue : CallSignal[*];
        
        port busPort : CommunicationBusPort;
        
        action def RouteCallSignal {
            in incomingCall : CallSignal;
            out routedCall : CallSignal;
        }
        
        action def RouteAcknowledgement {
            in incomingAck : AcknowledgementSignal;
            out routedAck : AcknowledgementSignal;
        }
        
        action def RouteCancellation {
            in incomingCancel : CancellationSignal;
            out routedCancel : CancellationSignal;
        }
        
        action manageTraffic {
            first start;
            then merge trafficLoop;
            
            action monitorBus;
            
            then decide;
                if callReceived then handleCall;
                if ackReceived then handleAck;
                if cancelReceived then handleCancel;
            
            action handleCall : RouteCallSignal {
                in incomingCall;
                out routedCall;
            }
            then trafficLoop;
            
            action handleAck : RouteAcknowledgement {
                in incomingAck;
                out routedAck;
            }
            then trafficLoop;
            
            action handleCancel : RouteCancellation {
                in incomingCancel;
                out routedCancel;
            }
            then trafficLoop;
        }
    }
    
    part nurseCallSystem {
        attribute systemName : String = "Patient Care Communication System";
        attribute numberOfRooms : Integer;
        
        part room301Button : CallButton {
            attribute :>> roomIdentifier {
                attribute :>> roomNumber = "301";
                attribute :>> bedPosition = "A";
            }
        }
        
        part room301Panel : RoomAlertPanel {
            attribute :>> panelId = "Panel-301A";
        }
        
        part room302Button : CallButton {
            attribute :>> roomIdentifier {
                attribute :>> roomNumber = "302";
                attribute :>> bedPosition = "B";
            }
        }
        
        part room302Panel : RoomAlertPanel {
            attribute :>> panelId = "Panel-302B";
        }
        
        part centralStation : NurseStationConsole {
            attribute :>> stationId = "Central-Floor3";
            attribute :>> onDutyStaff = ("Nurse Smith", "Nurse Johnson");
        }
        
        part commController : CommunicationController {
            attribute :>> controllerId = "CommCtrl-Floor3";
            attribute :>> networkStatus = true;
        }
        
        connection room301ButtonToController 
            connect room301Button.buttonPort to commController.busPort;
        
        connection room302ButtonToController 
            connect room302Button.buttonPort to commController.busPort;
        
        connection controllerToStation 
            connect commController.busPort to centralStation.consolePort;
        
        connection controllerToPanel301 
            connect commController.busPort to room301Panel.alertPort;
        
        connection controllerToPanel302 
            connect commController.busPort to room302Panel.alertPort;
        
        action providePatientCallService {
            doc /* 
                The nurse call button system enables patients to request assistance 
                from nursing staff by pressing a bedside call button. When activated, 
                the system transmits a call signal through a communication network to 
                the central nurse station and activates audio-visual alerts in the 
                patient room and hallway. Nursing staff can acknowledge the call from 
                the central console, which updates the alert status. The system ensures 
                timely communication between patients and caregivers, supporting prompt 
                response to patient needs and enhancing overall care quality and safety.
            */
            
            first start;
            then merge systemReady;
            
            action monitorAllButtons;
            accept patientCallRequest;
            
            then action initiateCallSequence {
                action captureButtonPress;
                
                then action routeCallThroughNetwork {
                    perform commController.manageTraffic;
                }
                
                then action notifyNurseStation {
                    perform centralStation.operateConsole;
                }
                
                then action activateRoomAlert {
                    perform room301Panel.manageAlertDisplay;
                }
            }
            
            then action awaitStaffResponse;
            
            then decide;
                if staffAcknowledges then processAcknowledgement;
                if staffCancels then processCancellation;
            
            action processAcknowledgement {
                action routeAckSignal {
                    perform commController.manageTraffic;
                }
                then action updateButtonState;
                then action updatePanelDisplay;
            }
            then systemReady;
            
            action processCancellation {
                action routeCancelSignal {
                    perform commController.manageTraffic;
                }
                then action resetButtonState;
                then action deactivatePanelDisplay;
            }
            then systemReady;
        }
    }
    
    requirement def SystemResponseTime;
    requirement def AlertReliability;
    requirement def NetworkAvailability;
    requirement def UserSafety;
    
    requirement <'NCR-001'> responseTimeRequirement : SystemResponseTime {
        doc /* 
            The nurse call system shall activate all audio and visual alerts 
            within 2 seconds of the call button being pressed to ensure 
            timely notification of nursing staff.
        */
        
        subject nurseCallSystem;
        
        require constraint {
            alertActivationTime <= 2.0
        }
    }
    
    requirement <'NCR-002'> alertPersistenceRequirement : AlertReliability {
        doc /* 
            Audio and visual alerts shall remain continuously active until 
            explicitly acknowledged or cancelled by authorized nursing staff 
            to prevent missed patient requests.
        */
        
        subject nurseCallSystem;
    }
    
    requirement <'NCR-003'> networkAvailabilityRequirement : NetworkAvailability {
        doc /* 
            The communication network shall maintain 99.9% uptime to ensure 
            reliable transmission of call signals between patient rooms and 
            the nurse station.
        */
        
        subject nurseCallSystem.commController;
        
        require constraint {
            networkUptime >= 0.999
        }
    }
    
    requirement <'NCR-004'> safetyRequirement : UserSafety {
        doc /* 
            All electrical components shall operate at safe low voltage levels 
            (24V DC or less) to ensure patient and staff safety in healthcare 
            environments.
        */
        
        subject nurseCallSystem;
        
        require constraint {
            operatingVoltage <= 24.0
        }
    }
    
    requirement <'NCR-005'> callLoggingRequirement {
        doc /* 
            The system shall log all call events including timestamp, room 
            identifier, response time, and acknowledging staff member for 
            quality assurance and regulatory compliance.
        */
        
        subject nurseCallSystem.centralStation;
    }
    
    requirement primaryMissionRequirement {
        doc /* 
            The nurse call button system shall provide a reliable, immediate 
            communication mechanism enabling patients to summon nursing assistance 
            when needed, ensuring timely response to patient care requirements 
            through clear audio-visual notification of nursing staff, thereby 
            supporting high-quality patient care and safety in healthcare facilities.
        */
        
        subject nurseCallSystem;
        
        require responseTimeRequirement;
        require alertPersistenceRequirement;
        require networkAvailabilityRequirement;
        require safetyRequirement;
        require callLoggingRequirement;
    }
}
