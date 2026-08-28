package HomeRF {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value type FrequencyUnit > Real { unit 'Hz'; }
    value type FrequencyValue > FrequencyUnit;
    value type DataRate > Real { unit 'Mb/s'; }
    value type PowerLevel > Real { unit 'mW'; }
    value type TimeSlotDuration > Real { unit 'ms'; }
    value type HopRate > Real { unit 'hops/s'; }
    value type DeviceID > Integer;
    value type SlotIndex > Integer;
    value type BeaconInterval > Real { unit 'ms'; }
    value type RSSI > Real { unit 'dBm'; }

    enumeration SecurityLevel { none = 0, basic = 1, strong = 2; }
    enumeration TrafficClass { voice, data; }
    enumeration DeviceType { cordlessHandset, computerAdapter, other; }
    enumeration AssociationStatus { notAssociated, authenticating, associated, rejected; }

    item def BeaconFrame {
        attribute networkID : String;
        attribute hopSequenceID : Integer;
        attribute currentHopIndex : Integer;
        attribute beaconTimestamp : TimeSlotDuration;
        attribute nextBeacon : BeaconInterval;
        attribute availableSlots : SlotIndex;
    }

    item def AssociationRequest {
        attribute deviceID : DeviceID;
        attribute deviceType : DeviceType;
        attribute requestedClass : TrafficClass;
        attribute securityCapability : SecurityLevel;
    }

    item def AssociationResponse {
        attribute granted : Boolean;
        attribute assignedSlot : SlotIndex;
        attribute assignedID : DeviceID;
        attribute hopSequenceID : Integer;
        attribute status : AssociationStatus;
    }

    item def VoiceFrame {
        attribute sourceID : DeviceID;
        attribute destinationID : DeviceID;
        attribute payload : String;
        attribute sequenceNumber : Integer;
        attribute encrypted : Boolean;
    }

    item def DataFrame {
        attribute sourceID : DeviceID;
        attribute destinationID : DeviceID;
        attribute payload : String;
        attribute priority : Integer;
        attribute encrypted : Boolean;
    }

    item def RFSignal {
        attribute frequency : FrequencyValue;
        attribute power : PowerLevel;
        attribute rssi : RSSI;
    }

    // ===== Interfaces =====

    interface def RFInterface {
        in item rfSignal : RFSignal;
        out item transmittedSignal : RFSignal;
    }

    interface def BeaconInterface {
        out item beacon : BeaconFrame;
    }

    interface def AssociationInterface {
        in item request : AssociationRequest;
        out item response : AssociationResponse;
    }

    interface def VoiceTrafficInterface {
        in item uplinkVoice : VoiceFrame;
        out item downlinkVoice : VoiceFrame;
    }

    interface def DataTrafficInterface {
        in item uplinkData : DataFrame;
        out item downlinkData : DataFrame;
    }

    // ===== Port Definitions =====

    port def RFAirPort :> RFInterface;
    port def BeaconPort :> BeaconInterface;
    port def AssociationPort :> AssociationInterface;
    port def VoicePort :> VoiceTrafficInterface;
    port def DataPort :> DataTrafficInterface;

    // ===== FHSS Hopping Pattern =====

    item def HopSequence {
        attribute sequenceID : Integer;
        attribute channelCount : Integer = 79;
        attribute hopRate : HopRate = 50.0;
        attribute baseFrequency : FrequencyValue = 2.4e9;
        attribute channelSpacing : FrequencyValue = 1.0e6;
        attribute pattern : Integer[79] = { 0, 5, 10, 15, 20, 25, 30, 35, 40, 45,
                                            50, 55, 60, 65, 70, 1, 6, 11, 16, 21,
                                            26, 31, 36, 41, 46, 51, 56, 61, 66, 71,
                                            2, 7, 12, 17, 22, 27, 32, 37, 42, 47,
                                            52, 57, 62, 67, 72, 3, 8, 13, 18, 23,
                                            28, 33, 38, 43, 48, 53, 58, 63, 68, 73,
                                            4, 9, 14, 19, 24, 29, 34, 39, 44, 49,
                                            54, 59, 64, 69, 74, 75, 76, 77, 78 };
    }

    // ===== Control Point =====

    part def ControlPoint {

        attribute maxDevices : Integer = 127;
        attribute currentDeviceCount : Integer;
        attribute networkID : String = "HomeRF_Net_001";
        attribute beaconInterval : BeaconInterval = 20.0;
        attribute slotDuration : TimeSlotDuration = 10.0;
        attribute securityLevel : SecurityLevel = SecurityLevel::strong;

        port rfPort : RFAirPort;
        port beaconPort : BeaconPort;
        port assocPort : AssociationPort;
        port voicePort : VoicePort;
        port dataPort : DataPort;

        part fhssEngine {
            attribute currentHopIndex : Integer;
            attribute hopSequence : HopSequence;
            attribute synchronized : Boolean;

            action hopFrequency {
                in seq : HopSequence;
                in index : Integer;
                out newFrequency : FrequencyValue;
            }
        }

        part macController {
            attribute slotTable : SlotIndex[127];
            attribute deviceRegistry : DeviceID[127];
            attribute authenticatedDevices : DeviceID[0..127];

            action authenticateDevice {
                in request : AssociationRequest;
                out granted : Boolean;
                out assignedSlot : SlotIndex;
            }

            action assignTimeSlot {
                in deviceID : DeviceID;
                in trafficClass : TrafficClass;
                out slot : SlotIndex;
            }

            action releaseSlot {
                in deviceID : DeviceID;
            }
        }

        part voiceCodec {
            attribute codecType : String = "G.711";
            attribute samplingRate : FrequencyValue = 8000.0;
            attribute frameSize : Integer = 160;

            action encodeVoice {
                in analogVoice : String;
                out encodedFrame : VoiceFrame;
            }

            action decodeVoice {
                in frame : VoiceFrame;
                out analogVoice : String;
            }
        }

        part dataRouter {
            attribute queueDepth : Integer = 64;
            attribute maxPriority : Integer = 8;

            action routeData {
                in frame : DataFrame;
                out forwarded : DataFrame;
            }

            action prioritizeData {
                in frames : DataFrame[*];
                out ordered : DataFrame[*];
            }
        }

        part encryptionEngine {
            attribute algorithm : String = "AES";
            attribute keyLength : Integer = 128;

            action encrypt {
                in plaintext : String;
                out ciphertext : String;
            }

            action decrypt {
                in ciphertext : String;
                out plaintext : String;
            }
        }

        part beaconGenerator {
            attribute active : Boolean = true;

            action generateBeacon {
                in netID : String;
                in hopSeq : HopSequence;
                in hopIndex : Integer;
                in available : SlotIndex;
                out beacon : BeaconFrame;
            }
        }

        state ControlPointBehavior {

            entry action initialize {
                fhssEngine.currentHopIndex = 0;
                fhssEngine.synchronized = true;
                currentDeviceCount = 0;
            }

            state Operational {
                entry; 
                do action broadcastBeacon {
                    beaconGenerator.generateBeacon(
                        networkID,
                        fhssEngine.hopSequence,
                        fhssEngine.currentHopIndex,
                        maxDevices - currentDeviceCount
                    );
                }

                transition Operational
                    then Operational
                    when beaconInterval elapsed;

                transition Operational
                    then Operational
                    when assocPort.request received;

                transition Operational
                    then Operational
                    when fhssEngine.hopRate elapsed;
            }

            state Maintenance {
                entry;
            }

            transition Operational
                then Maintenance
                when false;

            transition Maintenance
                then Operational
                when false;
        }

        connection fhssToMAC connect fhssEngine to macController;
        connection macToVoice connect macController to voiceCodec;
        connection macToData connect macController to dataRouter;
        connection voiceToEncryption connect voiceCodec to encryptionEngine;
        connection dataToEncryption connect dataRouter to encryptionEngine;
        connection beaconToRF connect beaconGenerator to rfPort;
    }

    // ===== Wireless Device =====

    part def WirelessDevice {

        attribute deviceID : DeviceID;
        attribute deviceType : DeviceType;
        attribute batteryLevel : PowerLevel;
        attribute associated : Boolean = false;
        attribute assignedSlot : SlotIndex;
        attribute hopSequence : HopSequence;
        attribute currentHopIndex : Integer;

        port rfPort : RFAirPort;
        port beaconPort : BeaconPort;
        port assocPort : AssociationPort;
        port voicePort : VoicePort;
        port dataPort : DataPort;

        part radioTransceiver {
            attribute operatingFrequency : FrequencyValue;
            attribute transmitPower : PowerLevel = 10.0;
            attribute receiverSensitivity : RSSI = -85.0;
            attribute active : Boolean;

            action transmit {
                in signal : RFSignal;
            }

            action receive {
                out signal : RFSignal;
            }

            action tuneFrequency {
                in frequency : FrequencyValue;
            }
        }

        part processor {
            attribute clockRate : FrequencyValue = 16.0e6;
            attribute applicationType : TrafficClass;

            action processVoice {
                in frame : VoiceFrame;
                out audio : String;
            }

            action processData {
                in frame : DataFrame;
                out data : String;
            }

            action generateVoice {
                in audio : String;
                out frame : VoiceFrame;
            }

            action generateData {
                in data : String;
                out frame : DataFrame;
            }
        }

        part powerManager {
            attribute sleepMode : Boolean = false;
            attribute idleThreshold : TimeSlotDuration = 100.0;
            attribute currentConsumption : PowerLevel;

            action enterSleep {
                sleepMode = true;
                currentConsumption = 0.1;
            }

            action wakeUp {
                sleepMode = false;
                currentConsumption = 15.0;
            }

            action monitorActivity {
                in lastActivity : TimeSlotDuration;
                if lastActivity > idleThreshold then enterSleep();
            }
        }

        part fhssSynchronizer {
            attribute synchronized : Boolean = false;
            attribute hopSequenceID : Integer;

            action synchronizeHop {
                in beacon : BeaconFrame;
                out hopIndex : Integer;
            }

            action advanceHop {
                currentHopIndex = currentHopIndex + 1;
            }
        }

        state DeviceLifecycle {

            entry action powerOn {
                associated = false;
                powerManager.wakeUp();
            }

            state Scanning {
                entry;
                do action scanForBeacon {
                    radioTransceiver.receive();
                }

                transition Scanning
                    then Associating
                    when beaconPort.beacon received;
            }

            state Associating {
                entry;
                do action requestAssociation {
                    fhssSynchronizer.synchronizeHop(beaconPort.beacon);
                    assocPort.request = AssociationRequest{
                        deviceID = deviceID,
                        deviceType = deviceType,
                        requestedClass = processor.applicationType,
                        securityCapability = SecurityLevel::strong
                    };
                }

                transition Associating
                    then Connected
                    when assocPort.response.granted == true;

                transition Associating
                    then Scanning
                    when assocPort.response.granted == false;
            }

            state Connected {
                entry;
                do action operate {
                    fhssSynchronizer.advanceHop();
                    powerManager.monitorActivity();
                }

                state Transmitting {
                    entry;
                    do action transmitData {
                        if processor.applicationType == TrafficClass::voice then
                            processor.generateVoice();
                        else
                            processor.generateData();
                        radioTransceiver.transmit();
                    }
                }

                state Receiving {
                    entry;
                    do action receiveData {
                        radioTransceiver.receive();
                        if processor.applicationType == TrafficClass::voice then
                            processor.processVoice();
                        else
                            processor.processData();
                    }
                }

                state Idle {
                    entry;
                    do action idle {
                        powerManager.monitorActivity();
                    }
                }

                transition Idle
                    then Transmitting
                    when voicePort.uplinkVoice requested or dataPort.uplinkData requested;

                transition Transmitting
                    then Receiving
                    when transmit complete;

                transition Receiving
                    then Idle
                    when receive complete;

                transition Idle
                    then Idle
                    when powerManager.sleepMode == true;

                transition Connected
                    then Scanning
                    when beaconPort.beacon lost;
            }

            transition Connected
                then PoweredOff
                when batteryLevel <= 0.0;

            state PoweredOff {
                entry;
            }
        }

        connection processorToRadio connect processor to radioTransceiver;
        connection powerToProcessor connect powerManager to processor;
        connection powerToRadio connect powerManager to radioTransceiver;
        connection fhssToRadio connect fhssSynchronizer to radioTransceiver;
    }

    // ===== HomeRF Network System =====

    part def HomeRFNetwork {

        attribute networkName : String = "HomeRF_Home_Network";
        attribute operatingBand : FrequencyValue = 2.4e9;
        attribute maxDevices : Integer = 127;

        part controlPoint : ControlPoint;
        part devices : WirelessDevice[0..127];

        connection beaconBroadcast connect controlPoint.beaconPort to devices[*].beaconPort;
        connection rfAirLink connect controlPoint.rfPort to devices[*].rfPort;
        connection associationLink connect controlPoint.assocPort to devices[*].assocPort;
        connection voiceLink connect controlPoint.voicePort to devices[*].voicePort;
        connection dataLink connect controlPoint.dataPort to devices[*].dataPort;
    }

    // ===== Requirements =====

    requirement def HomeRFRequirement {
        subject network : HomeRFNetwork;
    }

    requirement OperatesIn2_4GHzBand :> HomeRFRequirement {
        doc /* The system shall operate in the 2.4 GHz ISM radio band. */
        constraint { network.operatingBand == 2.4e9 }
    }

    requirement SupportsUpTo127Devices :> HomeRFRequirement {
        doc /* A single Control Point shall support up to 127 wireless devices. */
        constraint { network.controlPoint.maxDevices == 127 }
    }

    requirement UsesFHSS :> HomeRFRequirement {
        doc /* The system shall use Frequency Hopping Spread Spectrum with synchronous hopping. */
        constraint { network.controlPoint.fhssEngine.hopSequence.hopRate >= 50.0 }
    }

    requirement BroadcastsBeacon :> HomeRFRequirement {
        doc /* The Control Point shall broadcast a beacon frame for discovery and synchronization. */
        constraint { network.controlPoint.beaconGenerator.active == true }
    }

    requirement AuthenticatesDevices :> HomeRFRequirement {
        doc /* The Control Point MAC controller shall authenticate devices before association. */
        constraint { network.controlPoint.macController.authenticatedDevices.size() <= 127 }
    }

    requirement AssignsTimeSlots :> HomeRFRequirement {
        doc /* The Control Point shall assign time slots for voice and data traffic. */
        constraint { network.controlPoint.slotDuration > 0.0 }
    }

    requirement VoiceAndDataCoexist :> HomeRFRequirement {
        doc /* Voice traffic shall be processed by a dedicated codec and data by a router. */
        constraint { network.controlPoint.voiceCodec.codecType == "G.711" }
        constraint { network.controlPoint.dataRouter.queueDepth > 0 }
    }

    requirement SecuresCommunications :> HomeRFRequirement {
        doc /* All communications shall be encrypted. */
        constraint { network.controlPoint.encryptionEngine.algorithm == "AES" }
        constraint { network.controlPoint.securityLevel == SecurityLevel::strong }
    }

    requirement DevicePowerManagement :> HomeRFRequirement {
        doc /* Wireless devices shall enter sleep mode when not actively communicating. */
        constraint { network.devices[*].powerManager.sleepMode == true or
                     network.devices[*].powerManager.idleThreshold > 0.0 }
    }

    requirement DeviceLifecycleStates :> HomeRFRequirement {
        doc /* Each device shall scan, associate, and operate in connected state. */
        constraint { network.devices[*].DeviceLifecycle.Scanning.exists() }
        constraint { network.devices[*].DeviceLifecycle.Associating.exists() }
        constraint { network.devices[*].DeviceLifecycle.Connected.exists() }
    }

    requirement SynchronousHopping :> HomeRFRequirement {
        doc /* All devices shall hop frequencies synchronously with the Control Point. */
        constraint { network.devices[*].fhssSynchronizer.synchronized == true }
    }

}
