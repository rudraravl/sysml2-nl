package WeatherRadarSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute GHz : FrequencyUnit = 1.0E9 * Hz;
    attribute kW : PowerUnit = 1000.0 * W;
    attribute us : TimeUnit = 1.0E-6 * s;

    item def Power {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }

    item def RFPulse {
        attribute frequency : FrequencyValue;
        attribute peakPower : PowerValue;
        attribute pulseWidth : TimeValue;
    }

    item def EchoSignal {
        attribute returnTime : TimeValue;
        attribute strength : PowerValue;
        attribute dopplerShift : FrequencyValue;
    }

    item def AmplifiedSignal :> EchoSignal;

    item def ScanCommand {
        attribute azimuth : PlaneAngleValue;
        attribute elevation : PlaneAngleValue;
        attribute scanMode : String;
    }

    item def WeatherProduct {
        attribute distance : LengthValue;
        attribute reflectivity : Real;
        attribute windVelocity : SpeedValue;
        attribute precipitationType : String;
        attribute timestamp : TimeValue;
    }

    port def PowerPort {
        out item power : Power;
    }

    port def PulsePort {
        out item pulse : RFPulse;
    }

    port def EchoPort {
        out item echo : EchoSignal;
    }

    port def AmplifiedSignalPort {
        out item signal : AmplifiedSignal;
    }

    port def ScanControlPort {
        in item command : ScanCommand;
    }

    port def WeatherDataPort {
        out item data : WeatherProduct;
    }

    part def PowerSubsystem {
        attribute inputVoltage : ElectricPotentialValue;
        attribute outputVoltage : ElectricPotentialValue;
        port highVoltageIn : ~PowerPort;
        port powerOut : PowerPort;
    }

    part def Transmitter {
        port powerIn : ~PowerPort;
        port pulseOut : PulsePort;
    }

    part def AntennaSystem {
        attribute dishDiameter : LengthValue = 8.5 [m];
        attribute azimuthAngle : PlaneAngleValue;
        attribute elevationAngle : PlaneAngleValue;
        port powerIn : ~PowerPort;
        port pulseIn : ~PulsePort;
        port echoOut : EchoPort;
        port controlIn : ScanControlPort;
    }

    part def Receiver {
        attribute sensitivity : Real;
        port powerIn : ~PowerPort;
        port echoIn : ~EchoPort;
        port signalOut : AmplifiedSignalPort;
    }

    part def SignalProcessor {
        port powerIn : ~PowerPort;
        port signalIn : ~AmplifiedSignalPort;
        port dataOut : WeatherDataPort;
    }

    part def DisplayUnit {
        port powerIn : ~PowerPort;
        port dataIn : ~WeatherDataPort;
    }

    action def TransmitPulse {
        out pulse : RFPulse;
    }

    action def ReceiveEcho {
        in echo : EchoSignal;
    }

    action def ProcessData {
        in signal : AmplifiedSignal;
        out data : WeatherProduct;
    }

    action def RenderWeatherMap {
        in data : WeatherProduct;
    }

    attribute def PowerOn;
    attribute def StartScan;
    attribute def StopScan;
    attribute def PowerOff;

    state def RadarOperationalState {
        entry; then Offline;

        state Offline;
        state Standby;
        state ActiveScanning {
            entry; then Transmitting;

            state Transmitting {
                do action TransmitPulse;
            }
            state Receiving {
                do action ReceiveEcho;
            }
            state Processing {
                do action ProcessData;
            }
            state UpdatingDisplay {
                do action RenderWeatherMap;
            }

            transition first Transmitting then Receiving;
            transition first Receiving then Processing;
            transition first Processing then UpdatingDisplay;
            transition first UpdatingDisplay accept after 5.0 [s] then Transmitting;
        }

        transition first Offline accept PowerOn then Standby;
        transition first Standby accept StartScan then ActiveScanning;
        transition first Standby accept PowerOff then Offline;
        transition first ActiveScanning accept StopScan then Standby;
        transition first ActiveScanning accept PowerOff then Offline;
    }

    part def WeatherRadar {
        attribute maxDetectionRange : LengthValue;
        attribute rangeResolution : LengthValue;
        attribute velocityAccuracy : SpeedValue;
        attribute updateInterval : TimeValue;
        attribute classificationAccuracy : Real;

        part powerSubsystem : PowerSubsystem;
        part transmitter : Transmitter;
        part antenna : AntennaSystem;
        part receiver : Receiver;
        part signalProcessor : SignalProcessor;
        part display : DisplayUnit;

        flow powerToTransmitter of Power
            from powerSubsystem.powerOut.power to transmitter.powerIn.power;
        flow powerToAntenna of Power
            from powerSubsystem.powerOut.power to antenna.powerIn.power;
        flow powerToReceiver of Power
            from powerSubsystem.powerOut.power to receiver.powerIn.power;
        flow powerToProcessor of Power
            from powerSubsystem.powerOut.power to signalProcessor.powerIn.power;
        flow powerToDisplay of Power
            from powerSubsystem.powerOut.power to display.powerIn.power;

        flow pulseToAntenna of RFPulse
            from transmitter.pulseOut.pulse to antenna.pulseIn.pulse;
        flow echoToReceiver of EchoSignal
            from antenna.echoOut.echo to receiver.echoIn.echo;
        flow echoToProcessor of AmplifiedSignal
            from receiver.signalOut.signal to signalProcessor.signalIn.signal;
        flow dataToDisplay of WeatherProduct
            from signalProcessor.dataOut.data to display.dataIn.data;

        state operationalState : RadarOperationalState;
    }

    requirement def WeatherRadarRequirement {
        subject radar : WeatherRadar;
    }

    requirement def AntennaDishRequirement :> WeatherRadarRequirement {
        doc /* The antenna dish diameter shall be 8.5 meters. */
        require constraint { radar.antenna.dishDiameter == 8.5 [m] }
    }

    requirement def DetectionRangeRequirement :> WeatherRadarRequirement {
        doc /* The radar shall detect precipitation at ranges up to 300 km. */
        attribute requiredRange : LengthValue = 300.0 [km];
        require constraint { radar.maxDetectionRange >= requiredRange }
    }

    requirement def RangeResolutionRequirement :> WeatherRadarRequirement {
        doc /* The radar shall resolve targets separated by 150 m or less in range. */
        attribute requiredResolution : LengthValue = 150.0 [m];
        require constraint { radar.rangeResolution <= requiredResolution }
    }

    requirement def VelocityAccuracyRequirement :> WeatherRadarRequirement {
        doc /* The radar shall measure wind velocity with accuracy of 1 m/s or better. */
        attribute requiredAccuracy : SpeedValue = 1.0 [m/s];
        require constraint { radar.velocityAccuracy <= requiredAccuracy }
    }

    requirement def UpdateRateRequirement :> WeatherRadarRequirement {
        doc /* The radar shall provide updated weather products every 5 seconds. */
        attribute requiredInterval : TimeValue = 5.0 [s];
        require constraint { radar.updateInterval <= requiredInterval }
    }

    requirement def PrecipitationClassificationRequirement :> WeatherRadarRequirement {
        doc /* The radar shall classify precipitation type with at least 90% accuracy. */
        attribute requiredAccuracy : Real = 90.0;
        require constraint { radar.classificationAccuracy >= requiredAccuracy }
    }

    analysis def WeatherRadarVerification {
        subject radar : WeatherRadar;
        requirement antennaReq : AntennaDishRequirement;
        requirement rangeReq : DetectionRangeRequirement;
        requirement resolutionReq : RangeResolutionRequirement;
        requirement velocityReq : VelocityAccuracyRequirement;
        requirement updateReq : UpdateRateRequirement;
        requirement classificationReq : PrecipitationClassificationRequirement;
        objective verifyAll {
            doc /* Verify all weather radar system requirements are satisfied. */
        }
    }
}
