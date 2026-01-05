package MetalDetectorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SignalAmplitude :> Real;
    attribute def PhaseShift :> Real;
    attribute def TargetDepth :> LengthValue;
    attribute def Conductivity :> Real;
    
    enum def MetalCategory {
        ferrous;
        nonFerrous;
        stainless;
    }
    
    enum def AlertLevel {
        none;
        low;
        medium;
        high;
    }
    
    item def TransmitSignal {
        attribute frequency : FrequencyValue;
        attribute amplitude : ElectricPotentialValue;
        attribute phase : PhaseShift;
    }
    
    item def ReceiveSignal {
        attribute amplitude : SignalAmplitude;
        attribute phaseShift : PhaseShift;
        attribute frequency : FrequencyValue;
    }
    
    item def DetectionData {
        attribute metalCategory : MetalCategory;
        attribute signalStrength : SignalAmplitude;
        attribute estimatedDepth : TargetDepth;
        attribute confidence : Real;
    }
    
    attribute def PowerCommand;
    attribute def PowerOnCommand :> PowerCommand;
    attribute def PowerOffCommand :> PowerCommand;
    attribute def SensitivityAdjustment;
    attribute def TargetDetected;
    attribute def StrongSignal;
    attribute def SignalWeakened;
    attribute def TargetLost;
    attribute def ScanStart;
    attribute def ScanStop;
    
    port def TransmitCoilPort {
        out txSignal : TransmitSignal;
    }
    
    port def ReceiveCoilPort {
        in rxSignal : ReceiveSignal;
    }
    
    port def ProcessorInputPort {
        in receivedSignal : ReceiveSignal;
    }
    
    port def ProcessorOutputPort {
        out detectionData : DetectionData;
    }
    
    port def AlertOutputPort {
        out alertLevel : AlertLevel;
        out audioTone : FrequencyValue;
        out visualIndication : Boolean;
    }
    
    port def UserInterfacePort {
        in powerCmd : PowerCommand;
        in sensitivityAdj : SensitivityAdjustment;
        out systemStatus : String;
    }
    
    part def TransmitterCoil {
        port txPort : TransmitCoilPort;
        attribute operatingFrequency : FrequencyValue;
        attribute transmitPower : PowerValue;
        
        action generateTransmitSignal {
            in frequency : FrequencyValue;
            in power : PowerValue;
            out signal : TransmitSignal;
        }
    }
    
    part def ReceiverCoil {
        port rxPort : ReceiveCoilPort;
        attribute coilInductance : InductanceValue;
        attribute coilResistance : ResistanceValue;
        
        action captureReceivedSignal {
            in disturbedField : TransmitSignal;
            out signal : ReceiveSignal;
        }
    }
    
    part def SignalProcessingUnit {
        port inputPort : ProcessorInputPort;
        port outputPort : ProcessorOutputPort;
        attribute sensitivityLevel : Real;
        attribute filterCutoffFrequency : FrequencyValue;
        
        action filterSignal {
            in rawSignal : ReceiveSignal;
            out filteredSignal : ReceiveSignal;
        }
        
        action analyzePhaseShift {
            in signal : ReceiveSignal;
            out phaseChange : PhaseShift;
        }
        
        action classifyMetal {
            in phaseChange : PhaseShift;
            in amplitude : SignalAmplitude;
            out category : MetalCategory;
        }
        
        action calculateDepth {
            in signalStrength : SignalAmplitude;
            in sensitivity : Real;
            out depth : TargetDepth;
        }
        
        action determineConfidence {
            in signalQuality : Real;
            out confidence : Real;
        }
    }
    
    part def AlertingSubsystem {
        port alertPort : AlertOutputPort;
        attribute audioEnabled : Boolean;
        attribute visualEnabled : Boolean;
        
        action generateAudioAlert {
            in detectionStrength : SignalAmplitude;
            out toneFrequency : FrequencyValue;
        }
        
        action activateVisualIndicator {
            in alertLevel : AlertLevel;
            out ledState : Boolean;
        }
        
        action determineAlertLevel {
            in detectionData : DetectionData;
            out level : AlertLevel;
        }
    }
    
    part def PowerManagementUnit {
        attribute batteryVoltage : ElectricPotentialValue;
        attribute currentDraw : ElectricCurrentValue;
        attribute remainingCapacity : Real;
        
        action supplyPower {
            out voltage : ElectricPotentialValue;
            out current : ElectricCurrentValue;
        }
        
        action monitorBattery {
            out capacity : Real;
            out status : String;
        }
    }
    
    part def ControlModule {
        port userPort : UserInterfacePort;
        attribute operatingMode : String;
        attribute currentSensitivity : Real;
        
        state powerOff;
        state powerOn {
            entry action initializeSystem;
            
            state standby {
                entry action enterStandbyMode;
                do action monitorUserInput;
            }
            
            state activeScanning {
                entry action activateTransmitter;
                do action performContinuousScan;
                
                state searching {
                    entry action setSearchMode;
                }
                
                state targetAcquired {
                    entry action lockOnTarget;
                    do action trackTarget;
                }
                
                state alerting {
                    entry action triggerAlert;
                    do action maintainAlert;
                }
                
                transition searchToAcquired
                    first searching
                    accept targetDetected : TargetDetected
                    then targetAcquired;
                
                transition acquiredToAlerting
                    first targetAcquired
                    accept strongSignal : StrongSignal
                    then alerting;
                
                transition alertingToAcquired
                    first alerting
                    accept signalWeakened : SignalWeakened
                    then targetAcquired;
                
                transition acquiredToSearch
                    first targetAcquired
                    accept targetLost : TargetLost
                    then searching;
            }
            
            transition standbyToScanning
                first standby
                accept scanStart : ScanStart
                then activeScanning;
            
            transition scanningToStandby
                first activeScanning
                accept scanStop : ScanStop
                then standby;
        }
        
        transition powerOnTransition
            first powerOff
            accept powerOn : PowerOnCommand
            then powerOn;
        
        transition powerOffTransition
            first powerOn
            accept powerOff : PowerOffCommand
            then powerOff;
        
        action adjustSensitivity {
            in adjustment : SensitivityAdjustment;
            in currentLevel : Real;
            out newLevel : Real;
        }
        
        action updateSystemStatus {
            in mode : String;
            in batteryLevel : Real;
            out statusMessage : String;
        }
    }
    
    part def MetalDetector {
        doc /* A metal detector system that identifies and locates metallic objects by 
               detecting disturbances in an electromagnetic field. */
        
        part transmitter : TransmitterCoil {
            attribute :>> operatingFrequency = 8000.0 [SI::Hz];
            attribute :>> transmitPower = 0.5 [SI::W];
        }
        
        part receiver : ReceiverCoil {
            attribute :>> coilInductance = 0.001 [SI::H];
            attribute :>> coilResistance = 10.0 [SI::ohm];
        }
        
        part processor : SignalProcessingUnit {
            attribute :>> sensitivityLevel = 0.8;
            attribute :>> filterCutoffFrequency = 100.0 [SI::Hz];
        }
        
        part alertSystem : AlertingSubsystem {
            attribute :>> audioEnabled = true;
            attribute :>> visualEnabled = true;
        }
        
        part controller : ControlModule {
            attribute :>> operatingMode = "standby";
            attribute :>> currentSensitivity = 0.8;
        }
        
        part powerUnit : PowerManagementUnit {
            attribute :>> batteryVoltage = 9.0 [SI::V];
            attribute :>> currentDraw = 0.3 [SI::A];
            attribute :>> remainingCapacity = 0.75;
        }
        
        connection txToEnvironment
            connect transmitter.txPort to searchEnvironment.fieldInputPort;
        
        connection environmentToRx
            connect searchEnvironment.fieldOutputPort to receiver.rxPort;
        
        connection rxToProcessor
            connect receiver.rxPort to processor.inputPort;
        
        connection processorToAlert
            connect processor.outputPort to alertSystem;
        
        connection controlToProcessor
            connect controller to processor;
        
        connection powerDistribution
            connect powerUnit to transmitter;
        
        connection powerDistribution2
            connect powerUnit to receiver;
        
        connection powerDistribution3
            connect powerUnit to processor;
        
        perform action metalDetectionOperation;
    }
    
    part searchEnvironment {
        port fieldInputPort {
            in transmittedField : TransmitSignal;
        }
        
        port fieldOutputPort {
            out disturbedField : ReceiveSignal;
        }
        
        part searchVolume {
            attribute soilConductivity : Conductivity;
            attribute mineralization : Real;
            
            part targetObjects[0..*] {
                attribute metalType : MetalCategory;
                attribute depth : TargetDepth;
                attribute size : LengthValue;
                attribute orientation : Real;
            }
        }
        
        action interactWithField {
            in transmittedField : TransmitSignal;
            in targets : targetObjects[*];
            out disturbedField : ReceiveSignal;
        }
    }
    
    action def MetalDetectionOperation {
        in sensitivity : Real;
        out detectionResult : DetectionData;
        out alertOutput : AlertLevel;
    }
    
    action metalDetectionOperation : MetalDetectionOperation {
        in sensitivity : Real;
        out detectionResult : DetectionData;
        out alertOutput : AlertLevel;
        
        first start;
        then merge continuousCycle;
        
        then action transmitElectromagneticField {
            out emittedField : TransmitSignal;
        }
        
        then action receiveDisturbedField {
            in emittedField : TransmitSignal;
            out receivedField : ReceiveSignal;
        }
        
        then action processReceivedSignal {
            in receivedField : ReceiveSignal;
            in sensitivitySetting : Real;
            out processedData : DetectionData;
        }
        
        then decide;
            if processReceivedSignal.processedData.confidence > 0.7 then generateAlert;
            if processReceivedSignal.processedData.confidence <= 0.7 then continuousCycle;
        
        action generateAlert {
            action determineAlertIntensity {
                in detection : DetectionData;
                out intensity : AlertLevel;
            }
            
            then action activateAudioVisualAlert {
                in alertIntensity : AlertLevel;
                out audioActive : Boolean;
                out visualActive : Boolean;
            }
            
            then assign alertOutput := determineAlertIntensity.intensity;
        }
        
        then continuousCycle;
        
        accept shutdown : PowerOffCommand;
        then done;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def OperationalRequirement;
    
    requirement primaryFunction : FunctionalRequirement {
        doc /* The metal detector system shall detect the presence of metallic objects 
               by transmitting an electromagnetic field and analyzing disturbances in 
               the received signal caused by conductive materials. */
        
        subject detectorSystem : MetalDetector;
        
        require constraint {
            doc /* The system shall continuously transmit and receive electromagnetic signals 
                   during active operation. */
        }
    }
    
    requirement detectionCapability : PerformanceRequirement {
        doc /* The system shall detect ferrous metals at a minimum depth of 25 cm and 
               non-ferrous metals at a minimum depth of 15 cm in standard soil conditions. */
        
        subject detectorSystem : MetalDetector;
        
        require constraint {
            doc /* Detection depth for a 25mm diameter ferrous object >= 25 cm. */
        }
        
        require constraint {
            doc /* Detection depth for a 25mm diameter non-ferrous object >= 15 cm. */
        }
    }
    
    requirement discriminationCapability : PerformanceRequirement {
        doc /* The system shall discriminate between ferrous, non-ferrous, and stainless 
               steel metals with a minimum accuracy of 80%. */
        
        subject detectorSystem : MetalDetector;
    }
    
    requirement responseTime : PerformanceRequirement {
        doc /* The system shall provide an alert within 0.2 seconds of detecting a 
               metallic object. */
        
        subject detectorSystem : MetalDetector;
    }
    
    requirement operationalDuration : OperationalRequirement {
        doc /* The system shall operate continuously for a minimum of 15 hours on 
               a single battery charge under normal usage conditions. */
        
        subject detectorSystem : MetalDetector;
    }
    
    requirement environmentalTolerance : OperationalRequirement {
        doc /* The system shall operate in temperatures ranging from -10°C to 45°C 
               and withstand exposure to moisture and dust. */
        
        subject detectorSystem : MetalDetector;
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for the metal detector system encompassing 
               functional, performance, and operational aspects. */
        
        requirement function : primaryFunction;
        requirement detection : detectionCapability;
        requirement discrimination : discriminationCapability;
        requirement response : responseTime;
        requirement duration : operationalDuration;
        requirement environmental : environmentalTolerance;
    }
    
    part metalDetectorInstance : MetalDetector {
        satisfy primaryFunction;
        satisfy detectionCapability;
        satisfy discriminationCapability;
        satisfy responseTime;
        satisfy operationalDuration;
        satisfy environmentalTolerance;
    }
}
