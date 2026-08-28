package HomeRFNetworkSystem {
    private import ScalarValues::*;
    
    attribute def FrequencyValue :> Real;
    attribute def TimeValue :> Real;
    
    attribute def FrequencyHoppingSequence {
        attribute frequencies : FrequencyValue[1..*];
        attribute hopRate : FrequencyValue;
    }
    
    attribute def TimeSlot {
        attribute duration : TimeValue;
        attribute slotId : Integer;
    }
    
    item def BeaconFrame {
        attribute hoppingSequence : FrequencyHoppingSequence;
        attribute timestamp : TimeValue;
    }
    
    item def AssociationRequest {
        attribute deviceId : Integer;
    }
    
    item def AssociationResponse {
        attribute assignedSlot : TimeSlot;
        attribute authenticated : Boolean;
    }
    
    item def VoicePacket;
    item def DataPacket;
    
    port def WirelessPort {
        in item beacon : BeaconFrame;
        in item associationResponse : AssociationResponse;
        out item associationRequest : AssociationRequest;
        in item voiceIn : VoicePacket;
        out item voiceOut : VoicePacket;
        in item dataIn : DataPacket;
        out item dataOut : DataPacket;
    }
    
    action def ListenForBeacon {
        out item detectedBeacon : BeaconFrame;
    }
    
    action def SendAssociationRequest {
        out item request : AssociationRequest;
    }
    
    action def ProcessVoice {
        in item voiceIn : VoicePacket;
        out item voiceOut : VoicePacket;
    }
    
    action def RouteData {
        in item dataIn : DataPacket;
        out item dataOut : DataPacket;
    }
    
    action def Encrypt {
        in item data : DataPacket;
        out item encrypted : DataPacket;
    }
    
    action def Authenticate {
        in item request : AssociationRequest;
        out item response : AssociationResponse;
    }
    
    action def AssignTimeSlot {
        out attribute slot : TimeSlot;
    }
    
    action def BroadcastBeacon {
        out item beacon : BeaconFrame;
    }
    
    state def DeviceBehavior {
        state Scanning;
        state Associating;
        state Connected {
            state Idle;
            state Transmitting;
            state Receiving;
        }
        
        transition from Scanning to Associating;
        transition from Associating to Connected;
        transition from Connected.Transmitting to Connected.Idle;
        transition from Connected.Receiving to Connected.Idle;
        transition from Connected.Idle to Connected.Transmitting;
        transition from Connected.Idle to Connected.Receiving;
    }
    
    part def RadioTransceiver {
        port rfPort : ~WirelessPort;
    }
    
    part def Processor {
        attribute clockSpeed : FrequencyValue;
    }
    
    part def PowerManager {
        attribute inSleepMode : Boolean = false;
        attribute batteryLevel : Real;
    }
    
    part def ControlPoint {
        attribute maxDevices : Integer = 127;
        attribute operatingBand : FrequencyValue = 2.4;
        attribute hoppingSequence : FrequencyHoppingSequence;
        
        port wirelessPort : WirelessPort;
        
        part macController {
            perform authenticate : Authenticate;
            perform assignTimeSlot : AssignTimeSlot;
        }
        
        part voiceCodec {
            perform processVoice : ProcessVoice;
        }
        
        part dataRouter {
            perform routeData : RouteData;
        }
        
        part encryptionEngine {
            perform encrypt : Encrypt;
        }
        
        perform broadcastBeacon : BroadcastBeacon;
        
        flow beaconFlow from broadcastBeacon.beacon to wirelessPort.beacon;
    }
    
    part def WirelessDevice {
        port wirelessPort : ~WirelessPort;
        
        part radioTransceiver : RadioTransceiver;
        part processor : Processor;
        part powerManager : PowerManager;
        
        connect wirelessPort to radioTransceiver.rfPort;
        
        perform deviceBehavior : DeviceBehavior;
    }
    
    connection def WirelessConnection {
        end cpPort : WirelessPort;
        end devPort : ~WirelessPort;
    }
    
    part def HomeRFNetwork {
        part controlPoint : ControlPoint;
        part devices : WirelessDevice[0..127];
        
        connection wirelessLinks : WirelessConnection connect controlPoint.wirelessPort to devices.wirelessPort;
    }
    
    requirement def OperatesIn24GHz {
        doc /* The system shall operate in the 2.4 GHz ISM band. */
        attribute operatingFrequency : FrequencyValue = 2.4;
    }
    
    requirement def MaxDevices {
        doc /* A Control Point shall support up to 127 Wireless Devices. */
        attribute maxClients : Integer = 127;
    }
    
    requirement def FrequencyHopping {
        doc /* The system shall use FHSS with a synchronized hopping pattern. */
    }
    
    satisfy OperatesIn24GHz by HomeRFNetwork;
    satisfy MaxDevices by ControlPoint;
    satisfy FrequencyHopping by HomeRFNetwork;
}
