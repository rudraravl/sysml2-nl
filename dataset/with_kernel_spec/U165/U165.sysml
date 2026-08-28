package BiophoneModel {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        item def VitalSigns {
            attribute heartRate :> ISQ::frequency;
            attribute bodyTemp :> ISQ::temperature;
            attribute bloodPressureSystolic :> ISQ::pressure;
            attribute bloodPressureDiastolic :> ISQ::pressure;
            attribute bloodOxygenSaturation :> Real;
        }
        item def ProcessedVitalSigns;
        item def AudioStream;
        
        attribute def AlertSignal;
        attribute def LowPowerSignal;
        attribute def AbnormalVitalsSignal;
        attribute def StartMonitoringSignal;
        attribute def StopMonitoringSignal;
        attribute def CallStartSignal;
        attribute def CallEndSignal;
        
        port def SensorDataPort {
            out vitalSigns : VitalSigns;
        }
        port def ProcessedDataPort {
            out processedVitalSigns : ProcessedVitalSigns;
        }
        port def WirelessDataPort {
            out data : ProcessedVitalSigns;
            in response : AudioStream;
        }
        port def AudioPort {
            out audio : AudioStream;
            in incomingAudio : AudioStream;
        }
        port def PowerPort {
            attribute voltage :> ISQ::electricPotential;
        }
        
        part def Biophone {
            port sensorPort : SensorDataPort;
            port wirelessPort : WirelessDataPort;
            port userAudioPort : AudioPort;
            port powerPort : PowerPort;
            
            attribute batteryLevel :> ISQ::energy;
            attribute maxBatteryLevel :> ISQ::energy;
            
            exhibit state biophoneStates;
        }
        part def BiomedicalSensorArray {
            port dataOut : SensorDataPort;
            port powerIn : PowerPort;
        }
        part def SignalProcessingUnit {
            port dataIn : SensorDataPort;
            port dataOut : ProcessedDataPort;
            port powerIn : PowerPort;
        }
        part def WirelessCommunicationModule {
            port dataIn : ProcessedDataPort;
            port wirelessOut : WirelessDataPort;
            port audioOut : AudioPort;
            port powerIn : PowerPort;
        }
        part def RechargeableBattery {
            port powerOut : PowerPort;
            attribute capacity :> ISQ::energy;
            attribute currentCharge :> ISQ::energy;
        }
        part def UserControlInterface {
            port audioIn : AudioPort;
            port powerIn : PowerPort;
            attribute displayStatus : String;
        }
        part def RemoteMonitoringStation {
            port wirelessIn : WirelessDataPort;
        }
        
        action def MonitorVitals;
        action def TransmitData;
        action def VoiceCommunicate;
        action def AlertProvider;
        
        state def BiophoneStates;
        
        requirement def BatteryLifeRequirement {
            doc /* The battery must support at least 24 hours of continuous operation. */
        }
        requirement def MonitoringRequirement {
            doc /* The device must continuously monitor vital signs. */
        }
        requirement def AlertingRequirement {
            doc /* The device shall automatically enter an alerting state upon detection of abnormal vital signs. */
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        action monitorVitals : MonitorVitals;
        action transmitData : TransmitData;
        action voiceCommunicate : VoiceCommunicate;
        action alertProvider : AlertProvider;
        
        part biophoneSystem : Biophone {
            part sensorArray : BiomedicalSensorArray;
            part processingUnit : SignalProcessingUnit;
            part commModule : WirelessCommunicationModule;
            part battery : RechargeableBattery;
            part userInterface : UserControlInterface;
            
            connect sensorArray.dataOut to processingUnit.dataIn;
            connect processingUnit.dataOut to commModule.dataIn;
            connect commModule.audioOut to userInterface.audioIn;
            connect battery.powerOut to sensorArray.powerIn;
            connect battery.powerOut to processingUnit.powerIn;
            connect battery.powerOut to commModule.powerIn;
            connect battery.powerOut to userInterface.powerIn;
            
            part remoteStation : RemoteMonitoringStation;
            connect wirelessPort to remoteStation.wirelessIn;
        }
        
        state biophoneStates : BiophoneStates parallel {
            state operationalStates {
                entry; then idle;
                state idle;
                accept StartMonitoringSignal
                    then monitoring;
                state monitoring {
                    do monitorVitals;
                    do transmitData;
                    accept CallStartSignal
                        then communicating;
                    accept AbnormalVitalsSignal
                        then alerting;
                    accept LowPowerSignal
                        then lowPower;
                }
                state communicating {
                    do voiceCommunicate;
                    accept CallEndSignal
                        then monitoring;
                }
                state alerting {
                    do alertProvider;
                    accept StopMonitoringSignal
                        then idle;
                }
                state lowPower {
                    do monitorVitals;
                    accept StartMonitoringSignal
                        then monitoring;
                }
            }
        }
        
        requirement batteryReq : BatteryLifeRequirement;
        requirement monitoringReq : MonitoringRequirement;
        requirement alertingReq : AlertingRequirement;
    }
}
