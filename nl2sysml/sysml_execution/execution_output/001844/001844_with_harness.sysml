package RectifiedSineWaveSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VoltageValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def ResistanceValue :> Real;
    attribute def CapacitanceValue :> Real;
    attribute def PowerValue :> Real;
    attribute def TimeValue :> Real;
    
    enum def RectifierConfiguration {
        halfWave;
        fullWaveCenterTap;
        fullWaveBridge;
    }
    
    enum def OperatingMode {
        idle;
        rectifying;
        filtering;
        regulating;
        fault;
    }
    
    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute frequency : FrequencyValue;
    }
    
    item def ACSignal :> ElectricalSignal {
        attribute peakVoltage : VoltageValue;
        attribute rmsVoltage : VoltageValue;
    }
    
    item def RectifiedSignal :> ElectricalSignal {
        attribute averageVoltage : VoltageValue;
        attribute rippleVoltage : VoltageValue;
        attribute rippleFrequency : FrequencyValue;
    }
    
    port def ACInputPort {
        in item acSignal : ACSignal;
    }
    
    port def DCOutputPort {
        out item dcSignal : RectifiedSignal;
    }
    
    port def PowerFlowPort {
        item signal : ElectricalSignal;
    }
    
    part def ACPowerSource {
        attribute nominalVoltage : VoltageValue = 120.0;
        attribute peakVoltage : VoltageValue = 170.0;
        attribute frequency : FrequencyValue = 60.0;
        attribute sourceImpedance : ResistanceValue = 0.1;
        
        port acOutput : ACInputPort;
    }
    
    part def DiodeElement {
        attribute forwardVoltageDrop : VoltageValue = 0.7;
        attribute maxForwardCurrent : CurrentValue = 10.0;
        attribute reverseBreakdownVoltage : VoltageValue = 400.0;
        attribute thermalResistance : Real = 5.0;
        
        port anode : PowerFlowPort;
        port cathode : PowerFlowPort;
    }
    
    part def BridgeRectifier {
        attribute configuration : RectifierConfiguration = RectifierConfiguration::fullWaveBridge;
        attribute efficiency : Real = 0.95;
        attribute totalVoltageDrop : VoltageValue = 1.4;
        
        port acInput : ACInputPort;
        port dcOutput : DCOutputPort;
        
        part diodeD1 : DiodeElement;
        part diodeD2 : DiodeElement;
        part diodeD3 : DiodeElement;
        part diodeD4 : DiodeElement;
    }
    
    part def SmoothingCapacitor {
        attribute capacitance : CapacitanceValue = 2200.0;
        attribute voltageRating : VoltageValue = 250.0;
        attribute esr : ResistanceValue = 0.05;
        attribute leakageCurrent : CurrentValue = 0.001;
        
        port positive : PowerFlowPort;
        port negative : PowerFlowPort;
    }
    
    part def LoadResistor {
        attribute resistance : ResistanceValue = 100.0;
        attribute powerRating : PowerValue = 50.0;
        attribute tolerance : Real = 0.05;
        
        port input : PowerFlowPort;
        port ground : PowerFlowPort;
    }
    
    part def VoltageMonitor {
        attribute thresholdLow : VoltageValue = 90.0;
        attribute thresholdHigh : VoltageValue = 180.0;
        attribute samplingRate : FrequencyValue = 1000.0;
        
        port senseInput : PowerFlowPort;
    }
    
    action def GenerateACWaveform {
        in frequency : FrequencyValue;
        in peakVoltage : VoltageValue;
        in time : TimeValue;
        out instantaneousVoltage : VoltageValue;
    }
    
    action def PerformRectification {
        in acInputVoltage : VoltageValue;
        in configuration : RectifierConfiguration;
        out rectifiedVoltage : VoltageValue;
        out outputCurrent : CurrentValue;
    }
    
    action def FilterRipple {
        in pulsatingDC : VoltageValue;
        in capacitance : CapacitanceValue;
        in loadResistance : ResistanceValue;
        out smoothedDC : VoltageValue;
        out rippleAmplitude : VoltageValue;
    }
    
    action def DeliverPower {
        in dcVoltage : VoltageValue;
        in loadResistance : ResistanceValue;
        out loadCurrent : CurrentValue;
        out powerDelivered : PowerValue;
    }
    
    action def MonitorOutput {
        in outputVoltage : VoltageValue;
        in thresholdLow : VoltageValue;
        in thresholdHigh : VoltageValue;
        out statusOK : Boolean;
    }
    
    state def RectificationStateMachine {
        entry; then checkPower;
        
        state checkPower;
        then decide;
            if powerAvailable then initialize;
            if not powerAvailable then idle;
        
        state idle {
            entry assign mode = OperatingMode::idle;
        }
        then checkPower;
        
        state initialize {
            entry assign mode = OperatingMode::rectifying;
        }
        then rectifyingState;
        
        state rectifyingState {
            entry assign mode = OperatingMode::rectifying;
            do action convertACtoDC : PerformRectification;
        }
        then filteringState;
        
        state filteringState {
            entry assign mode = OperatingMode::filtering;
            do action smoothOutput : FilterRipple;
        }
        then regulatingState;
        
        state regulatingState {
            entry assign mode = OperatingMode::regulating;
            do action supplyLoad : DeliverPower;
            do action monitor : MonitorOutput;
        }
        then decide;
            if faultDetected then faultState;
            if not faultDetected then rectifyingState;
        
        state faultState {
            entry assign mode = OperatingMode::fault;
        }
        then checkPower;
        
        attribute powerAvailable : Boolean;
        attribute faultDetected : Boolean;
        attribute mode : OperatingMode;
    }
    
    part def RectifiedSineWaveConverter {
        doc /*
         * A power conversion system that transforms alternating current (AC) 
         * sine wave input into pulsating direct current (DC) output using 
         * full-wave bridge rectification. The system converts both positive 
         * and negative half-cycles of the AC input into unidirectional current 
         * flow, then filters the resulting pulsating DC to provide a smoothed 
         * voltage suitable for powering DC loads.
         */
        
        attribute inputFrequency : FrequencyValue = 60.0;
        attribute inputPeakVoltage : VoltageValue = 170.0;
        attribute outputAverageDC : VoltageValue;
        attribute outputRippleVoltage : VoltageValue;
        attribute conversionEfficiency : Real;
        attribute operatingMode : OperatingMode;
        
        part source : ACPowerSource {
            attribute :>> nominalVoltage = 120.0;
            attribute :>> peakVoltage = 170.0;
            attribute :>> frequency = 60.0;
        }
        
        part rectifierBridge : BridgeRectifier {
            attribute :>> configuration = RectifierConfiguration::fullWaveBridge;
            attribute :>> efficiency = 0.95;
            
            part :>> diodeD1 {
                attribute :>> forwardVoltageDrop = 0.7;
                attribute :>> maxForwardCurrent = 10.0;
            }
            part :>> diodeD2 {
                attribute :>> forwardVoltageDrop = 0.7;
                attribute :>> maxForwardCurrent = 10.0;
            }
            part :>> diodeD3 {
                attribute :>> forwardVoltageDrop = 0.7;
                attribute :>> maxForwardCurrent = 10.0;
            }
            part :>> diodeD4 {
                attribute :>> forwardVoltageDrop = 0.7;
                attribute :>> maxForwardCurrent = 10.0;
            }
        }
        
        part smoothingFilter : SmoothingCapacitor {
            attribute :>> capacitance = 2200.0;
            attribute :>> voltageRating = 250.0;
            attribute :>> esr = 0.05;
        }
        
        part dcLoad : LoadResistor {
            attribute :>> resistance = 100.0;
            attribute :>> powerRating = 50.0;
        }
        
        part monitor : VoltageMonitor {
            attribute :>> thresholdLow = 90.0;
            attribute :>> thresholdHigh = 180.0;
        }
        
        connection sourceToRectifier connect source.acOutput to rectifierBridge.acInput;
        connection rectifierToFilter connect rectifierBridge.dcOutput to smoothingFilter.positive;
        connection filterToLoad connect smoothingFilter.positive to dcLoad.input;
        connection loadToGround connect dcLoad.ground to smoothingFilter.negative;
        connection monitorConnection connect smoothingFilter.positive to monitor.senseInput;
        
        perform action powerConversionProcess {
            first start;
            then generateWaveform;
            
            action generateWaveform : GenerateACWaveform {
                in frequency = inputFrequency;
                in peakVoltage = inputPeakVoltage;
                in time : TimeValue;
                out acVoltage : VoltageValue;
            }
            then rectifySignal;
            
            action rectifySignal : PerformRectification {
                in acInputVoltage = generateWaveform.acVoltage;
                in configuration = rectifierBridge.configuration;
                out pulsatingDC : VoltageValue;
                out rectifiedCurrent : CurrentValue;
            }
            then smoothSignal;
            
            action smoothSignal : FilterRipple {
                in pulsatingDC = rectifySignal.pulsatingDC;
                in capacitance = smoothingFilter.capacitance;
                in loadResistance = dcLoad.resistance;
                out filteredDC : VoltageValue;
                out ripple : VoltageValue;
            }
            then deliverToLoad;
            
            action deliverToLoad : DeliverPower {
                in dcVoltage = smoothSignal.filteredDC;
                in loadResistance = dcLoad.resistance;
                out current : CurrentValue;
                out power : PowerValue;
            }
            then monitorVoltage;
            
            action monitorVoltage : MonitorOutput {
                in outputVoltage = smoothSignal.filteredDC;
                in thresholdLow = monitor.thresholdLow;
                in thresholdHigh = monitor.thresholdHigh;
                out status : Boolean;
            }
            then generateWaveform;
        }
    }
    
    requirement <'REQ-100'> primarySystemFunction {
        doc /*
         * The rectified sine wave system shall convert AC sinusoidal input 
         * voltage into pulsating DC output voltage, then filter the output 
         * to provide smoothed DC power suitable for resistive loads.
         */
        subject converter :> rectifierConverter;
        
        require <'REQ-101'> acToDcConversion {
            doc /*
             * The system shall accept sinusoidal AC input and produce 
             * rectified DC output containing only positive voltage pulses.
             */
        }
        
        require <'REQ-102'> fullWaveOperation {
            doc /*
             * The system shall utilize full-wave bridge rectification to 
             * convert both positive and negative half-cycles of the AC input.
             */
            assert constraint {
                converter.rectifierBridge.configuration == RectifierConfiguration::fullWaveBridge
            }
        }
        
        require <'REQ-103'> outputFiltering {
            doc /*
             * The system shall filter the pulsating DC output to reduce 
             * voltage ripple and provide smoothed DC voltage.
             */
        }
    }
    
    requirement <'REQ-200'> voltageSpecifications {
        doc /*
         * The system shall operate within specified voltage ranges for 
         * input and output.
         */
        subject converter :> rectifierConverter;
        
        assert constraint inputVoltageRange {
            converter.inputPeakVoltage >= 150.0 and 
            converter.inputPeakVoltage <= 180.0
        }
        
        assert constraint outputVoltageRange {
            converter.outputAverageDC >= 100.0 and 
            converter.outputAverageDC <= 165.0
        }
    }
    
    requirement <'REQ-300'> efficiencyRequirement {
        doc /*
         * The rectifier system shall maintain minimum power conversion efficiency.
         */
        subject converter :> rectifierConverter;
        
        assert constraint minimumEfficiency {
            converter.conversionEfficiency >= 0.90
        }
    }
    
    requirement <'REQ-400'> componentRatings {
        doc /*
         * All system components shall be rated to safely handle maximum 
         * operating voltages and currents.
         */
        subject converter :> rectifierConverter;
        
        assert constraint diodeCurrentCapacity {
            converter.rectifierBridge.diodeD1.maxForwardCurrent >= 5.0 and
            converter.rectifierBridge.diodeD2.maxForwardCurrent >= 5.0 and
            converter.rectifierBridge.diodeD3.maxForwardCurrent >= 5.0 and
            converter.rectifierBridge.diodeD4.maxForwardCurrent >= 5.0
        }
        
        assert constraint capacitorVoltageRating {
            converter.smoothingFilter.voltageRating >= converter.inputPeakVoltage
        }
        
        assert constraint loadPowerRating {
            converter.dcLoad.powerRating >= 40.0
        }
    }
    
    requirement <'REQ-500'> rippleSpecification {
        doc /*
         * The output ripple voltage shall be limited to ensure acceptable 
         * DC quality for connected loads.
         */
        subject converter :> rectifierConverter;
        
        assert constraint maximumRipple {
            converter.outputRippleVoltage <= 0.10 * converter.outputAverageDC
        }
    }
    
    part rectifierConverter : RectifiedSineWaveConverter;
    
    satisfy primarySystemFunction by rectifierConverter;
    satisfy voltageSpecifications by rectifierConverter;
    satisfy efficiencyRequirement by rectifierConverter;
    satisfy componentRatings by rectifierConverter;
    satisfy rippleSpecification by rectifierConverter;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import RectifiedSineWaveSystem::*;

    part testSubject : RectifiedSineWaveConverter {
    :>> frequency = testFrequency;
    :>> peakVoltage = testPeakVoltage;
    :>> time = testTime;
    }

    part testSubject : ACPowerSource {
        exhibit state sm : RectificationStateMachine;
    }

    action orchestrator {
        attribute testFrequency : FrequencyValue = 0.0;
        attribute testPeakVoltage : VoltageValue = 0.0;
        attribute testTime : TimeValue = 0.0;
    }
}
