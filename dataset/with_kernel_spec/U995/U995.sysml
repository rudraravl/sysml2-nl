package BabyMonitoringSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        item def VideoStream;
        item def AudioStream {
            attribute soundLevel : Real;
        }
        item def SensorData {
            attribute temperature : TemperatureValue;
            attribute motionDetected : Boolean;
        }
        attribute def AlertSignal {
            attribute cryDetected : Boolean;
            attribute motionDetected : Boolean;
            attribute unsafeTemperature : Boolean;
        }

        attribute def 'Activate';
        attribute def 'CryDetected';
        attribute def 'MotionDetected';
        attribute def 'UnsafeTemperature';
        attribute def 'LowBattery';
        attribute def 'AlertClear';
        attribute def 'AlertReceived';

        port def VideoOutPort { out video : VideoStream; }
        port def AudioOutPort { out audio : AudioStream; }
        port def DataOutPort { out data : SensorData; }
        port def AlertOutPort { out alert : AlertSignal; }
        port def VideoInPort { in video : VideoStream; }
        port def AudioInPort { in audio : AudioStream; }
        port def DataInPort { in data : SensorData; }
        port def AlertInPort { in alert : AlertSignal; }

        part def Camera {
            attribute resolutionX : Integer = 1920;
            attribute resolutionY : Integer = 1080;
            attribute fieldOfView : PlaneAngleValue = 110;
            attribute nightVisionEnabled : Boolean = true;
            port videoOut : VideoOutPort;
            perform action captureVideo { out video : VideoStream; }
        }
        part def Microphone {
            port audioOut : AudioOutPort;
            perform action captureAudio { out audio : AudioStream; }
        }
        part def SoundAnalyzer {
            attribute threshold : Real = 55;
            port audioIn : AudioInPort;
            port audioOut : AudioOutPort;
            port alertOut : AlertOutPort;
            perform action analyzeSound {
                in audio : AudioStream;
                out processedAudio : AudioStream;
                out alert : AlertSignal;
            }
        }
        part def MotionDetector {
            port dataOut : DataOutPort;
            perform action detectMotion { out data : SensorData; }
        }
        part def TemperatureSensor {
            port dataOut : DataOutPort;
            perform action measureTemperature { out data : SensorData; }
        }
        part def WirelessTransmitter {
            port videoIn : VideoInPort;
            port audioIn : AudioInPort;
            port dataIn : DataInPort;
            port alertIn : AlertInPort;
            port videoOut : VideoOutPort;
            port audioOut : AudioOutPort;
            port dataOut : DataOutPort;
            port alertOut : AlertOutPort;
            perform action transmitData;
        }
        part def WirelessReceiver {
            port videoIn : VideoInPort;
            port audioIn : AudioInPort;
            port dataIn : DataInPort;
            port alertIn : AlertInPort;
            port videoOut : VideoOutPort;
            port audioOut : AudioOutPort;
            port dataOut : DataOutPort;
            port alertOut : AlertOutPort;
            perform action receiveData;
        }
        part def DisplayScreen {
            port videoIn : VideoInPort;
            perform action displayVideo { in video : VideoStream; }
        }
        part def Speaker {
            port audioIn : AudioInPort;
            perform action playAudio { in audio : AudioStream; }
        }
        part def AlertSystem {
            port alertIn : AlertInPort;
            attribute visualAlertEnabled : Boolean = true;
            attribute audibleAlertEnabled : Boolean = true;
            attribute vibrationAlertEnabled : Boolean = true;
            perform action notifyCaregiver { in alert : AlertSignal; }
        }

        action def 'Monitor Environment' {
            out video : VideoStream;
            out audio : AudioStream;
            out data : SensorData;
            out alert : AlertSignal;
        }
        action def 'Stream Data';
        action def 'Receive Data';
        action def 'Display Video' { in video : VideoStream; }
        action def 'Play Audio' { in audio : AudioStream; }
        action def 'Notify Caregiver' { in alert : AlertSignal; }

        state def 'System States';
        state def 'Baby Unit States';
        state def 'Parent Unit States';

        part def BabyUnit {
            perform action 'monitor environment': 'Monitor Environment';
            exhibit state 'baby unit states': 'Baby Unit States';

            port videoOut : VideoOutPort;
            port audioOut : AudioOutPort;
            port dataOut : DataOutPort;
            port alertOut : AlertOutPort;

            part camera : Camera;
            part microphone : Microphone;
            part soundAnalyzer : SoundAnalyzer;
            part motionDetector : MotionDetector;
            part temperatureSensor : TemperatureSensor;
            part transmitter : WirelessTransmitter;

            connect camera.videoOut to transmitter.videoIn;
            connect microphone.audioOut to soundAnalyzer.audioIn;
            connect soundAnalyzer.audioOut to transmitter.audioIn;
            connect soundAnalyzer.alertOut to transmitter.alertIn;
            connect motionDetector.dataOut to transmitter.dataIn;
            connect temperatureSensor.dataOut to transmitter.dataIn;

            connect transmitter.videoOut to videoOut;
            connect transmitter.audioOut to audioOut;
            connect transmitter.dataOut to dataOut;
            connect transmitter.alertOut to alertOut;
        }

        part def ParentUnit {
            perform action 'receive data': 'Receive Data';
            perform action 'display video': 'Display Video';
            perform action 'play audio': 'Play Audio';
            perform action 'notify caregiver': 'Notify Caregiver';
            exhibit state 'parent unit states': 'Parent Unit States';

            port videoIn : VideoInPort;
            port audioIn : AudioInPort;
            port dataIn : DataInPort;
            port alertIn : AlertInPort;

            part receiver : WirelessReceiver;
            part display : DisplayScreen;
            part speaker : Speaker;
            part alertSystem : AlertSystem;

            connect videoIn to receiver.videoIn;
            connect audioIn to receiver.audioIn;
            connect dataIn to receiver.dataIn;
            connect alertIn to receiver.alertIn;

            connect receiver.videoOut to display.videoIn;
            connect receiver.audioOut to speaker.audioIn;
            connect receiver.alertOut to alertSystem.alertIn;
        }

        part def BabyMonitoringSystem {
            part babyUnit : BabyUnit;
            part parentUnit : ParentUnit;

            connect babyUnit.videoOut to parentUnit.videoIn;
            connect babyUnit.audioOut to parentUnit.audioIn;
            connect babyUnit.dataOut to parentUnit.dataIn;
            connect babyUnit.alertOut to parentUnit.alertIn;
        }

        requirement def 'Camera Requirement' {
            doc /* The Baby Unit shall include a high-definition camera with 1920x1080 resolution, automatic night vision, and a 110-degree field of view. */
        }
        requirement def 'Sound Analysis Requirement' {
            doc /* The sound analyzer shall distinguish ambient noise from distress sounds using a 55 dB threshold. */
        }
        requirement def 'Alert System Requirement' {
            doc /* The Parent Unit shall notify the caregiver via visual, audible, and vibrational alerts upon receiving an alert signal. */
        }
        requirement def 'Power Management Requirement' {
            doc /* The system shall operate in active, low-power, and idle states to conserve battery. */
        }
    }

    package Usages {
        private import Definitions::*;

        action 'monitor environment': 'Monitor Environment';
        action 'stream data': 'Stream Data';
        action 'receive data': 'Receive Data';
        action 'display video': 'Display Video';
        action 'play audio': 'Play Audio';
        action 'notify caregiver': 'Notify Caregiver';

        part system : BabyMonitoringSystem {
            exhibit state 'system states': 'System States' parallel {
                state 'baby unit states': 'Baby Unit States' {
                    entry; then Idle;
                    state Idle;
                    accept 'Activate' then ActiveMonitoring;
                    state ActiveMonitoring {
                        do 'monitor environment';
                        do 'stream data';
                    }
                    accept 'CryDetected' then Alerting;
                    accept 'MotionDetected' then Alerting;
                    accept 'UnsafeTemperature' then Alerting;
                    accept 'LowBattery' then LowPower;
                    state Alerting {
                        do 'stream data';
                    }
                    accept 'AlertClear' then ActiveMonitoring;
                    state LowPower;
                    accept 'Activate' then ActiveMonitoring;
                }
                state 'parent unit states': 'Parent Unit States' {
                    entry; then Standby;
                    state Standby;
                    accept 'Activate' then ActiveReceiving;
                    state ActiveReceiving {
                        do 'receive data';
                        do 'display video';
                        do 'play audio';
                    }
                    accept 'AlertReceived' then Alerting;
                    accept 'LowBattery' then LowPower;
                    state Alerting {
                        do 'notify caregiver';
                    }
                    accept 'AlertClear' then ActiveReceiving;
                    state LowPower;
                    accept 'Activate' then ActiveReceiving;
                }
            }
        }

        requirement 'Camera Spec' : 'Camera Requirement';
        requirement 'Sound Analysis Spec' : 'Sound Analysis Requirement';
        requirement 'Alert System Spec' : 'Alert System Requirement';
        requirement 'Power Management Spec' : 'Power Management Requirement';
    }
}
