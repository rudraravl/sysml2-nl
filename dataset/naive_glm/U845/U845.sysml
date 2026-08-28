package HandheldRadarGun {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type FrequencyGHz :> Real;
    value type FrequencyMHz :> Real;
    value type SpeedMps :> Real;
    value type DistanceM :> Real;
    value type VoltageV :> Real;
    value type CurrentA :> Real;
    value type TimeS :> Real;
    value type TimeUs :> Real;
    value type TimeNs :> Real;
    value type AmplitudeV :> Real;
    value type DopplerHz :> Real;
    value type PowerW :> Real;
    value type SNRdB :> Real;
    value type ChargePct :> Real;

    // ===== Item Definitions =====
    item def RadarPulse {
        attribute carrierFrequency : FrequencyGHz = 24.15;
        attribute amplitude : AmplitudeV;
        attribute transmitTime : TimeS;
        attribute pulseDuration : TimeUs;
        attribute peakPower : PowerW;
    }

    item def EchoSignal {
        attribute frequency : FrequencyGHz;
        attribute amplitude : AmplitudeV;
        attribute receptionTime : TimeS;
        attribute snr : SNRdB;
        attribute targetSpeed : SpeedMps;
    }

    item def PowerFlow {
        attribute voltage : VoltageV;
        attribute current : CurrentA;
    }

    item def TriggerEvent;
    item def PowerOnCommand;
    item def PowerOffCommand;

    item def MeasurementResult {
        attribute speed : SpeedMps;
        attribute distance : DistanceM;
        attribute valid : Boolean;
        attribute errorCode : Integer;
    }

    item def DisplayData {
        attribute speedReading : SpeedMps;
        attribute distanceReading : DistanceM;
        attribute valid : Boolean;
        attribute message : String;
    }

    // ===== Port Definitions =====
    port def PowerSourcePort {
        attribute nominalVoltage : VoltageV;
        out power : PowerFlow;
    }

    port def PowerSinkPort {
        attribute requiredVoltage : VoltageV;
        in power : PowerFlow;
    }

    port def ControlCommandPort {
        out triggerEvent : TriggerEvent;
        out powerOnCmd : PowerOnCommand;
        out powerOffCmd : PowerOffCommand;
    }

    port def TriggerInputPort {
        in triggerEvent : TriggerEvent;
    }

    port def TransmitterOutputPort {
        out radiatedPulse : RadarPulse;
        out referencePulse : RadarPulse;
    }

    port def AntennaInputPort {
        in radiatedPulse : RadarPulse;
    }

    port def AntennaOutputPort {
        out receivedEcho : EchoSignal;
    }

    port def ReceiverInputPort {
        in receivedEcho : EchoSignal;
    }

    port def ReceiverOutputPort {
        out filteredEcho : EchoSignal;
    }

    port def ProcessorPulseInputPort {
        in referencePulse : RadarPulse;
    }

    port def ProcessorEchoInputPort {
        in filteredEcho : EchoSignal;
    }

    port def ProcessorOutputPort {
        out result : MeasurementResult;
    }

    port def DisplayInputPort {
        in result : MeasurementResult;
    }

    // ===== Part Definitions =====
    part def PowerSupply {
        attribute nominalVoltage : VoltageV = 12;
        attribute maxCurrent : CurrentA = 2.5;
        attribute capacityAh : Real = 2.0;
        attribute chargeLevel : ChargePct = 100;
        port powerOut : PowerSourcePort;

        action deliverPower {
            out power : PowerFlow;
            assign power.voltage := nominalVoltage;
            assign power.current := maxCurrent;
        }

        state machine PowerState {
            initialState Charged;
            state Discharging;
            state Depleted;

            transition Charged -> Discharging {
                when powerOut.power.transmit;
            }
            transition Discharging -> Depleted {
                when chargeLevel < 5;
            }
            transition Depleted -> Charged {
                when chargeLevel >= 100;
            }
        }
    }

    part def ControlUnit {
        attribute isPowered : Boolean = false;
        attribute triggerPressed : Boolean = false;
        attribute lastCommand : String = "none";
        port powerIn : PowerSinkPort;
        port controlOut : ControlCommandPort;

        action handlePowerOn {
            assign isPowered := true;
            assign lastCommand := "powerOn";
        }

        action handlePowerOff {
            assign isPowered := false;
            assign lastCommand := "powerOff";
        }

        action handleTrigger {
            assign triggerPressed := true;
            assign lastCommand := "trigger";
        }

        state machine ControlState {
            initialState Off;
            state Idle;
            state Active;
            state LowBattery;

            transition Off -> Idle {
                when handlePowerOn.complete;
                effect isPowered := true;
            }
            transition Idle -> Active {
                when handleTrigger.complete;
                effect triggerPressed := true;
            }
            transition Active -> Idle {
                when !triggerPressed;
            }
            transition Idle -> Off {
                when handlePowerOff.complete;
                effect isPowered := false;
            }
            transition Idle -> LowBattery {
                when chargeLevel < 10;
            }
            transition LowBattery -> Off {
                when handlePowerOff.complete;
            }
        }
    }

    part def TransmitterModule {
        attribute carrierFrequency : FrequencyGHz = 24.15;
        attribute outputPower : PowerW = 0.1;
        attribute pulseDuration : TimeUs = 0.5;
        port powerIn : PowerSinkPort;
        port triggerIn : TriggerInputPort;
        port txOut : TransmitterOutputPort;

        action generatePulse {
            in trigger : TriggerEvent;
            out pulse : RadarPulse;
            out reference : RadarPulse;
            assign pulse.carrierFrequency := carrierFrequency;
            assign pulse.amplitude := 1.0;
            assign pulse.transmitTime := 0;
            assign pulse.pulseDuration := pulseDuration;
            assign pulse.peakPower := outputPower;
            assign reference := pulse;
        }

        state machine TransmitterState {
            initialState Ready;
            state Transmitting;
            state Cooldown;

            transition Ready -> Transmitting {
                when triggerIn.triggerEvent.receive;
            }
            transition Transmitting -> Cooldown {
                when generatePulse.complete;
            }
            transition Cooldown -> Ready {
                when pulseDuration.elapsed;
            }
        }
    }

    part def Antenna {
        attribute gain : Real = 20;
        attribute beamWidthDeg : Real = 8;
        port txIn : AntennaInputPort;
        port rxOut : AntennaOutputPort;

        action radiate {
            in pulse : RadarPulse;
        }

        action receive {
            out echo : EchoSignal;
        }
    }

    part def ReceiverModule {
        attribute noiseFigure : SNRdB = 2.5;
        attribute gaindB : Real = 60;
        attribute bandwidthGHz : FrequencyGHz = 0.1;
        port powerIn : PowerSinkPort;
        port rxIn : ReceiverInputPort;
        port rxOut : ReceiverOutputPort;

        action filter {
            in raw : EchoSignal;
            out filtered : EchoSignal;
        }

        action amplify {
            in input : EchoSignal;
            out output : EchoSignal;
        }

        action processEcho {
            in raw : EchoSignal;
            out clean : EchoSignal;
            perform filter {
                in raw = raw;
                out intermediate;
            }
            perform amplify {
                in input = intermediate;
                out output = clean;
            }
        }

        state machine ReceiverState {
            initialState Listening;
            state Receiving;
            state Idle2;

            transition Listening -> Receiving {
                when rxIn.receivedEcho.receive;
            }
            transition Receiving -> Idle2 {
                when processEcho.complete;
            }
            transition Idle2 -> Listening {
                when !rxIn.receivedEcho.receive;
            }
        }
    }

    part def SignalProcessingUnit {
        attribute minSpeed : SpeedMps = 1.4;
        attribute maxSpeed : SpeedMps = 111;
        attribute maxRange : DistanceM = 500;
        attribute speedOfLight : SpeedMps = 299792458;
        attribute minSNR : SNRdB = 10;
        attribute dopplerTolerance : Real = 0.05;
        port powerIn : PowerSinkPort;
        port pulseIn : ProcessorPulseInputPort;
        port echoIn : ProcessorEchoInputPort;
        port resultOut : ProcessorOutputPort;

        action computeDoppler {
            in transmitted : RadarPulse;
            in echo : EchoSignal;
            out shift : DopplerHz;
            assign shift := (2 * transmitted.carrierFrequency * 1.0e9 * (echo.frequency - transmitted.carrierFrequency) * 1.0e9) / speedOfLight;
        }

        action computeSpeed {
            in shift : DopplerHz;
            in frequency : FrequencyGHz;
            out speed : SpeedMps;
            assign speed := (shift * speedOfLight) / (2 * frequency * 1.0e9);
        }

        action computeRange {
            in transmitted : RadarPulse;
            in echo : EchoSignal;
            out range : DistanceM;
            assign range := (echo.receptionTime - transmitted.transmitTime) * speedOfLight / 2;
        }

        action validate {
            in speed : SpeedMps;
            in range : DistanceM;
            in snr : SNRdB;
            out result : MeasurementResult;
            assign result.speed := speed;
            assign result.distance := range;
            assign result.valid := (speed >= minSpeed) && (speed <= maxSpeed) && (range <= maxRange) && (snr >= minSNR);
            assign result.errorCode := if result.valid then 0 else 1;
        }

        action processMeasurement {
            in pulse : RadarPulse;
            in echo : EchoSignal;
            out result : MeasurementResult;
            perform computeDoppler {
                in transmitted = pulse;
                in echo = echo;
                out shift;
            }
            perform computeSpeed {
                in shift = shift;
                in frequency = pulse.carrierFrequency;
                out speed;
            }
            perform computeRange {
                in transmitted = pulse;
                in echo = echo;
                out range;
            }
            perform validate {
                in speed = speed;
                in range = range;
                in snr = echo.snr;
                out result;
            }
        }

        state machine ProcessorState {
            initialState Waiting;
            state Computing;
            state Validating;
            state Outputting;

            transition Waiting -> Computing {
                when pulseIn.referencePulse.receive;
            }
            transition Computing -> Validating {
                when computeRange.complete;
            }
            transition Validating -> Outputting {
                when validate.complete;
            }
            transition Outputting -> Waiting {
                when resultOut.result.transmit;
            }
        }
    }

    part def DisplayModule {
        attribute backlightOn : Boolean = false;
        attribute resolution : String = "128x64";
        port powerIn : PowerSinkPort;
        port dataIn : DisplayInputPort;

        action showSpeed {
            in result : MeasurementResult;
            out data : DisplayData;
            assign data.valid := result.valid;
            assign data.speedReading := result.speed;
            assign data.distanceReading := result.distance;
            assign data.message := if result.valid then "OK" else "ERR";
        }

        action showError {
            in errorCode : Integer;
            out data : DisplayData;
            assign data.valid := false;
            assign data.speedReading := 0;
            assign data.distanceReading := 0;
            assign data.message := "ERR";
        }

        state machine DisplayState {
            initialState Dark;
            state Showing;
            state ErrorState;

            transition Dark -> Showing {
                when dataIn.result.receive;
                effect backlightOn := true;
            }
            transition Showing -> ErrorState {
                when !backlightOn;
            }
            transition ErrorState -> Dark {
                when handlePowerOff.complete;
            }
        }
    }

    // ===== Top-level System Part =====
    part def RadarGunSystem {
        attribute minSpeed : SpeedMps = 1.4;
        attribute maxSpeed : SpeedMps = 111;
        attribute maxRange : DistanceM = 500;
        attribute operatingFrequency : FrequencyGHz = 24.15;

        part powerSupply : PowerSupply;
        part controlUnit : ControlUnit;
        part transmitter : TransmitterModule;
        part antenna : Antenna;
        part receiver : ReceiverModule;
        part processor : SignalProcessingUnit;
        part display : DisplayModule;

        // Power distribution
        connection powerToControl connects powerSupply.powerOut to controlUnit.powerIn;
        connection powerToTransmitter connects powerSupply.powerOut to transmitter.powerIn;
        connection powerToReceiver connects powerSupply.powerOut to receiver.powerIn;
        connection powerToProcessor connects powerSupply.powerOut to processor.powerIn;
        connection powerToDisplay connects powerSupply.powerOut to display.powerIn;

        // Control commands to transmitter
        connection controlToTransmitterTrigger connects controlUnit.controlOut to transmitter.triggerIn;

        // Transmitter radiated pulse to antenna
        connection txToAntenna connects transmitter.txOut to antenna.txIn;

        // Antenna received echo to receiver
        connection antennaToReceiver connects antenna.rxOut to receiver.rxIn;

        // Transmitter reference pulse to processor
        connection txToProcessor connects transmitter.txOut to processor.pulseIn;

        // Receiver filtered echo to processor
        connection receiverToProcessor connects receiver.rxOut to processor.echoIn;

        // Processor result to display
        connection processorToDisplay connects processor.resultOut to display.dataIn;
    }

    // ===== Requirements =====
    requirement def SpeedRangeRequirement {
        doc << "The system shall measure target speeds from 1.4 m/s to 111 m/s." >>;
        attribute minSpeed : SpeedMps = 1.4;
        attribute maxSpeed : SpeedMps = 111;
        subject radarGun : RadarGunSystem;
        requirement {
            assert radarGun.minSpeed >= minSpeed;
            assert radarGun.maxSpeed <= maxSpeed;
        }
    }

    requirement def DetectionRangeRequirement {
        doc << "The system shall detect targets at distances up to 500 meters." >>;
        attribute maxRange : DistanceM = 500;
        subject radarGun : RadarGunSystem;
        requirement {
            assert radarGun.maxRange <= maxRange;
        }
    }

    requirement def OperatingFrequencyRequirement {
        doc << "The transmitter shall operate at approximately 24.15 GHz." >>;
        attribute nominalFrequency : FrequencyGHz = 24.15;
        subject transmitter : TransmitterModule;
        requirement {
            assert transmitter.carrierFrequency == nominalFrequency;
        }
    }

    requirement def PowerStabilityRequirement {
        doc << "The power supply shall provide stable voltage to all modules." >>;
        subject powerSupply : PowerSupply;
        requirement {
            assert powerSupply.nominalVoltage == 12;
            assert powerSupply.maxCurrent >= 2.0;
        }
    }

    requirement def DopplerShiftRequirement {
        doc << "The signal processor shall compute the Doppler shift from transmitted pulse and received echo." >>;
        subject processor : SignalProcessingUnit;
        requirement {
            assert processor.processMeasurement.computeDoppler.isCalled;
        }
    }

    requirement def RangeEstimationRequirement {
        doc << "The signal processor shall estimate target distance by measuring pulse-echo time delay." >>;
        subject processor : SignalProcessingUnit;
        requirement {
            assert processor.processMeasurement.computeRange.isCalled;
        }
    }

    requirement def MeasurementValidationRequirement {
        doc << "The signal processor shall validate the measurement and emit an error code if invalid." >>;
        subject processor : SignalProcessingUnit;
        requirement {
            assert processor.processMeasurement.validate.isCalled;
        }
    }

    requirement def DisplayOutputRequirement {
        doc << "The display shall show speed or an error code based on measurement validity." >>;
        subject display : DisplayModule;
        requirement {
            assert display.showSpeed.isCalled;
        }
    }

    requirement def EchoAmplificationRequirement {
        doc << "The receiver shall filter noise and amplify the echo before processing." >>;
        subject receiver : ReceiverModule;
        requirement {
            assert receiver.processEcho.isCalled;
        }
    }

    // ===== Top-level instance satisfying requirements =====
    part radarGunInstance : RadarGunSystem {
        satisfy SpeedRangeRequirement;
        satisfy DetectionRangeRequirement;
        satisfy OperatingFrequencyRequirement;
        satisfy PowerStabilityRequirement;
        satisfy DopplerShiftRequirement;
        satisfy RangeEstimationRequirement;
        satisfy MeasurementValidationRequirement;
        satisfy DisplayOutputRequirement;
        satisfy EchoAmplificationRequirement;
    }
}
