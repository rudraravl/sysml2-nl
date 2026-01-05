package 'Radar Gun System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RadarFrequency :> ISQ::FrequencyValue;
    attribute def DopplerShift :> ISQ::FrequencyValue;
    attribute def TargetSpeed :> ISQ::SpeedValue;
    attribute def SignalPower :> ISQ::PowerValue;
    attribute def TargetDistance :> ISQ::LengthValue;
    attribute def SignalPhase :> Real;
    
    attribute def TriggerPress;
    attribute def PowerOn;
    attribute def PowerOff;
    attribute def CalibrationMode;
    
    item def RadarPulse {
        attribute frequency : RadarFrequency;
        attribute power : SignalPower;
        attribute phase : SignalPhase;
        attribute emissionTime : ISQ::TimeValue;
    }
    
    item def EchoSignal {
        attribute frequency : RadarFrequency;
        attribute power : SignalPower;
        attribute phase : SignalPhase;
        attribute receptionTime : ISQ::TimeValue;
    }
    
    item def SpeedReading {
        attribute speed : TargetSpeed;
        attribute confidence : Real;
        attribute timestamp : ISQ::TimeValue;
        attribute distance : TargetDistance;
    }
    
    port def AntennaPort {
        out item transmit : RadarPulse;
        in item receive : EchoSignal;
    }
    
    port def DisplayPort {
        in item reading : SpeedReading;
    }
    
    port def TriggerPort {
        in item trigger : TriggerPress;
    }
    
    port def PowerPort {
        in item powerSignal : PowerOn;
        in item shutdownSignal : PowerOff;
    }
    
    part def TransmitterModule {
        attribute carrierFrequency : RadarFrequency;
        attribute transmitPower : SignalPower;
        port antennaOut : AntennaPort;
        
        action generatePulse {
            in frequency : RadarFrequency;
            in power : SignalPower;
            out pulse : RadarPulse;
        }
    }
    
    part def ReceiverModule {
        attribute sensitivity : SignalPower;
        attribute noiseFloor : SignalPower;
        port antennaIn : AntennaPort;
        
        action captureEcho {
            in echo : EchoSignal;
            out processedEcho : EchoSignal;
        }
        
        action filterNoise {
            in rawSignal : EchoSignal;
            out cleanSignal : EchoSignal;
        }
    }
    
    part def SignalProcessingUnit {
        attribute referenceFrequency : RadarFrequency;
        attribute speedOfLight : ISQ::SpeedValue;
        
        action measureDopplerShift {
            in transmitted : RadarPulse;
            in received : EchoSignal;
            out dopplerShift : DopplerShift;
        }
        
        action computeSpeed {
            in dopplerShift : DopplerShift;
            in carrierFrequency : RadarFrequency;
            out targetSpeed : TargetSpeed;
        }
        
        action estimateDistance {
            in transmitted : RadarPulse;
            in received : EchoSignal;
            out distance : TargetDistance;
        }
        
        action validateReading {
            in speed : TargetSpeed;
            in distance : TargetDistance;
            out isValid : Boolean;
        }
    }
    
    part def DisplayModule {
        attribute displayPrecision : Real;
        attribute units : String;
        port dataInput : DisplayPort;
        
        action showSpeed {
            in reading : SpeedReading;
        }
        
        action showError {
            in errorCode : Integer;
        }
    }
    
    part def PowerSupply {
        attribute batteryVoltage : Real;
        attribute batteryCapacity : ISQ::EnergyValue;
        attribute currentDraw : ISQ::ElectricCurrentValue;
        
        action providePower {
            out voltage : Real;
            out current : ISQ::ElectricCurrentValue;
        }
        
        action monitorBattery {
            out chargeLevel : Real;
        }
    }
    
    part def ControlUnit {
        port triggerInput : TriggerPort;
        port powerControl : PowerPort;
        
        action processTrigger {
            in trigger : TriggerPress;
            out measurementCommand : Boolean;
        }
        
        action managePowerState {
            in powerOn : PowerOn;
            in powerOff : PowerOff;
            out systemState : String;
        }
    }
    
    part def MovingTarget {
        attribute actualSpeed : TargetSpeed;
        attribute position : TargetDistance;
        attribute reflectivity : Real;
        
        action reflectRadarSignal {
            in incident : RadarPulse;
            out reflected : EchoSignal;
        }
    }
    
    action def MeasureTargetSpeed {
        in triggerCommand : TriggerPress;
        in carrierFrequency : RadarFrequency;
        in transmitPower : SignalPower;
        out speedMeasurement : SpeedReading;
    }
    
    part radarGunSystem {
        doc /* A handheld radar gun system that measures the speed of moving targets 
               by transmitting radio frequency pulses, analyzing the Doppler shift in 
               reflected signals, and displaying the calculated velocity. */
        
        attribute operatingFrequency : RadarFrequency = 24.15e9 [SI::Hz];
        attribute maxDetectionRange : TargetDistance = 500.0 [SI::m];
        attribute measurementAccuracy : TargetSpeed = 1.0 [SI::'m/s'];
        attribute minDetectableSpeed : TargetSpeed = 1.4 [SI::'m/s'];
        attribute maxMeasurableSpeed : TargetSpeed = 111.0 [SI::'m/s'];
        
        port userTrigger : TriggerPort;
        port powerInterface : PowerPort;
        port displayOutput : DisplayPort;
        
        part transmitter : TransmitterModule {
            attribute :>> carrierFrequency = radarGunSystem::operatingFrequency;
            attribute :>> transmitPower = 0.1 [SI::W];
        }
        
        part receiver : ReceiverModule {
            attribute :>> sensitivity = 0.000001 [SI::W];
            attribute :>> noiseFloor = 0.0000001 [SI::W];
        }
        
        part processor : SignalProcessingUnit {
            attribute :>> referenceFrequency = radarGunSystem::operatingFrequency;
            attribute :>> speedOfLight = 299792458.0 [SI::'m/s'];
        }
        
        part display : DisplayModule {
            attribute :>> displayPrecision = 0.1;
            attribute :>> units = "km/h";
        }
        
        part powerSupply : PowerSupply {
            attribute :>> batteryVoltage = 9.0;
            attribute :>> batteryCapacity = 180000.0 [SI::J];
        }
        
        part controller : ControlUnit;
        
        connect transmitter.antennaOut to receiver.antennaIn;
        connect controller.triggerInput to userTrigger;
        connect controller.powerControl to powerInterface;
        connect display.dataInput to displayOutput;
        
        perform action operateRadarGun : MeasureTargetSpeed {
            in triggerCommand = userTrigger.trigger;
            in carrierFrequency = operatingFrequency;
            in transmitPower = transmitter.transmitPower;
            out speedMeasurement : SpeedReading;
            
            first start;
            then merge standbyMode;
            then accept powerUp : PowerOn;
            then action initializeSystem {
                action powerOn : powerSupply.providePower;
                then action calibrate;
            }
            then merge readyState;
            then accept userTrigger : TriggerPress;
            then action performMeasurement {
                action transmitPulse : transmitter.generatePulse {
                    in frequency = carrierFrequency;
                    in power = transmitPower;
                    out pulse : RadarPulse;
                }
                then action waitForEcho;
                then action receiveEcho : receiver.captureEcho {
                    in echo : EchoSignal;
                    out processedEcho : EchoSignal;
                }
                then action filterSignal : receiver.filterNoise {
                    in rawSignal = receiveEcho.processedEcho;
                    out cleanSignal : EchoSignal;
                }
                then action analyzeDoppler : processor.measureDopplerShift {
                    in transmitted = transmitPulse.pulse;
                    in received = filterSignal.cleanSignal;
                    out dopplerShift : DopplerShift;
                }
                then action calculateSpeed : processor.computeSpeed {
                    in dopplerShift = analyzeDoppler.dopplerShift;
                    in carrierFrequency = carrierFrequency;
                    out targetSpeed : TargetSpeed;
                }
                then action calculateDistance : processor.estimateDistance {
                    in transmitted = transmitPulse.pulse;
                    in received = filterSignal.cleanSignal;
                    out distance : TargetDistance;
                }
                then action validate : processor.validateReading {
                    in speed = calculateSpeed.targetSpeed;
                    in distance = calculateDistance.distance;
                    out isValid : Boolean;
                }
                then decide;
                    if validate.isValid then displayResult;
                    if not validate.isValid then showError;
                
                action displayResult {
                    assign speedMeasurement := SpeedReading {
                        speed = calculateSpeed.targetSpeed;
                        confidence = 0.95;
                        timestamp = ISQ::time;
                        distance = calculateDistance.distance;
                    }
                    then action showReading : display.showSpeed {
                        in reading = speedMeasurement;
                    }
                }
                then readyState;
                
                action showError {
                    action displayError : display.showError {
                        in errorCode = 1;
                    }
                }
                then readyState;
            }
            then accept shutdown : PowerOff;
            then done;
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* The radar gun shall measure target speed with specified accuracy. */
        
        subject system : radarGunSystem;
        
        require constraint {
            system.measurementAccuracy <= 0.56 [SI::'m/s']
        }
    }
    
    requirement def RangeRequirement {
        doc /* The radar gun shall detect targets within maximum operational range. */
        
        subject system : radarGunSystem;
        
        require constraint {
            system.maxDetectionRange >= 300.0 [SI::m]
        }
    }
    
    requirement def SpeedRangeRequirement {
        doc /* The radar gun shall measure speeds within specified range. */
        
        subject system : radarGunSystem;
        
        require constraint {
            system.minDetectableSpeed <= 2.8 [SI::'m/s'] and
            system.maxMeasurableSpeed >= 97.2 [SI::'m/s']
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The radar gun shall display measurement within acceptable time. */
        
        attribute maxResponseTime : ISQ::TimeValue = 0.3 [SI::s];
        
        require constraint {
            maxResponseTime <= 0.5 [SI::s]
        }
    }
    
    requirement def PowerEfficiencyRequirement {
        doc /* The radar gun shall operate efficiently on battery power. */
        
        subject system : radarGunSystem;
        
        attribute minOperatingTime : ISQ::TimeValue = 28800.0 [SI::s];
        
        require constraint {
            minOperatingTime >= 21600.0 [SI::s]
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for radar gun system functionality and performance. */
        
        subject radarGunSystem;
        
        require requirement accuracyReq : AccuracyRequirement;
        require requirement rangeReq : RangeRequirement;
        require requirement speedRangeReq : SpeedRangeRequirement;
        require requirement responseReq : ResponseTimeRequirement;
        require requirement powerReq : PowerEfficiencyRequirement;
    }
}
