package EsophagealDopplerMonitoringSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def BloodVelocityValue :> SpeedValue {
        doc /* Peak blood flow velocity in descending aorta measured in cm/s */
    }

    attribute def StrokeVolumeValue :> VolumeValue {
        doc /* Volume of blood ejected per heartbeat in milliliters */
    }

    attribute def CardiacOutputValue :> VolumeFlowRateValue {
        doc /* Total blood volume pumped per minute in liters/min */
    }

    attribute def AorticDiameterValue :> LengthValue {
        doc /* Estimated diameter of descending thoracic aorta */
    }

    attribute def HeartRateValue :> FrequencyValue {
        doc /* Heart rate in beats per minute */
    }

    attribute def FlowTimeValue :> TimeValue {
        doc /* Duration of systolic flow corrected for heart rate */
    }

    attribute def DopplerFrequencyShiftValue :> FrequencyValue {
        doc /* Frequency shift of reflected ultrasound due to blood flow */
    }

    attribute def UltrasoundFrequencyValue :> FrequencyValue {
        doc /* Transmitted ultrasound carrier frequency, typically 4-5 MHz */
    }

    attribute def ProbeDepthValue :> LengthValue {
        doc /* Insertion depth of esophageal probe from incisors */
    }

    attribute def SignalQualityIndexValue :> Real {
        doc /* Quality metric for Doppler signal, range 0-100 */
    }

    item def UltrasoundPulse {
        attribute frequency : UltrasoundFrequencyValue;
        attribute amplitude : PressureValue;
        attribute duration : TimeValue;
    }

    item def DopplerEcho {
        attribute frequencyShift : DopplerFrequencyShiftValue;
        attribute signalStrength : Real;
        attribute timestamp : TimeValue;
    }

    item def VelocityWaveform {
        attribute peakVelocity : BloodVelocityValue;
        attribute meanVelocity : BloodVelocityValue;
        attribute flowTime : FlowTimeValue;
    }

    item def HemodynamicParameters {
        attribute cardiacOutput : CardiacOutputValue;
        attribute strokeVolume : StrokeVolumeValue;
        attribute heartRate : HeartRateValue;
        attribute correctedFlowTime : FlowTimeValue;
        attribute peakVelocity : BloodVelocityValue;
    }

    item def PatientData {
        attribute age : TimeValue;
        attribute height : LengthValue;
        attribute weight : MassValue;
        attribute estimatedAorticDiameter : AorticDiameterValue;
    }

    port def UltrasoundTransmitPort {
        out pulse : UltrasoundPulse;
    }

    port def UltrasoundReceivePort {
        in echo : DopplerEcho;
    }

    port def AnalogSignalPort {
        in out rawSignal : Real;
    }

    port def DigitalDataPort {
        in out data : HemodynamicParameters;
    }

    port def PowerPort {
        in voltage : ISQ::ElectricPotentialValue;
        in current : ISQ::ElectricCurrentValue;
    }

    port def UserInterfacePort {
        in commands : String;
        out status : String;
    }

    part def EsophagealProbe {
        doc /* Flexible probe inserted through esophagus to position ultrasound transducer adjacent to descending aorta */
        
        attribute probeLength : LengthValue = 90[SI::cm];
        attribute probeDiameter : LengthValue = 6[SI::mm];
        attribute transducerAngle : Real = 45.0;
        
        port transmitPort : UltrasoundTransmitPort;
        port receivePort : UltrasoundReceivePort;
        port signalPort : AnalogSignalPort;
    }

    part def UltrasoundTransducer {
        doc /* Piezoelectric element that generates and detects ultrasound waves */
        
        attribute operatingFrequency : UltrasoundFrequencyValue = 4000000.0[SI::Hz];
        attribute beamWidth : Real = 15.0;
        
        port txPort : UltrasoundTransmitPort;
        port rxPort : UltrasoundReceivePort;
    }

    part def SignalProcessingUnit {
        doc /* Processes Doppler-shifted ultrasound echoes to extract velocity information */
        
        attribute samplingRate : FrequencyValue = 20000.0[SI::Hz];
        attribute filterCutoff : FrequencyValue = 2000.0[SI::Hz];
        
        port analogInput : AnalogSignalPort;
        port digitalOutput : DigitalDataPort;
        port powerInput : PowerPort;
    }

    part def HemodynamicCalculator {
        doc /* Computes cardiac output and related parameters from velocity waveforms */
        
        port dataInput : DigitalDataPort;
        port dataOutput : DigitalDataPort;
    }

    part def DisplayUnit {
        doc /* Visual display showing real-time waveforms and calculated hemodynamic values */
        
        attribute screenSize : LengthValue = 12.0[SI::cm];
        attribute refreshRate : FrequencyValue = 60[SI::Hz];
        
        port dataInput : DigitalDataPort;
        port userInterface : UserInterfacePort;
        port powerInput : PowerPort;
    }

    part def ControlModule {
        doc /* Manages system operation, user inputs, and safety monitoring */
        
        port controlOutput : UserInterfacePort;
        port dataMonitor : DigitalDataPort;
        port powerInput : PowerPort;
    }

    part def PowerSupply {
        doc /* Provides regulated electrical power to all system components */
        
        attribute outputVoltage : ISQ::ElectricPotentialValue = 12[SI::V];
        attribute maxCurrent : ISQ::ElectricCurrentValue = 5[SI::A];
        
        port mainPower : PowerPort;
        port processorPower : PowerPort;
        port displayPower : PowerPort;
        port controlPower : PowerPort;
    }

    action def TransmitUltrasound {
        in frequency : UltrasoundFrequencyValue;
        in pulseRepetitionRate : FrequencyValue;
        out transmittedPulse : UltrasoundPulse;
    }

    action def ReceiveEcho {
        in reflectedSignal;
        out dopplerEcho : DopplerEcho;
    }

    action def FilterSignal {
        in rawEcho : DopplerEcho;
        in filterBandwidth : FrequencyValue;
        out filteredSignal;
    }

    action def ExtractVelocity {
        in dopplerShift : DopplerFrequencyShiftValue;
        in transmitFrequency : UltrasoundFrequencyValue;
        in beamAngle : Real;
        out bloodVelocity : BloodVelocityValue;
    }

    action def GenerateWaveform {
        in velocityData : BloodVelocityValue[*];
        in timeData : TimeValue[*];
        out waveform : VelocityWaveform;
    }

    action def EstimateAorticDiameter {
        in patientHeight : LengthValue;
        in patientWeight : MassValue;
        in patientAge : TimeValue;
        out aorticDiameter : AorticDiameterValue;
    }

    action def CalculateStrokeVolume {
        in peakVelocity : BloodVelocityValue;
        in flowTime : FlowTimeValue;
        in aorticDiameter : AorticDiameterValue;
        out strokeVolume : StrokeVolumeValue;
    }

    action def CalculateCardiacOutput {
        in strokeVolume : StrokeVolumeValue;
        in heartRate : HeartRateValue;
        out cardiacOutput : CardiacOutputValue;
    }

    action def AssessSignalQuality {
        in echoStrength : Real;
        in noiseLevel : Real;
        out qualityIndex : SignalQualityIndexValue;
    }

    action def DisplayWaveform {
        in waveform : VelocityWaveform;
        out visualDisplay;
    }

    action def DisplayParameters {
        in parameters : HemodynamicParameters;
        out parameterDisplay;
    }

    action def MonitorHemodynamics {
        doc /* Continuous monitoring cycle for real-time hemodynamic assessment */
        
        in patientInfo : PatientData;
        out continuousParameters : HemodynamicParameters;
        
        private attribute currentAorticDiameter : AorticDiameterValue;
        private attribute currentWaveform : VelocityWaveform;
        private attribute signalQuality : SignalQualityIndexValue;
        
        first start;
        
        then action initializeSystem {
            action estimateDiameter : EstimateAorticDiameter {
                in patientHeight = patientInfo.height;
                in patientWeight = patientInfo.weight;
                in patientAge = patientInfo.age;
                out aorticDiameter;
            }
            then assign currentAorticDiameter := estimateDiameter.aorticDiameter;
        }
        
        then merge continuousAcquisition;
        
        then action acquireData {
            action transmit : TransmitUltrasound {
                in frequency = 4000000.0[SI::Hz];
                in pulseRepetitionRate = 5000.0[SI::Hz];
                out transmittedPulse;
            }
            
            flow transmit.transmittedPulse to receive.reflectedSignal;
            
            action receive : ReceiveEcho {
                in reflectedSignal;
                out dopplerEcho;
            }
        }
        
        then action processSignal {
            action filter : FilterSignal {
                in rawEcho = acquireData::receive.dopplerEcho;
                in filterBandwidth = 2000.0[SI::Hz];
                out filteredSignal;
            }
            
            action checkQuality : AssessSignalQuality {
                in echoStrength = acquireData::receive.dopplerEcho.signalStrength;
                in noiseLevel = 10.0;
                out qualityIndex;
            }
            
            then assign signalQuality := checkQuality.qualityIndex;
        }
        
        then decide;
            if signalQuality >= 70.0 then computeHemodynamics;
            if signalQuality < 70.0 then continuousAcquisition;
        
        action computeHemodynamics {
            action extractVel : ExtractVelocity {
                in dopplerShift = acquireData::receive.dopplerEcho.frequencyShift;
                in transmitFrequency = 4000000.0[SI::Hz];
                in beamAngle = 45.0;
                out bloodVelocity;
            }
            
            flow extractVel.bloodVelocity to generateWave.velocityData;
            
            action generateWave : GenerateWaveform {
                in velocityData : BloodVelocityValue[100];
                in timeData : TimeValue[100];
                out waveform;
            }
            
            then assign currentWaveform := generateWave.waveform;
            
            flow generateWave.waveform.peakVelocity to calcSV.peakVelocity;
            flow generateWave.waveform.flowTime to calcSV.flowTime;
            
            action calcSV : CalculateStrokeVolume {
                in peakVelocity;
                in flowTime;
                in aorticDiameter = currentAorticDiameter;
                out strokeVolume;
            }
            
            flow calcSV.strokeVolume to calcCO.strokeVolume;
            
            action calcCO : CalculateCardiacOutput {
                in strokeVolume;
                in heartRate = 75.0[SI::Hz];
                out cardiacOutput;
            }
        }
        
        then action updateDisplay {
            action showWaveform : DisplayWaveform {
                in waveform = currentWaveform;
                out visualDisplay;
            }
            
            action showParams : DisplayParameters {
                in parameters {
                    attribute cardiacOutput = computeHemodynamics::calcCO.cardiacOutput;
                    attribute strokeVolume = computeHemodynamics::calcSV.strokeVolume;
                    attribute heartRate = 75.0[SI::Hz];
                    attribute correctedFlowTime = currentWaveform.flowTime;
                    attribute peakVelocity = currentWaveform.peakVelocity;
                }
                out parameterDisplay;
            }
        }
        
        then continuousAcquisition;
    }

    state def SystemOperationalStates {
        doc /* State machine governing system operational modes */
        
        entry; then powerOn;
        
        state powerOn {
            doc /* System powered and performing self-test */
        }
        
        transition powerOn_to_standby
            first powerOn
            if "self-test passed"
            then standby;
        
        state standby {
            doc /* System ready but not actively monitoring */
        }
        
        transition standby_to_calibrating
            first standby
            accept StartCalibration
            then calibrating;
        
        state calibrating {
            doc /* Calibrating transducer and establishing baseline */
        }
        
        transition calibrating_to_monitoring
            first calibrating
            if "calibration complete"
            then monitoring;
        
        state monitoring {
            doc /* Active hemodynamic monitoring in progress */
            
            state acquiring {
                doc /* Transmitting ultrasound and receiving echoes */
            }
            
            state processing {
                doc /* Processing Doppler signals and extracting velocities */
            }
            
            state calculating {
                doc /* Computing hemodynamic parameters */
            }
            
            state displaying {
                doc /* Updating display with current measurements */
            }
            
            transition acquiring_to_processing
                first acquiring
                if "echo received"
                then processing;
            
            transition processing_to_calculating
                first processing
                if "velocity extracted"
                then calculating;
            
            transition calculating_to_displaying
                first calculating
                if "parameters computed"
                then displaying;
            
            transition displaying_to_acquiring
                first displaying
                then acquiring;
        }
        
        transition monitoring_to_standby
            first monitoring
            accept StopMonitoring
            then standby;
        
        transition monitoring_to_alarm
            first monitoring
            if "signal quality critical"
            then alarm;
        
        state alarm {
            doc /* Alert state for poor signal quality or system fault */
        }
        
        transition alarm_to_monitoring
            first alarm
            if "signal restored"
            then monitoring;
        
        transition alarm_to_standby
            first alarm
            accept AcknowledgeAlarm
            then standby;
    }

    requirement def SystemRequirement;
    requirement def PerformanceRequirement :> SystemRequirement;
    requirement def SafetyRequirement :> SystemRequirement;
    requirement def UsabilityRequirement :> SystemRequirement;

    requirement <'REQ-001'> primaryFunction : SystemRequirement {
        doc /* 
            The Esophageal Doppler Monitoring System shall measure blood flow 
            velocity in the descending thoracic aorta using Doppler ultrasound 
            to calculate and display real-time hemodynamic parameters including 
            cardiac output, stroke volume, and corrected flow time.
        */
        subject system : EsophagealDopplerSystem;
    }

    requirement <'REQ-002'> measurementAccuracy : PerformanceRequirement {
        doc /* 
            The system shall measure cardiac output with an accuracy of ±10% 
            compared to reference thermodilution methods.
        */
        require constraint {
            doc /* Cardiac output accuracy within ±10% */
        }
    }

    requirement <'REQ-003'> continuousMonitoring : PerformanceRequirement {
        doc /* 
            The system shall provide continuous real-time monitoring with 
            display refresh rate of at least 1 Hz.
        */
        require constraint {
            doc /* Display update frequency >= 1 Hz */
        }
    }

    requirement <'REQ-004'> signalQualityThreshold : PerformanceRequirement {
        doc /* 
            The system shall maintain Doppler signal quality index above 70 
            for reliable hemodynamic measurements.
        */
        require constraint {
            doc /* Signal quality index >= 70 */
        }
    }

    requirement <'REQ-005'> probeSafety : SafetyRequirement {
        doc /* 
            The esophageal probe shall have a maximum diameter of 6mm and 
            flexible construction to minimize patient discomfort and risk 
            of esophageal trauma.
        */
        require constraint {
            doc /* Probe diameter <= 6mm, flexible material */
        }
    }

    requirement <'REQ-006'> ultrasoundSafety : SafetyRequirement {
        doc /* 
            The ultrasound output shall comply with FDA limits for diagnostic 
            ultrasound with spatial peak temporal average intensity below 
            720 mW/cm².
        */
        require constraint {
            doc /* ISPTA < 720 mW/cm² */
        }
    }

    requirement <'REQ-007'> displayCompleteness : UsabilityRequirement {
        doc /* 
            The display shall simultaneously show velocity waveform, cardiac 
            output, stroke volume, heart rate, and corrected flow time.
        */
        require constraint {
            doc /* All parameters displayed concurrently */
        }
    }

    requirement <'REQ-008'> responseTime : PerformanceRequirement {
        doc /* 
            The system shall display updated hemodynamic parameters within 
            2 seconds of signal acquisition.
        */
        require constraint {
            doc /* Processing latency <= 2 seconds */
        }
    }

    part def EsophagealDopplerSystem {
        doc /* 
            Minimally invasive hemodynamic monitoring system utilizing 
            esophageal Doppler ultrasound to measure aortic blood flow 
            for real-time assessment of cardiac output and fluid responsiveness.
        */
        
        satisfy primaryFunction;
        satisfy measurementAccuracy;
        satisfy continuousMonitoring;
        satisfy signalQualityThreshold;
        satisfy probeSafety;
        satisfy ultrasoundSafety;
        satisfy displayCompleteness;
        satisfy responseTime;
        
        part probe : EsophagealProbe;
        part transducer : UltrasoundTransducer;
        part processor : SignalProcessingUnit;
        part calculator : HemodynamicCalculator;
        part display : DisplayUnit;
        part controller : ControlModule;
        part power : PowerSupply;
        
        connection probeToTransducer connect probe.transmitPort to transducer.txPort;
        connection transducerToProbe connect transducer.rxPort to probe.receivePort;
        connection probeToProcessor connect probe.signalPort to processor.analogInput;
        connection processorToCalculator connect processor.digitalOutput to calculator.dataInput;
        connection calculatorToDisplay connect calculator.dataOutput to display.dataInput;
        connection controllerToDisplay connect controller.controlOutput to display.userInterface;
        connection calculatorToController connect calculator.dataOutput to controller.dataMonitor;
        
        connection powerToProcessor connect power.processorPower to processor.powerInput;
        connection powerToDisplay connect power.displayPower to display.powerInput;
        connection powerToController connect power.controlPower to controller.powerInput;
        
        perform action monitoring : MonitorHemodynamics {
            in patientInfo {
                attribute age = 55[SI::year];
                attribute height = 175[SI::cm];
                attribute weight = 75[SI::kg];
                attribute estimatedAorticDiameter = 2.5[SI::cm];
            }
            out continuousParameters;
        }
        
        exhibit state operationalStates : SystemOperationalStates;
    }

    part clinicalSystem : EsophagealDopplerSystem {
        doc /* Deployed clinical system instance for perioperative hemodynamic monitoring */
    }
}
