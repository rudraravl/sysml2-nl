package BabyMonitoringSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def ResolutionWidth :> Integer { unit "pixel" }
    value def ResolutionHeight :> Integer { unit "pixel" }
    value def FieldOfView :> Real { unit "deg" }
    value def SoundLevel :> Real { unit "dB" }
    value def TemperatureValue :> Real { unit "°C" }
    value def MotionIntensity :> Real { unit "g" }
    value def BatteryLevel :> Real { unit "%" }
    value def FrameRate :> Real { unit "fps" }
    value def Frequency :> Real { unit "Hz" }

    // ===== Item Definitions =====
    item def VideoStream {
        attribute width : ResolutionWidth = 1920;
        attribute height : ResolutionHeight = 1080;
        attribute frameRate : FrameRate = 30;
        attribute nightVisionEnabled : Boolean;
    }

    item def AudioStream {
        attribute level : SoundLevel;
        attribute isDistress : Boolean;
    }

    item def SensorReading {
        attribute timestamp : DateTime;
    }

    item def TemperatureReading :> SensorReading {
        attribute value : TemperatureValue;
        attribute isUnsafe : Boolean;
    }

    item def MotionReading :> SensorReading {
        attribute intensity : MotionIntensity;
        attribute detected : Boolean;
    }

    item def AlertSignal {
        attribute alertType : AlertType;
        attribute severity : AlertSeverity;
        attribute timestamp : DateTime;
    }

    enum def AlertType { cry, motion, unsafeTemp, lowBattery, connectionLost }
    enum def AlertSeverity { low, medium, high, critical }

    item def TelemetryPacket {
        attribute video : VideoStream;
        attribute audio : AudioStream;
        attribute temperature : TemperatureReading;
        attribute motion : MotionReading;
        attribute batteryLevel : BatteryLevel;
    }

    // ===== Port Definitions =====
    port def VideoOutPort { out video : VideoStream; }
    port def AudioOutPort { out audio : AudioStream; }
    port def TempOutPort { out tempReading : TemperatureReading; }
    port def MotionOutPort { out motionReading : MotionReading; }
    port def TelemetryOutPort { out telemetry : TelemetryPacket; }
    port def TelemetryInPort { in telemetry : TelemetryPacket; }
    port def AlertOutPort { out alert : AlertSignal; }
    port def AlertInPort { in alert : AlertSignal; }
    port def WirelessOutPort { out telemetry : TelemetryPacket; out alert : AlertSignal; }
    port def WirelessInPort { in telemetry : TelemetryPacket; in alert : AlertSignal; }

    // ===== Baby Unit Components =====
    part def Camera {
        attribute resolutionWidth : ResolutionWidth = 1920;
        attribute resolutionHeight : ResolutionHeight = 1080;
        attribute fieldOfView : FieldOfView = 110;
        attribute nightVisionEnabled : Boolean = false;
        port videoOut : VideoOutPort;
        attribute ambientLightLevel : Real;

        action def CaptureVideo :> Action {
            out capturedVideo : VideoStream;
        }

        perform action captureVideo : CaptureVideo {
            if ambientLightLevel < 10.0 then {
                nightVisionEnabled = true;
            } else {
                nightVisionEnabled = false;
            }
            capturedVideo.width = resolutionWidth;
            capturedVideo.height = resolutionHeight;
            capturedVideo.nightVisionEnabled = nightVisionEnabled;
            videoOut.video = capturedVideo;
        }
    }

    part def Microphone {
        attribute sensitivity : SoundLevel = 30;
        port audioOut : AudioOutPort;
        attribute capturedLevel : SoundLevel;

        action def CaptureAudio :> Action {
            out capturedAudio : AudioStream;
        }

        perform action captureAudio : CaptureAudio {
            capturedAudio.level = capturedLevel;
            capturedAudio.isDistress = false;
            audioOut.audio = capturedAudio;
        }
    }

    part def SoundAnalyzer {
        attribute distressThreshold : SoundLevel = 55;
        in port audioIn : AudioOutPort;
        out port analyzedAudioOut : AudioOutPort;
        attribute currentLevel : SoundLevel;
        attribute isDistressDetected : Boolean;

        action def AnalyzeAudio :> Action {
            in inputAudio : AudioStream;
            out analyzedAudio : AudioStream;
        }

        perform action analyzeAudio : AnalyzeAudio {
            inputAudio = audioIn.audio;
            currentLevel = inputAudio.level;
            if currentLevel >= distressThreshold then {
                isDistressDetected = true;
            } else {
                isDistressDetected = false;
            }
            analyzedAudio.level = currentLevel;
            analyzedAudio.isDistress = isDistressDetected;
            analyzedAudioOut.audio = analyzedAudio;
        }
    }

    part def MotionDetector {
        attribute sensitivityThreshold : MotionIntensity = 0.5;
        port motionOut : MotionOutPort;
        attribute detectedMotion : Boolean;
        attribute currentIntensity : MotionIntensity;

        action def DetectMotion :> Action {
            out motionReading : MotionReading;
        }

        perform action detectMotion : DetectMotion {
            if currentIntensity >= sensitivityThreshold then {
                detectedMotion = true;
            } else {
                detectedMotion = false;
            }
            motionReading.intensity = currentIntensity;
            motionReading.detected = detectedMotion;
            motionOut.motionReading = motionReading;
        }
    }

    part def TemperatureSensor {
        attribute minSafeTemp : TemperatureValue = 18.0;
        attribute maxSafeTemp : TemperatureValue = 22.0;
        attribute accuracy : Real = 0.1;
        port tempOut : TempOutPort;
        attribute currentTemp : TemperatureValue;

        action def MeasureTemperature :> Action {
            out tempReading : TemperatureReading;
        }

        perform action measureTemperature : MeasureTemperature {
            tempReading.value = currentTemp;
            if currentTemp < minSafeTemp or currentTemp > maxSafeTemp then {
                tempReading.isUnsafe = true;
            } else {
                tempReading.isUnsafe = false;
            }
            tempOut.tempReading = tempReading;
        }
    }

    part def WirelessTransmitter {
        attribute frequency : Frequency = 2.4e9;
        attribute range : Real = 300;
        in port telemetryIn : TelemetryOutPort;
        out port wirelessOut : WirelessOutPort;

        action def TransmitData :> Action {
            in telemetry : TelemetryPacket;
        }

        perform action transmitData : TransmitData {
            telemetry = telemetryIn.telemetry;
            wirelessOut.telemetry = telemetry;
        }
    }

    // ===== Parent Unit Components =====
    part def Display {
        attribute screenWidth : ResolutionWidth = 800;
        attribute screenHeight : ResolutionHeight = 480;
        in port videoIn : VideoOutPort;
        attribute brightness : Real = 50;
        attribute isOn : Boolean = true;

        action def RenderVideo :> Action {
            in video : VideoStream;
        }

        perform action renderVideo : RenderVideo {
            video = videoIn.video;
        }
    }

    part def Speaker {
        attribute maxVolume : SoundLevel = 85;
        attribute currentVolume : SoundLevel = 50;
        in port audioIn : AudioOutPort;
        attribute isMuted : Boolean = false;

        action def PlayAudio :> Action {
            in audio : AudioStream;
        }

        perform action playAudio : PlayAudio {
            audio = audioIn.audio;
            if isMuted == false then {
                // audio played at currentVolume
            }
        }
    }

    part def AlertSystem {
        in port alertIn : AlertInPort;
        attribute visualAlertEnabled : Boolean = true;
        attribute audibleAlertEnabled : Boolean = true;
        attribute vibrationAlertEnabled : Boolean = true;
        attribute activeAlertType : AlertType;
        attribute activeSeverity : AlertSeverity;

        action def NotifyCaregiver :> Action {
            in alert : AlertSignal;
        }

        perform action notifyCaregiver : NotifyCaregiver {
            alert = alertIn.alert;
            activeAlertType = alert.alertType;
            activeSeverity = alert.severity;
            if visualAlertEnabled then {
                // activate visual indicator
            }
            if audibleAlertEnabled then {
                // activate audible alarm
            }
            if vibrationAlertEnabled then {
                // activate vibration motor
            }
        }
    }

    part def WirelessReceiver {
        attribute frequency : Frequency = 2.4e9;
        in port wirelessIn : WirelessInPort;
        out port telemetryOut : TelemetryInPort;
        out port alertOut : AlertInPort;
        attribute signalStrength : Real;

        action def ReceiveData :> Action {
            out telemetry : TelemetryPacket;
            out alert : AlertSignal;
        }

        perform action receiveData : ReceiveData {
            telemetry = wirelessIn.telemetry;
            alert = wirelessIn.alert;
            telemetryOut.telemetry = telemetry;
            alertOut.alert = alert;
        }
    }

    // ===== Baby Unit =====
    part def BabyUnit {
        attribute batteryLevel : BatteryLevel = 100;
        attribute isPowered : Boolean = true;

        port def BabyWirelessPort {
            out telemetry : TelemetryPacket;
            out alert : AlertSignal;
        }

        port wirelessOut : BabyWirelessPort;

        part camera : Camera {
            port videoOut : VideoOutPort;
        }
        part microphone : Microphone {
            port audioOut : AudioOutPort;
        }
        part soundAnalyzer : SoundAnalyzer {
            in port audioIn : AudioOutPort;
            out port analyzedAudioOut : AudioOutPort;
        }
        part motionDetector : MotionDetector {
            port motionOut : MotionOutPort;
        }
        part temperatureSensor : TemperatureSensor {
            port tempOut : TempOutPort;
        }
        part transmitter : WirelessTransmitter {
            in port telemetryIn : TelemetryOutPort;
            out port wirelessOut : WirelessOutPort;
        }

        // Internal data aggregation
        attribute aggregatedTelemetry : TelemetryPacket;
        attribute currentAlert : AlertSignal;

        action def AggregateData :> Action {
            in video : VideoStream;
            in audio : AudioStream;
            in temp : TemperatureReading;
            in motion : MotionReading;
            out telemetry : TelemetryPacket;
        }

        action def EvaluateAlerts :> Action {
            in audio : AudioStream;
            in temp : TemperatureReading;
            in motion : MotionReading;
            out alert : AlertSignal;
        }

        perform action aggregateData : AggregateData {
            video = camera.videoOut.video;
            audio = soundAnalyzer.analyzedAudioOut.audio;
            temp = temperatureSensor.tempOut.tempReading;
            motion = motionDetector.motionOut.motionReading;
            telemetry.video = video;
            telemetry.audio = audio;
            telemetry.temperature = temp;
            telemetry.motion = motion;
            telemetry.batteryLevel = batteryLevel;
            aggregatedTelemetry = telemetry;
            transmitter.telemetryIn.telemetry = telemetry;
        }

        perform action evaluateAlerts : EvaluateAlerts {
            audio = soundAnalyzer.analyzedAudioOut.audio;
            temp = temperatureSensor.tempOut.tempReading;
            motion = motionDetector.motionOut.motionReading;
            if audio.isDistress == true then {
                alert.alertType = AlertType::cry;
                alert.severity = AlertSeverity::high;
            } else if motion.detected == true then {
                alert.alertType = AlertType::motion;
                alert.severity = AlertSeverity::medium;
            } else if temp.isUnsafe == true then {
                alert.alertType = AlertType::unsafeTemp;
                alert.severity = AlertSeverity::critical;
            }
            currentAlert = alert;
            transmitter.wirelessOut.alert = alert;
        }

        // Connections between internal parts
        connection microphone.audioOut to soundAnalyzer.audioIn;
        connection camera.videoOut to transmitter.telemetryIn;
        connection soundAnalyzer.analyzedAudioOut to transmitter.telemetryIn;
        connection motionDetector.motionOut to transmitter.telemetryIn;
        connection temperatureSensor.tempOut to transmitter.telemetryIn;

        // State Machine for Baby Unit
        state def BabyUnitStateMachine {
            state ActiveMonitoring {
                entry {
                    isPowered = true;
                    camera.captureVideo();
                    microphone.captureAudio();
                    soundAnalyzer.analyzeAudio();
                    motionDetector.detectMotion();
                    temperatureSensor.measureTemperature();
                    aggregateData();
                    evaluateAlerts();
                    transmitter.transmitData();
                }
                do {
                    camera.captureVideo();
                    microphone.captureAudio();
                    soundAnalyzer.analyzeAudio();
                    motionDetector.detectMotion();
                    temperatureSensor.measureTemperature();
                    aggregateData();
                    evaluateAlerts();
                    transmitter.transmitData();
                }
            }

            state LowPower {
                entry {
                    camera.frameRate = 5;
                    // reduced sensing frequency
                }
                do {
                    temperatureSensor.measureTemperature();
                    motionDetector.detectMotion();
                    evaluateAlerts();
                }
            }

            state IdleStandby {
                entry {
                    isPowered = false;
                }
                do {
                    // minimal activity, waiting for wake trigger
                }
            }

            transition from ActiveMonitoring to LowPower
                when batteryLevel <= 20;
            transition from LowPower to ActiveMonitoring
                when batteryLevel > 80;
            transition from ActiveMonitoring to IdleStandby
                when batteryLevel <= 5;
            transition from LowPower to IdleStandby
                when batteryLevel <= 5;
            transition from IdleStandby to ActiveMonitoring
                when batteryLevel > 50;
        }

        stateMachine babyUnitStateMachine : BabyUnitStateMachine;

        // Initial state
        // Baby Unit starts in ActiveMonitoring
    }

    // ===== Parent Unit =====
    part def ParentUnit {
        attribute batteryLevel : BatteryLevel = 100;
        attribute isPowered : Boolean = true;

        port def ParentWirelessPort {
            in telemetry : TelemetryPacket;
            in alert : AlertSignal;
        }

        port wirelessIn : ParentWirelessPort;

        part receiver : WirelessReceiver {
            in port wirelessIn : WirelessInPort;
            out port telemetryOut : TelemetryInPort;
            out port alertOut : AlertInPort;
        }
        part display : Display {
            in port videoIn : VideoOutPort;
        }
        part speaker : Speaker {
            in port audioIn : AudioOutPort;
        }
        part alertSystem : AlertSystem {
            in port alertIn : AlertInPort;
        }

        attribute receivedTelemetry : TelemetryPacket;
        attribute receivedAlert : AlertSignal;

        action def ProcessReceivedData :> Action {
            in telemetry : TelemetryPacket;
            in alert : AlertSignal;
        }

        perform action processReceivedData : ProcessReceivedData {
            telemetry = receiver.telemetryOut.telemetry;
            alert = receiver.alertOut.alert;
            receivedTelemetry = telemetry;
            receivedAlert = alert;
            display.videoIn.video = telemetry.video;
            speaker.audioIn.audio = telemetry.audio;
            alertSystem.alertIn.alert = alert;
        }

        // Connections
        connection receiver.telemetryOut to display.videoIn;
        connection receiver.telemetryOut to speaker.audioIn;
        connection receiver.alertOut to alertSystem.alertIn;

        // State Machine for Parent Unit
        state def ParentUnitStateMachine {
            state ActiveMonitoring {
                entry {
                    isPowered = true;
                    receiver.receiveData();
                    processReceivedData();
                    display.renderVideo();
                    speaker.playAudio();
                    if receivedAlert.alertType != null then {
                        alertSystem.notifyCaregiver();
                    }
                }
                do {
                    receiver.receiveData();
                    processReceivedData();
                    display.renderVideo();
                    speaker.playAudio();
                    if receivedAlert.alertType != null then {
                        alertSystem.notifyCaregiver();
                    }
                }
            }

            state LowPower {
                entry {
                    display.brightness = 10;
                    speaker.currentVolume = 20;
                }
                do {
                    receiver.receiveData();
                    processReceivedData();
                    if receivedAlert.alertType != null then {
                        alertSystem.notifyCaregiver();
                    }
                }
            }

            state IdleStandby {
                entry {
                    isPowered = false;
                    display.isOn = false;
                }
                do {
                    // waiting for alert signal to wake
                    receiver.receiveData();
                    if receivedAlert.alertType != null then {
                        alertSystem.notifyCaregiver();
                    }
                }
            }

            transition from ActiveMonitoring to LowPower
                when batteryLevel <= 20;
            transition from LowPower to ActiveMonitoring
                when batteryLevel > 80;
            transition from ActiveMonitoring to IdleStandby
                when batteryLevel <= 5;
            transition from LowPower to IdleStandby
                when batteryLevel <= 5;
            transition from IdleStandby to ActiveMonitoring
                when receivedAlert.alertType != null;
        }

        stateMachine parentUnitStateMachine : ParentUnitStateMachine;
    }

    // ===== System =====
    part def BabyMonitoringSystem {
        part babyUnit : BabyUnit {
            port wirelessOut : BabyUnit::BabyWirelessPort;
        }
        part parentUnit : ParentUnit {
            port wirelessIn : ParentUnit::ParentWirelessPort;
        }

        // Wireless link between Baby Unit and Parent Unit
        connection babyUnit.wirelessOut to parentUnit.wirelessIn;
    }

    // ===== Requirements =====
    requirement def ContinuousMonitoringRequirement {
        doc "The system shall provide continuous, remote surveillance of an infant's environment."
        attribute monitoringInterval : Real = 1.0;
        subject : BabyMonitoringSystem;
        require subject.babyUnit.camera.captureVideo();
        require subject.babyUnit.microphone.captureAudio();
        require subject.babyUnit.temperatureSensor.measureTemperature();
        require subject.babyUnit.motionDetector.detectMotion();
    }

    requirement def VideoQualityRequirement {
        doc "The camera shall provide a 1920x1080 resolution video stream at minimum 30 fps."
        subject : BabyUnit::camera;
        require subject.resolutionWidth == 1920;
        require subject.resolutionHeight == 1080;
        require subject.frameRate >= 30;
    }

    requirement def NightVisionRequirement {
        doc "The camera shall automatically enable night vision in low-light conditions."
        subject : BabyUnit::camera;
        require subject.nightVisionEnabled == true when subject.ambientLightLevel < 10.0;
    }

    requirement def FieldOfViewRequirement {
        doc "The camera shall have a field of view of at least 110 degrees."
        subject : BabyUnit::camera;
        require subject.fieldOfView >= 110;
    }

    requirement def SoundAnalysisRequirement {
        doc "The sound analyzer shall distinguish distress sounds from ambient noise using a 55 dB threshold."
        subject : BabyUnit::soundAnalyzer;
        require subject.distressThreshold == 55;
        require subject.isDistressDetected == true when subject.currentLevel >= subject.distressThreshold;
    }

    requirement def TemperatureMonitoringRequirement {
        doc "The temperature sensor shall monitor room climate and flag unsafe temperatures outside 18-22°C."
        subject : BabyUnit::temperatureSensor;
        require subject.minSafeTemp == 18.0;
        require subject.maxSafeTemp == 22.0;
        require subject.tempOut.tempReading.isUnsafe == true when subject.currentTemp < subject.minSafeTemp or subject.currentTemp > subject.maxSafeTemp;
    }

    requirement def MotionDetectionRequirement {
        doc "The motion detector shall sense activity in the crib above a defined threshold."
        subject : BabyUnit::motionDetector;
        require subject.detectedMotion == true when subject.currentIntensity >= subject.sensitivityThreshold;
    }

    requirement def WirelessTransmissionRequirement {
        doc "The Baby Unit shall wirelessly transmit video, audio, and sensor data to the Parent Unit."
        subject : BabyMonitoringSystem;
        require subject.babyUnit.transmitter.wirelessOut.telemetry != null;
        require subject.parentUnit.receiver.wirelessIn.telemetry != null;
    }

    requirement def AlertNotificationRequirement {
        doc "The Parent Unit shall notify the caregiver of significant events using visual, audible, and vibration alerts."
        subject : ParentUnit::alertSystem;
        require subject.visualAlertEnabled == true;
        require subject.audibleAlertEnabled == true;
        require subject.vibrationAlertEnabled == true;
        require subject.notifyCaregiver() when subject.alertIn.alert.alertType != null;
    }

    requirement def PowerManagementRequirement {
        doc "The system shall support active monitoring, low-power, and idle/standby states."
        subject : BabyMonitoringSystem;
        require subject.babyUnit.babyUnitStateMachine.ActiveMonitoring != null;
        require subject.babyUnit.babyUnitStateMachine.LowPower != null;
        require subject.babyUnit.babyUnitStateMachine.IdleStandby != null;
        require subject.parentUnit.parentUnitStateMachine.ActiveMonitoring != null;
        require subject.parentUnit.parentUnitStateMachine.LowPower != null;
        require subject.parentUnit.parentUnitStateMachine.IdleStandby != null;
    }

    requirement def AlertSignalRequirement {
        doc "The Baby Unit shall send an alert signal when crying, motion, or unsafe temperature is detected."
        subject : BabyUnit;
        require subject.currentAlert.alertType == AlertType::cry when subject.soundAnalyzer.isDistressDetected == true;
        require subject.currentAlert.alertType == AlertType::motion when subject.motionDetector.detectedMotion == true;
        require subject.currentAlert.alertType == AlertType::unsafeTemp when subject.temperatureSensor.tempOut.tempReading.isUnsafe == true;
    }

    requirement def DisplayRequirement {
        doc "The Parent Unit shall display the live video feed from the Baby Unit camera."
        subject : ParentUnit::display;
        require subject.screenWidth >= 800;
        require subject.screenHeight >= 480;
        require subject.isOn == true when subject.videoIn.video != null;
    }

    requirement def SpeakerRequirement {
        doc "The Parent Unit shall play audio from the baby's room through a built-in speaker."
        subject : ParentUnit::speaker;
        require subject.isMuted == false when subject.audioIn.audio != null;
        require subject.currentVolume <= subject.maxVolume;
    }

    // ===== Requirement Satisfaction =====
    satisfaction satisfy ContinuousMonitoringRequirement by BabyMonitoringSystem;
    satisfaction satisfy VideoQualityRequirement by BabyUnit::camera;
    satisfaction satisfy NightVisionRequirement by BabyUnit::camera;
    satisfaction satisfy FieldOfViewRequirement by BabyUnit::camera;
    satisfaction satisfy SoundAnalysisRequirement by BabyUnit::soundAnalyzer;
    satisfaction satisfy TemperatureMonitoringRequirement by BabyUnit::temperatureSensor;
    satisfaction satisfy MotionDetectionRequirement by BabyUnit::motionDetector;
    satisfaction satisfy WirelessTransmissionRequirement by BabyMonitoringSystem;
    satisfaction satisfy AlertNotificationRequirement by ParentUnit::alertSystem;
    satisfaction satisfy PowerManagementRequirement by BabyMonitoringSystem;
    satisfaction satisfy AlertSignalRequirement by BabyUnit;
    satisfaction satisfy DisplayRequirement by ParentUnit::display;
    satisfaction satisfy SpeakerRequirement by ParentUnit::speaker;
}
