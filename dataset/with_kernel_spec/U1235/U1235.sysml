package TelephoneSwitchboardSystem {

    item def AudioSignal {
        attribute amplitude : ScalarValues::Real;
        attribute frequency : ScalarValues::Real;
    }

    item def VoiceSignal :> AudioSignal;

    item def DialTone :> AudioSignal {
        attribute frequency : ScalarValues::Real = 440.0;
    }

    item def RingingSignal :> AudioSignal {
        attribute frequency : ScalarValues::Real = 440.0;
        attribute cadenceOn : ScalarValues::Real = 2.0;
        attribute cadenceOff : ScalarValues::Real = 4.0;
    }

    item def BusySignal :> AudioSignal {
        attribute frequency : ScalarValues::Real = 480.0;
        attribute cadenceOn : ScalarValues::Real = 0.5;
        attribute cadenceOff : ScalarValues::Real = 0.5;
    }

    item def PhoneNumber {
        attribute number : ScalarValues::String;
    }

    item def CallRecord {
        attribute callerNumber : ScalarValues::String;
        attribute receiverNumber : ScalarValues::String;
        attribute startTime : ScalarValues::String;
        attribute duration : ScalarValues::Real;
    }

    port def LinePort {
        in item voiceIn : VoiceSignal;
        out item voiceOut : VoiceSignal;
        in item signalIn : AudioSignal;
        out item hookStatus : ScalarValues::Boolean;
        out item dialedNumber : PhoneNumber;
    }

    port def TrunkPort {
        in item voiceIn : VoiceSignal;
        out item voiceOut : VoiceSignal;
        in item signalIn : AudioSignal;
    }

    port def OperatorPort {
        in item callerNotification : PhoneNumber;
        out item destinationNumber : PhoneNumber;
        out item connectCommand : ScalarValues::Boolean;
        out item disconnectCommand : ScalarValues::Boolean;
    }

    port def MatrixPort {
        in item voiceIn : VoiceSignal;
        out item voiceOut : VoiceSignal;
    }

    port def SignalPort {
        out item audioOut : AudioSignal;
    }

    port def RecordingPort {
        in item callRecord : CallRecord;
    }

    part def SubscriberLine {
        port linePort : LinePort;
        attribute phoneNumber : PhoneNumber;
        attribute status : ScalarValues::String = "idle";
        attribute lineId : ScalarValues::Integer;
    }

    part def TrunkLine {
        port trunkPort : TrunkPort;
        attribute trunkId : ScalarValues::Integer;
        attribute status : ScalarValues::String = "idle";
        attribute connectedNetwork : ScalarValues::String;
    }

    part def SwitchingMatrix {
        port matrixPorts : MatrixPort[0..100];
        port trunkMatrixPorts : MatrixPort[0..10];
        port operatorInterfaces : OperatorPort[0..5];
        port signalRequest : SignalPort[0..1];
        port recordingInterface : RecordingPort[0..1];

        attribute activeConnections : ScalarValues::Integer = 0;
        attribute maxConnections : ScalarValues::Integer = 100;

        perform action establishConnection {
            in caller : PhoneNumber;
            in destination : PhoneNumber;
            out connectionId : ScalarValues::Integer;
        }

        perform action routeAudio {
            in voiceIn : VoiceSignal;
            out voiceOut : VoiceSignal;
        }

        perform action terminateConnection {
            in connectionId : ScalarValues::Integer;
        }
    }

    part def OperatorConsole {
        port operatorPort : OperatorPort;
        attribute consoleId : ScalarValues::Integer;
        attribute operatorName : ScalarValues::String;

        perform action handleCallRequest {
            in callerNumber : PhoneNumber;
            out destinationNumber : PhoneNumber;
        }

        perform action issueConnectCommand {
            out destination : PhoneNumber;
            out command : ScalarValues::Boolean;
        }

        perform action issueDisconnectCommand {
            out command : ScalarValues::Boolean;
        }
    }

    part def SignalGenerator {
        port signalOutput : SignalPort[0..100];
        port signalOutputTrunk : SignalPort[0..10];

        perform action generateDialTone {
            out tone : DialTone;
        }

        perform action generateRingingSignal {
            out signal : RingingSignal;
        }

        perform action generateBusySignal {
            out signal : BusySignal;
        }
    }

    part def CallRecordingSystem {
        port recordingPort : RecordingPort;
        attribute logCapacity : ScalarValues::Integer = 10000;
        item storedRecords : CallRecord[0..10000];

        perform action logCall {
            in record : CallRecord;
        }

        perform action retrieveRecords {
            out records : CallRecord[0..*];
        }
    }

    connection def LineToMatrixConnection {
        end lineEnd : LinePort;
        end matrixEnd : MatrixPort;
    }

    connection def TrunkToMatrixConnection {
        end trunkEnd : TrunkPort;
        end matrixEnd : MatrixPort;
    }

    connection def OperatorToMatrixConnection {
        end operatorEnd : OperatorPort;
        end matrixEnd : OperatorPort;
    }

    connection def SignalToMatrixConnection {
        end signalEnd : SignalPort;
        end matrixEnd : SignalPort;
    }

    connection def MatrixToRecordingConnection {
        end matrixEnd : RecordingPort;
        end recordingEnd : RecordingPort;
    }

    connection def VoicePathConnection {
        end sourceEnd : MatrixPort;
        end destEnd : MatrixPort;
    }

    requirement def CallConnectionRequirement {
        doc /** The switchboard must be able to connect any subscriber line to any other subscriber line. */
    }

    requirement def OperatorResponseRequirement {
        doc /** An operator must be notified within 3 seconds of a subscriber going off hook. */
    }

    requirement def SignalGenerationRequirement {
        doc /** The signal generator must produce dial tone, ringing signal, and busy signal. */
    }

    requirement def CallRecordingRequirement {
        doc /** Every completed call must be logged with caller, receiver, start time, and duration. */
    }

    requirement def TrunkCapacityRequirement {
        doc /** The switchboard must support at least 10 external trunk lines. */
    }

    part def SwitchboardSystem {
        attribute systemId : ScalarValues::String;
        attribute systemBreadth : ScalarValues::Real;

        part switchingMatrix : SwitchingMatrix;
        part subscriberLines : SubscriberLine[0..100];
        part trunkLines : TrunkLine[0..10];
        part operatorConsoles : OperatorConsole[5];
        part signalGenerator : SignalGenerator;
        part callRecordingSystem : CallRecordingSystem;

        connection lineToMatrix : LineToMatrixConnection[0..100]
            connect subscriberLines.linePort to switchingMatrix.matrixPorts;

        connection trunkToMatrix : TrunkToMatrixConnection[0..10]
            connect trunkLines.trunkPort to switchingMatrix.trunkMatrixPorts;

        connection operatorToMatrix : OperatorToMatrixConnection[5]
            connect operatorConsoles.operatorPort to switchingMatrix.operatorInterfaces;

        connection signalToMatrix : SignalToMatrixConnection[1]
            connect signalGenerator.signalOutput to switchingMatrix.signalRequest;

        connection matrixToRecording : MatrixToRecordingConnection[1]
            connect switchingMatrix.recordingInterface to callRecordingSystem.recordingPort;

        perform action {
            first start;
            then action detectOffHook {
                in callerLine : SubscriberLine;
                out notification : PhoneNumber;
            }
            then action notifyOperator {
                in notification : PhoneNumber;
                out destination : PhoneNumber;
            }
            then action attemptConnection {
                in caller : PhoneNumber;
                in destination : PhoneNumber;
                out connectionEstablished : ScalarValues::Boolean;
            }
            then action routeCall {
                in caller : PhoneNumber;
                in destination : PhoneNumber;
                out callData : CallRecord;
            }
            then action recordCall {
                in callData : CallRecord;
            }
            then action terminateCall {
                in caller : PhoneNumber;
                in destination : PhoneNumber;
            }
            then done;
        }

        satisfy CallConnectionRequirement by switchingMatrix;
        satisfy OperatorResponseRequirement by operatorConsoles;
        satisfy SignalGenerationRequirement by signalGenerator;
        satisfy CallRecordingRequirement by callRecordingSystem;
        satisfy TrunkCapacityRequirement by switchingMatrix;
    }
}
