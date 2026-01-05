package WeatherRadarSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def PowerValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def ReflectivityValue :> Real;
    attribute def AzimuthAngle :> Real;
    attribute def ElevationAngle :> Real;

    enum def PrecipitationType {
        rain;
        snow;
        hail;
        sleet;
        mixed;
    }

    enum def ScanPattern {
        volumeScan;
        sectorScan;
        ppi;
        rhi;
    }

    item def RadarPulse {
        attribute frequency : FrequencyValue;
        attribute power : PowerValue;
        attribute pulseWidth : DurationValue;
        attribute timestamp : DateTime;
    }

    item def EchoSignal {
        attribute receivedPower : PowerValue;
        attribute range : LengthValue;
        attribute azimuth : AzimuthAngle;
        attribute elevation : ElevationAngle;
        attribute dopplerVelocity : SpeedValue;
        attribute timestamp : DateTime;
    }

    item def WeatherProduct {
        attribute reflectivity : ReflectivityValue;
        attribute precipitationType : PrecipitationType;
        attribute precipitationRate : Real;
        attribute windVelocity : SpeedValue;
        attribute coverage : LengthValue;
        attribute timestamp : DateTime;
    }

    port def RfTransmitPort {
        out transmittedPulse : RadarPulse;
    }

    port def RfReceivePort {
        in receivedEcho : EchoSignal;
    }

    port def DataPort {
        out weatherData : WeatherProduct;
    }

    port def ControlPort {
        in scanPattern : ScanPattern;
        in targetAzimuth : AzimuthAngle;
        in targetElevation : ElevationAngle;
    }

    part def Transmitter {
        attribute operatingFrequency : FrequencyValue = 2.8E9 [Hz];
        attribute peakPower : PowerValue = 750000.0;
        attribute pulseRepetitionFrequency : FrequencyValue = 1000.0 [Hz];
        attribute pulseWidth : DurationValue = 1.0E-6 [s];

        port txPort : RfTransmitPort;

        action generatePulse {
            out pulse : RadarPulse {
                :>> frequency = operatingFrequency;
                :>> power = peakPower;
                :>> pulseWidth;
            }
        }
    }

    part def Receiver {
        attribute sensitivity : PowerValue = 1.0E-13;
        attribute bandwidth : FrequencyValue = 1.0E6 [Hz];
        attribute dynamicRange : Real = 100.0;

        port rxPort : RfReceivePort;

        action amplifyEcho {
            in echo : EchoSignal;
            out amplifiedEcho : EchoSignal;
        }

        action filterSignal {
            in rawEcho : EchoSignal;
            out filteredEcho : EchoSignal;
        }
    }

    part def AntennaSystem {
        attribute diameter : LengthValue = 8.5 [m];
        attribute gain : Real = 45.0;
        attribute beamWidth : AzimuthAngle = 1.0;
        attribute rotationRate : Real = 6.0;
        attribute currentAzimuth : AzimuthAngle;
        attribute currentElevation : ElevationAngle;

        port rfPort : RfTransmitPort;
        port echoPort : RfReceivePort;
        port ctrlPort : ControlPort;

        part positioner {
            attribute azimuthPosition : AzimuthAngle;
            attribute elevationPosition : ElevationAngle;
            attribute azimuthSpeed : Real;
            attribute elevationSpeed : Real;
        }

        action positionAntenna {
            in targetAz : AzimuthAngle;
            in targetEl : ElevationAngle;

            first start;
            then action moveToPosition {
                out newAzimuth : AzimuthAngle;
                out newElevation : ElevationAngle;
            }
            then done;
        }
    }

    part def SignalProcessor {
        attribute processingCapacity : Real = 1.0E9;
        attribute memorySize : Real = 64.0E9;

        action processEcho {
            in echo : EchoSignal;
            out weatherData : WeatherProduct;

            first start;
            then action computeRange {
                in echoTime : DurationValue;
                out range : LengthValue;
            }
            then action computeVelocity {
                in dopplerShift : FrequencyValue;
                out velocity : SpeedValue;
            }
            then action estimateReflectivity {
                in echoPower : PowerValue;
                in distance : LengthValue;
                out reflectivity : ReflectivityValue;
            }
            then action classifyPrecipitation {
                in reflectivity : ReflectivityValue;
                in velocity : SpeedValue;
                out precipType : PrecipitationType;
            }
            then done;
        }
    }

    part def DisplayUnit {
        attribute screenResolution : Real[2] = (1920.0, 1080.0);
        attribute refreshRate : Real = 30.0;

        port dataInput : DataPort;

        action renderWeatherDisplay {
            in weatherData : WeatherProduct;

            first start;
            then action createReflectivityMap;
            then action overlayVelocityData;
            then action updateScreen;
            then done;
        }
    }

    part def PowerSubsystem {
        attribute inputVoltage : Real = 480.0;
        attribute outputVoltage : Real = 28.0;
        attribute maxCurrent : Real = 250.0;
        attribute efficiency : Real = 0.90;

        assert constraint efficiencyConstraint {
            efficiency >= 0.85 and efficiency <= 0.95
        }
    }

    action def TransmitRadarPulse {
        in frequency : FrequencyValue;
        in power : PowerValue;
        out pulse : RadarPulse;
    }

    action def ReceiveEcho {
        in transmittedPulse : RadarPulse;
        out echo : EchoSignal;
    }

    action def ProcessWeatherData {
        in echoSignals : EchoSignal[0..*];
        out weatherReport : WeatherProduct;
    }

    action def PerformScan {
        in scanMode : ScanPattern;
        out detectedWeather : WeatherProduct;
    }

    action def WeatherRadarOperation {
        first start;
        then merge continuousOperation;

        then action initScan : PerformScan {
            in scanMode = ScanPattern::volumeScan;
        }

        then action transmit : TransmitRadarPulse {
            in frequency = 2.8E9;
            in power = 750000.0;
        }

        then action receive : ReceiveEcho {
            in transmittedPulse = transmit.pulse;
        }

        then action process : ProcessWeatherData {
            in echoSignals = (receive.echo);
        }

        then decide;
            if process.weatherReport.precipitationType == PrecipitationType::rain
                then issueAlert;
            if process.weatherReport.precipitationType != PrecipitationType::rain
                then continuousOperation;

        action issueAlert {
            in weatherData : WeatherProduct = process.weatherReport;
        }
        then continuousOperation;
    }

    state def RadarOperationalStates {
        entry; then Offline;
        
        state Offline;
        state Standby;
        state Scanning;
        state Processing;
        state Transmitting;

        transition powerUp first Offline accept at Offline then Standby;
        transition beginScan first Standby accept at Standby then Scanning;
        transition startTransmit first Scanning accept at Scanning then Transmitting;
        transition receiveData first Transmitting accept at Transmitting then Processing;
        transition completeCycle first Processing accept at Processing then Scanning;
        transition shutdown first Standby accept at Standby then Offline;
    }

    part def WeatherRadar {
        attribute operatingFrequency : FrequencyValue = 2.8E9 [Hz];
        attribute maximumRange : LengthValue = 460.0 [km];
        attribute rangeResolution : LengthValue = 250.0 [m];
        attribute angularResolution : AzimuthAngle = 1.0;
        attribute totalMass : MassValue;
        attribute updateInterval : DurationValue = 5.0 [s];

        part transmitter : Transmitter {
            :>> operatingFrequency = 2.8E9 [Hz];
            :>> peakPower = 750000.0;
            :>> pulseRepetitionFrequency = 1000.0 [Hz];
            :>> pulseWidth = 1.0E-6 [s];
        }

        part receiver : Receiver {
            :>> sensitivity = 1.0E-13;
            :>> bandwidth = 1.0E6 [Hz];
            :>> dynamicRange = 100.0;
        }

        part antenna : AntennaSystem {
            :>> diameter = 8.5 [m];
            :>> gain = 45.0;
            :>> beamWidth = 1.0;
            :>> rotationRate = 6.0;
        }

        part processor : SignalProcessor {
            :>> processingCapacity = 1.0E9;
            :>> memorySize = 64.0E9;
        }

        part display : DisplayUnit {
            :>> screenResolution = (1920.0, 1080.0);
            :>> refreshRate = 30.0;
        }

        part power : PowerSubsystem {
            :>> inputVoltage = 480.0;
            :>> outputVoltage = 28.0;
            :>> maxCurrent = 250.0;
            :>> efficiency = 0.90;
        }

        connection txToAntenna connect transmitter.txPort to antenna.rfPort;
        connection antennaToRx connect antenna.echoPort to receiver.rxPort;

        perform action radarOps : WeatherRadarOperation;
        state stateMachine : RadarOperationalStates;
    }

    requirement <'REQ-WR-100'> detectAtmosphericPhenomena {
        doc /* The weather radar system shall detect, locate, and characterize 
             * atmospheric precipitation and weather phenomena within its operational 
             * range to provide timely meteorological data for weather forecasting 
             * and severe weather warning.
             */
        subject radar : WeatherRadar;

        require rangeRequirement;
        require resolutionRequirement;
        require updateRateRequirement;
    }

    requirement <'REQ-WR-101'> rangeRequirement {
        doc /* The weather radar shall provide detection capability 
             * out to a minimum range of 460 km.
             */
        subject radar : WeatherRadar;

        assert constraint {
            radar.maximumRange >= 460.0 [km]
        }
    }

    requirement <'REQ-WR-102'> resolutionRequirement {
        doc /* The weather radar shall achieve a range resolution 
             * of 250 meters or better.
             */
        subject radar : WeatherRadar;

        assert constraint {
            radar.rangeResolution <= 250.0 [m]
        }
    }

    requirement <'REQ-WR-103'> updateRateRequirement {
        doc /* The weather radar shall complete a full volume scan 
             * and update weather products every 5 seconds or faster.
             */
        subject radar : WeatherRadar;

        assert constraint {
            radar.updateInterval <= 5.0 [s]
        }
    }

    requirement <'REQ-WR-104'> massConstraint {
        doc /* The total mass of the weather radar system shall not 
             * exceed 5000 kg to meet installation requirements.
             */
        subject radar : WeatherRadar;

        assert constraint {
            radar.totalMass <= 5000.0 [kg]
        }
    }

    part weatherRadarStation : WeatherRadar {
        :>> totalMass = 4500.0 [kg];
        :>> maximumRange = 460.0 [km];
        :>> rangeResolution = 250.0 [m];
        :>> updateInterval = 5.0 [s];
    }

    satisfy detectAtmosphericPhenomena by weatherRadarStation;
}
