package PrecisionForceMeasurementSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ======================== Value Types ========================
    value def VoltageVal :> ElectricPotential;
    value def ResistanceVal :> ElectricResistance;
    value def ForceVal :> Force;
    value def TemperatureVal :> ThermodynamicTemperature;
    value def FrequencyVal :> Frequency;
    value def TimeVal :> Time;
    value def GainVal :> Real;
    value def CountVal :> Integer;
    value def PercentVal :> Real;

    // ======================== Item Definitions ========================
    item def AppliedForceItem {
        attribute magnitude : ForceVal;
        attribute directionDeg : Real;
    }

    item def BridgeSignal {
        attribute differential : VoltageVal;
        attribute commonMode : VoltageVal;
        attribute excitation : VoltageVal;
    }

    item def AmplifiedSignal {
        attribute voltage : VoltageVal;
        attribute gainApplied : GainVal;
    }

    item def DigitizedSample {
        attribute rawCount : CountVal;
        attribute timestamp : TimeVal;
        attribute sampleRate : FrequencyVal;
        attribute channel : Integer = 1;
    }

    item def CalibratedForceReading {
        attribute forceValue : ForceVal;
        attribute timestamp : TimeVal;
        attribute uncertainty : ForceVal;
        attribute status : String = "OK";
    }

    item def DisplayMessage {
        attribute displayedForce : ForceVal;
        attribute unitLabel : String = "N";
        attribute timestamp : TimeVal;
        attribute overloadFlag : Boolean = false;
    }

    // ======================== Port Definitions ========================
    port def ForceInPort {
        in force : AppliedForceItem;
    }

    port def AnalogOutPort {
        out signal : VoltageVal;
    }

    port def AnalogInPort {
        in signal : VoltageVal;
    }

    port def DigitalOutPort {
        out sample : DigitizedSample;
    }

    port def DigitalInPort {
        in sample : DigitizedSample;
    }

    port def ForceReadingOutPort {
        out reading : CalibratedForceReading;
    }

    port def ForceReadingInPort {
        in reading : CalibratedForceReading;
    }

    port def DisplayOutPort {
        out message : DisplayMessage;
    }

    // ======================== Requirements ========================
    requirement def SystemAccuracyReq {
        doc "The complete system shall measure applied force with an accuracy of ±0.1 percent of full scale (5000 N), equivalent to ±5 N.";
        attribute fullScale : ForceVal = 5000 [N];
        attribute accuracyFraction : PercentVal = 0.001;
        attribute maxError : ForceVal = 5 [N];
    }

    requirement def LoadCellLinearityReq {
        doc "The load cell shall maintain a linearity error within ±0.05 percent of rated output across the operating range.";
        attribute linearityFraction : PercentVal = 0.0005;
        attribute ratedOutput : VoltageVal = 0.010 [V];
    }

    requirement def OperatingTemperatureReq {
        doc "The system shall operate reliably within the ambient temperature range of -10 °C to +60 °C.";
        attribute minTemp : TemperatureVal = 263.15 [K];
        attribute maxTemp : TemperatureVal = 333.15 [K];
    }

    requirement def MaxForceCapacityReq {
        doc "The load cell shall safely measure mechanical forces up to 5000 N without permanent deformation or loss of calibration.";
        attribute ratedCapacity : ForceVal = 5000 [N];
        attribute overloadCapacity : ForceVal = 7500 [N];
    }

    requirement def ADCPerformanceReq {
        doc "The analog-to-digital converter shall sample the amplified signal at 1000 samples per second with 24-bit resolution.";
        attribute sampleRate : FrequencyVal = 1000 [Hz];
        attribute resolutionBits : Integer = 24;
        attribute fullScaleCount : CountVal = 16777216;
    }

    requirement def AmplifierGainReq {
        doc "The signal amplifier shall provide a nominal voltage gain of 1000 to boost the weak bridge output to a usable level.";
        attribute nominalGain : GainVal = 1000;
        attribute bandwidth : FrequencyVal = 5000 [Hz];
    }

    requirement def DisplayRefreshReq {
        doc "The display unit shall refresh the presented force measurement at a minimum rate of 10 Hz, i.e., ten times per second.";
        attribute refreshRate : FrequencyVal = 10 [Hz];
    }

    requirement def CalibrationConversionReq {
        doc "The microcontroller shall convert each raw digital sample into a calibrated force value in Newtons using a system-specific calibration constant and zero offset.";
        attribute calibrationConstant : GainVal;
        attribute zeroOffset : CountVal = 0;
        attribute updateRate : FrequencyVal = 1000 [Hz];
    }

    // ======================== Strain Gauge ========================
    part def StrainGauge {
        attribute nominalResistance : ResistanceVal = 350 [Ohm];
        attribute gaugeFactor : Real = 2.0;
        attribute currentResistance : ResistanceVal = 350 [Ohm];
        attribute maxStrainMicrostrain : Integer = 3000;
        attribute tempCoeffPerKelvin : Real = 0.00001;

        port deformationPort : ForceInPort;
        port resistanceOutPort : AnalogOutPort;

        action def senseStrain {
            in appliedForce : ForceVal;
            in modulusElasticity : Real = 200000000000;
            in crossSectionArea : Real = 0.0001;
            out resistanceDelta : ResistanceVal;
            // DeltaR = Rnom * gaugeFactor * strain
            // strain = appliedForce / (E * A)
        }

        state machine strainGaugeStates {
            initial state Rest;
            state Compressed;
            state Tensioned;
            state Overstressed;

            transition from Rest to Compressed when force < 0;
            transition from Rest to Tensioned when force > 0;
            transition from Compressed to Rest when force == 0;
            transition from Tensioned to Rest when force == 0;
            transition from Tensioned to Overstressed when strain > maxStrainMicrostrain;
            transition from Compressed to Overstressed when strain > maxStrainMicrostrain;
        }
    }

    // ======================== Wheatstone Bridge ========================
    part def WheatstoneBridge {
        attribute excitationVoltage : VoltageVal = 5 [V];
        attribute bridgeSensitivityMVperV : Real = 2.0;
        attribute outputDifferential : VoltageVal;
        attribute bridgeType : String = "full";

        part gaugeR1 : StrainGauge;
        part gaugeR2 : StrainGauge;
        part gaugeR3 : StrainGauge;
        part gaugeR4 : StrainGauge;

        port forceInputPort : ForceInPort;
        port bridgeOutputPort : AnalogOutPort;

        action def computeBridgeOutput {
            in r1 : ResistanceVal;
            in r2 : ResistanceVal;
            in r3 : ResistanceVal;
            in r4 : ResistanceVal;
            in vExcitation : VoltageVal;
            out vOut : VoltageVal;
            // Vout = Vexc * (R2/(R1+R2) - R4/(R3+R4))
        }

        connect forceInputPort to gaugeR1.deformationPort;
        connect forceInputPort to gaugeR2.deformationPort;
        connect forceInputPort to gaugeR3.deformationPort;
        connect forceInputPort to gaugeR4.deformationPort;
    }

    // ======================== Signal Amplifier ========================
    part def SignalAmplifier {
        attribute gain : GainVal = 1000;
        attribute inputRange : VoltageVal = 0.010 [V];
        attribute outputRange : VoltageVal = 10 [V];
        attribute bandwidth : FrequencyVal = 5000 [Hz];
        attribute inputNoise : VoltageVal = 0.000001 [V];
        attribute cmrr : Real = 120;

        port ampInputPort : AnalogInPort;
        port ampOutputPort : AnalogOutPort;

        action def amplify {
            in inputVoltage : VoltageVal;
            out outputVoltage : VoltageVal;
            // Vout = gain * Vin + offset; offset ~ 0
        }

        state machine amplifierStates {
            initial state Powered;
            state Active;
            state Saturated;
            state Fault;

            transition from Powered to Active when stable;
            transition from Active to Saturated when inputVoltage > inputRange;
            transition from Saturated to Active when inputVoltage < inputRange;
            transition from Active to Fault when inputNoise > threshold;
            transition from Fault to Active when reset;
        }

        satisfy AmplifierGainReq;
    }

    // ======================== Analog-to-Digital Converter ========================
    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 24;
        attribute sampleRate : FrequencyVal = 1000 [Hz];
        attribute fullScaleCount : CountVal = 16777216;
        attribute referenceVoltage : VoltageVal = 5 [V];
        attribute effectiveBits : Integer = 21;
        attribute lsbVoltage : VoltageVal;

        port adcInputPort : AnalogInPort;
        port adcOutputPort : DigitalOutPort;

        action def convert {
            in analogVoltage : VoltageVal;
            in vRef : VoltageVal;
            in maxCount : CountVal;
            out digitalCount : CountVal;
            // count = round(analogVoltage / vRef * maxCount)
        }

        action def continuousSampling {
            attribute running : Boolean = true;
            while running {
                action convert;
            }
        }

        state machine adcStates {
            initial state Idle;
            state Sampling;
            state Converting;
            state OutputReady;

            transition from Idle to Sampling when startSignal;
            transition from Sampling to Converting when sampleTimerTick;
            transition from Converting to OutputReady when conversionDone;
            transition from OutputReady to Sampling when nextCycle;
        }

        satisfy ADCPerformanceReq;
    }

    // ======================== Load Cell Assembly ========================
    part def LoadCell {
        attribute ratedCapacity : ForceVal = 5000 [N];
        attribute ratedOutputMVperV : Real = 2.0;
        attribute nonlinearity : PercentVal = 0.0005;
        attribute hysteresisErr : PercentVal = 0.0005;
        attribute repeatabilityErr : PercentVal = 0.0003;
        attribute creepErr : PercentVal = 0.0002;
        attribute tempEffectZero : Real = 0.000035;
        attribute tempEffectSpan : Real = 0.000035;
        attribute compensatedTempMin : TemperatureVal = 263.15 [K];
        attribute compensatedTempMax : TemperatureVal = 333.15 [K];
        attribute material : String = "aluminum-alloy";

        part bridge : WheatstoneBridge;
        part amplifier : SignalAmplifier;

        port cellForcePort : ForceInPort;
        port cellOutputPort : AnalogOutPort;

        connect cellForcePort to bridge.forceInputPort;
        connect bridge.bridgeOutputPort to amplifier.ampInputPort;
        connect amplifier.ampOutputPort to cellOutputPort;

        state machine loadCellStates {
            initial state Unloaded;
            state Loaded;
            state Overloaded;
            state ThermalCompensation;

            transition from Unloaded to Loaded when appliedForce > 0;
            transition from Loaded to Unloaded when appliedForce == 0;
            transition from Loaded to Overloaded when appliedForce > ratedCapacity;
            transition from Overloaded to Loaded when appliedForce < ratedCapacity and appliedForce > 0;
            transition from Loaded to ThermalCompensation when tempDrift > threshold;
            transition from ThermalCompensation to Loaded when compensated;
        }

        satisfy LoadCellLinearityReq;
        satisfy MaxForceCapacityReq;
    }

    // ======================== Data Acquisition Unit ========================
    part def DataAcquisitionUnit {
        attribute samplingFrequency : FrequencyVal = 1000 [Hz];
        attribute bufferSize : Integer = 1024;
        attribute dataFormat : String = "SPI-24bit";
        attribute interruptDriven : Boolean = true;

        part adc : AnalogToDigitalConverter;

        port daqInputPort : AnalogInPort;
        port daqOutputPort : DigitalOutPort;

        connect daqInputPort to adc.adcInputPort;
        connect adc.adcOutputPort to daqOutputPort;

        action def bufferSample {
            in sample : DigitizedSample;
            attribute bufferIndex : Integer = 0;
            // Store sample in ring buffer
        }

        state machine daqStates {
            initial state Stopped;
            state Acquiring;
            state BufferFull;
            state Transferring;

            transition from Stopped to Acquiring when startCommand;
            transition from Acquiring to BufferFull when bufferCount >= bufferSize;
            transition from BufferFull to Transferring when transferRequest;
            transition from Transferring to Acquiring when transferComplete;
        }
    }

    // ======================== Microcontroller ========================
    part def Microcontroller {
        attribute calibrationConstant : GainVal = 0.000298;
        attribute zeroOffsetCount : CountVal = 0;
        attribute processingRate : FrequencyVal = 1000 [Hz];
        attribute filterCoefficient : Real = 0.125;
        attribute oversamplingFactor : Integer = 4;
        attribute clockFrequency : FrequencyVal = 48000000 [Hz];

        port mcDigitalIn : DigitalInPort;
        port mcForceOut : ForceReadingOutPort;

        action def applyCalibration {
            in rawCount : CountVal;
            in calConstant : GainVal;
            in zeroOffset : CountVal;
            out forceValue : ForceVal;
            // force = (rawCount - zeroOffset) * calConstant
        }

        action def digitalLowPassFilter {
            in currentSample : CountVal;
            in previousFiltered : CountVal;
            in alpha : Real;
            out filteredValue : CountVal;
            // y[n] = alpha * x[n] + (1-alpha) * y[n-1]
        }

        action def tareZero {
            out newZeroOffset : CountVal;
            // Capture current ADC reading as zero reference
        }

        state machine mcuStates {
            initial state Boot;
            state Idle;
            state Receiving;
            state Processing;
            state Transmitting;
            state TareMode;

            transition from Boot to Idle when bootComplete;
            transition from Idle to Receiving when sampleReady;
            transition from Receiving to Processing when dataAcquired;
            transition from Processing to Transmitting when calculationDone;
            transition from Transmitting to Idle when transmissionComplete;
            transition from Idle to TareMode when tareButtonPressed;
            transition from TareMode to Idle when tareComplete;
        }

        satisfy CalibrationConversionReq;
    }

    // ======================== Display Unit ========================
    part def DisplayUnit {
        attribute refreshRate : FrequencyVal = 10 [Hz];
        attribute currentDisplayedForce : ForceVal;
        attribute decimalPlaces : Integer = 2;
        attribute unitString : String = "N";
        attribute backlightEnabled : Boolean = true;
        attribute displayType : String = "LCD-16x2";

        port displayInPort : ForceReadingInPort;
        port displayOutPort : DisplayOutPort;

        action def renderForce {
            in force : ForceVal;
            in decimals : Integer;
            in unit : String;
            out message : DisplayMessage;
            // Format numeric value and unit for presentation
        }

        action def updateAt10Hz {
            attribute timerInterval : TimeVal = 0.1 [s];
            // Periodic refresh of display content every 100 ms
        }

        state machine displayStates {
            initial state PowerOff;
            state Initializing;
            state Showing;
            state Refreshing;
            state OverloadWarning;
            state ErrorDisplay;

            transition from PowerOff to Initializing when powerApplied;
            transition from Initializing to Showing when initComplete;
            transition from Showing to Refreshing when refreshTimerElapsed;
            transition from Refreshing to Showing when renderComplete;
            transition from Showing to OverloadWarning when forceValue > 5000;
            transition from Refreshing to OverloadWarning when forceValue > 5000;
            transition from OverloadWarning to Showing when forceValue <= 5000;
            transition from Showing to ErrorDisplay when errorFlag;
            transition from ErrorDisplay to Showing when errorCleared;
        }

        satisfy DisplayRefreshReq;
    }

    // ======================== Top-Level Force Measurement System ========================
    part def ForceMeasurementSystem {
        attribute systemIdentifier : String = "PrecisionForceMeasurementSystem";
        attribute operatingTempMin : TemperatureVal = 263.15 [K];
        attribute operatingTempMax : TemperatureVal = 333.15 [K];
        attribute maxMeasurableForce : ForceVal = 5000 [N];
        attribute systemAccuracyPercent : Real = 0.1;
        attribute warmupTime : TimeVal = 30 [s];
        attribute supplyVoltage : VoltageVal = 12 [V];
        attribute powerConsumption : Real = 2.5;

        part loadCell : LoadCell;
        part daq : DataAcquisitionUnit;
        part controller : Microcontroller;
        part display : DisplayUnit;

        port systemForcePort : ForceInPort;
        port systemDisplayPort : DisplayOutPort;

        // Internal connections: force -> load cell -> DAQ -> microcontroller -> display
        connect systemForcePort to loadCell.cellForcePort;
        connect loadCell.cellOutputPort to daq.daqInputPort;
        connect daq.daqOutputPort to controller.mcDigitalIn;
        connect controller.mcForceOut to display.displayInPort;
        connect display.displayOutPort to systemDisplayPort;

        action def fullMeasurementPipeline {
            in appliedForce : ForceVal;
            out displayedForce : ForceVal;
            // 1. Load cell deforms under force; strain gauges change resistance
            // 2. Wheatstone bridge produces differential voltage proportional to force
            // 3. Amplifier boosts bridge output by gain of 1000
            // 4. ADC samples amplified voltage at 1000 Hz, 24-bit resolution
            // 5. Microcontroller applies calibration constant to convert count to Newtons
            // 6. Display unit presents calibrated force at 10 Hz refresh rate
        }

        action def startupSequence {
            attribute warmupElapsed : TimeVal = 0 [s];
            // Apply power to all subsystems
            // Wait for amplifier stabilization
            // Initialize ADC sampling
            // Perform initial tare/zero calibration
            // Begin display
        }

        action def continuousOperation {
            attribute running : Boolean = true;
            while running {
                action fullMeasurementPipeline;
            }
        }

        state machine systemStates {
            initial state Off;
            state Warming;
            state Operational;
            state Faulted;
            state Maintenance;

            transition from Off to Warming when powerOn;
            transition from Warming to Operational when warmupComplete;
            transition from Operational to Faulted when faultDetected;
            transition from Faulted to Operational when faultCleared;
            transition from Operational to Off when powerOff;
            transition from Operational to Maintenance when maintenanceRequested;
            transition from Maintenance to Off when shutdownApproved;
        }

        satisfy SystemAccuracyReq;
        satisfy OperatingTemperatureReq;
    }

    // ======================== Concrete System Instance ========================
    part industrialForceSystem : ForceMeasurementSystem {
        attribute systemIdentifier = "IFMS-5000-RevC";
        attribute maxMeasurableForce = 5000 [N];
        attribute operatingTempMin = 263.15 [K];
        attribute operatingTempMax = 333.15 [K];

        part loadCell {
            attribute ratedCapacity = 5000 [N];
            attribute material = "stainless-steel";
        }

        part controller {
            attribute calibrationConstant = 0.000298;
            attribute zeroOffsetCount = 838861;
            attribute filterCoefficient = 0.0625;
        }

        part display {
            attribute refreshRate = 10 [Hz];
            attribute displayType = "OLED-128x64";
            attribute decimalPlaces = 3;
        }
    }
}
