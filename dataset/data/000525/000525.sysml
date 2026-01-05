package AirIoniserSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    enum def OperatingMode {
        off;
        standby;
        low;
        medium;
        high;
        auto;
    }

    enum def AirQualityLevel {
        excellent;
        good;
        moderate;
        poor;
        hazardous;
    }

    item def Air {
        attribute particulateConcentration : Real;
        attribute ionDensity : Real;
        attribute qualityLevel : AirQualityLevel;
        attribute temperature : TemperatureValue;
        attribute humidity : Real;
    }

    item def NegativeIon {
        attribute chargeValue : Real;
        attribute lifetime : DurationValue;
    }

    port def AirFlowPort {
        in item airIn : Air;
        out item airOut : Air;
    }

    port def PowerPort {
        in voltage : Real;
        in current : Real;
    }

    port def ControlSignalPort {
        in commandSignal : Real;
        out statusSignal : Real;
    }

    port def SensorDataPort {
        out particulateLevel : Real;
        out ionLevel : Real;
        out airQuality : AirQualityLevel;
    }

    part def HighVoltageGenerator {
        attribute inputVoltage : Real;
        attribute outputVoltage : Real;
        attribute efficiency : Real;
        attribute powerConsumption : PowerValue;

        port powerIn : PowerPort;
        port hvOut : PowerPort;
        port control : ControlSignalPort;
    }

    part def IonizationNeedle {
        attribute needleCount : Integer;
        attribute emissionRate : Real;
        attribute coronaVoltage : Real;

        port hvIn : PowerPort;
        port ionOut;
    }

    part def CirculationFan {
        attribute rotationSpeed : Real;
        attribute airFlowRate : Real;
        attribute powerConsumption : PowerValue;
        attribute noiseLevel : Real;

        port powerIn : PowerPort;
        port airFlow : AirFlowPort;
        port speedControl : ControlSignalPort;
    }

    part def AirQualitySensor {
        attribute measurementAccuracy : Real;
        attribute responseTime : DurationValue;
        attribute calibrationDate : String;

        port samplePort;
        port dataOut : SensorDataPort;
        port powerIn : PowerPort;
    }

    part def ControlModule {
        attribute currentMode : OperatingMode;
        attribute targetIonDensity : Real;
        attribute maxParticulateThreshold : Real;
        attribute autoAdjustEnabled : Boolean;

        port sensorInput : SensorDataPort;
        port fanControl : ControlSignalPort;
        port hvControl : ControlSignalPort;
        port userInterface;
        port powerIn : PowerPort;
    }

    part def PowerSupply {
        attribute inputVoltage : Real;
        attribute outputVoltage : Real;
        attribute maxCurrent : Real;
        attribute efficiency : Real;

        port acInput : PowerPort;
        port dcOutput1 : PowerPort;
        port dcOutput2 : PowerPort;
        port dcOutput3 : PowerPort;
        port dcOutput4 : PowerPort;
    }

    part def PreFilter {
        attribute filterType : String;
        attribute efficiency : Real;
        attribute dustCapacity : MassValue;
        attribute replacementInterval : DurationValue;

        port airFlow : AirFlowPort;
    }

    part def OzoneCatalyst {
        attribute conversionEfficiency : Real;
        attribute surfaceArea : AreaValue;
        attribute operatingTemperature : TemperatureValue;

        port airFlow : AirFlowPort;
    }

    part def AirIoniser {
        attribute operatingMode : OperatingMode;
        attribute coverageArea : AreaValue;
        attribute totalMass : MassValue;
        attribute totalPowerConsumption : PowerValue;
        attribute maxIonOutput : Real;

        port mainsPowerIn : PowerPort;
        port airIntake : AirFlowPort;
        port airOutlet : AirFlowPort;

        part powerSupply : PowerSupply {
            attribute :>> inputVoltage = 120.0;
            attribute :>> outputVoltage = 12.0;
            attribute :>> maxCurrent = 3.0;
            attribute :>> efficiency = 0.88;
        }

        part controlModule : ControlModule {
            attribute :>> currentMode = OperatingMode::standby;
            attribute :>> targetIonDensity = 5000000.0;
            attribute :>> maxParticulateThreshold = 35.0;
            attribute :>> autoAdjustEnabled = true;
        }

        part hvGenerator : HighVoltageGenerator {
            attribute :>> inputVoltage = 12.0;
            attribute :>> outputVoltage = 7000.0;
            attribute :>> efficiency = 0.82;
            attribute :>> powerConsumption = 8.0 [W];
        }

        part ionNeedles : IonizationNeedle[6] {
            attribute :>> needleCount = 6;
            attribute :>> emissionRate = 1200000.0;
            attribute :>> coronaVoltage = 7000.0;
        }

        part circulationFan : CirculationFan {
            attribute :>> rotationSpeed = 1500.0;
            attribute :>> airFlowRate = 180.0;
            attribute :>> powerConsumption = 12.0 [W];
            attribute :>> noiseLevel = 32.0;
        }

        part preFilter : PreFilter {
            attribute :>> filterType = "HEPA";
            attribute :>> efficiency = 0.95;
            attribute :>> dustCapacity = 60.0 [kg];
            attribute :>> replacementInterval = 2160.0 [s];
        }

        part ozoneCatalyst : OzoneCatalyst {
            attribute :>> conversionEfficiency = 0.92;
            attribute :>> surfaceArea = 0.05 [m^2];
            attribute :>> operatingTemperature = 298.0 [K];
        }

        part airQualitySensor : AirQualitySensor {
            attribute :>> measurementAccuracy = 0.95;
            attribute :>> responseTime = 5.0 [s];
            attribute :>> calibrationDate = "2025-01-01";
        }

        connection c1 connect powerSupply.acInput to mainsPowerIn;
        connection c2 connect powerSupply.dcOutput1 to controlModule.powerIn;
        connection c3 connect powerSupply.dcOutput2 to hvGenerator.powerIn;
        connection c4 connect powerSupply.dcOutput3 to circulationFan.powerIn;
        connection c5 connect powerSupply.dcOutput4 to airQualitySensor.powerIn;

        connection c6 connect hvGenerator.hvOut to ionNeedles.hvIn;
        connection c7 connect airQualitySensor.dataOut to controlModule.sensorInput;
        connection c8 connect controlModule.fanControl to circulationFan.speedControl;
        connection c9 connect controlModule.hvControl to hvGenerator.control;

        connection c10 connect airIntake to preFilter.airFlow.airIn;
        connection c11 connect preFilter.airFlow.airOut to circulationFan.airFlow.airIn;
        connection c12 connect circulationFan.airFlow.airOut to ozoneCatalyst.airFlow.airIn;
        connection c13 connect ozoneCatalyst.airFlow.airOut to airOutlet;
    }

    action def MonitorAirQuality {
        in airSample : Air;
        out measuredQuality : AirQualityLevel;
        out measuredParticulateLevel : Real;
        out measuredIonDensity : Real;
    }

    action def GenerateNegativeIons {
        in appliedVoltage : Real;
        in operatingMode : OperatingMode;
        out generatedIons : NegativeIon[*];
        out ionDensity : Real;
    }

    action def CirculateAir {
        in fanSpeed : Real;
        in incomingAir : Air;
        out processedAir : Air;
        out flowRate : Real;
    }

    action def AdjustOperatingParameters {
        in currentAirQuality : AirQualityLevel;
        in currentParticulateLevel : Real;
        in targetIonDensity : Real;
        out newMode : OperatingMode;
        out newFanSpeed : Real;
        out newVoltage : Real;
    }

    action def PurifyAir {
        first start;
        then merge monitoringCycle;

        then action monitor : MonitorAirQuality {
            in airSample : Air;
            out currentQuality : AirQualityLevel;
            out currentParticulateLevel : Real;
            out currentIonDensity : Real;
        }

        then action adjust : AdjustOperatingParameters {
            in currentAirQuality = monitor.currentQuality;
            in currentParticulateLevel = monitor.currentParticulateLevel;
            in targetIonDensity : Real;
            out operatingMode : OperatingMode;
            out fanSpeed : Real;
            out voltage : Real;
        }

        then decide;
            if adjust.operatingMode == OperatingMode::off then shutdown;
            if adjust.operatingMode != OperatingMode::off then ionize;

        action ionize : GenerateNegativeIons {
            in appliedVoltage = adjust.voltage;
            in operatingMode = adjust.operatingMode;
            out generatedIons : NegativeIon[*];
            out ionDensity : Real;
        }

        then action circulate : CirculateAir {
            in fanSpeed = adjust.fanSpeed;
            in incomingAir : Air;
            out processedAir : Air;
            out flowRate : Real;
        }

        then monitoringCycle;

        action shutdown;
        then done;
    }

    state def AirIoniserStateMachine {
        entry; then powerOff;

        state powerOff;
        transition powerOff_to_standby
            first powerOff
            accept OperatingMode::standby
            then standby;

        state standby;
        transition standby_to_operating
            first standby
            accept OperatingMode::auto
            then operating;

        state operating {
            entry; then lowPower;

            state lowPower;
            state mediumPower;
            state highPower;
            state autoPower;

            transition low_to_medium
                first lowPower
                accept OperatingMode::medium
                then mediumPower;

            transition medium_to_high
                first mediumPower
                accept OperatingMode::high
                then highPower;

            transition high_to_auto
                first highPower
                accept OperatingMode::auto
                then autoPower;

            transition auto_to_low
                first autoPower
                accept OperatingMode::low
                then lowPower;
        }

        transition operating_to_standby
            first operating
            accept OperatingMode::standby
            then standby;

        transition standby_to_powerOff
            first standby
            accept OperatingMode::off
            then powerOff;
    }

    requirement def AirPurificationRequirement {
        doc /* The air ioniser shall purify indoor air by generating negative ions 
             * that attach to airborne particles, causing them to precipitate out 
             * of the air, thereby improving overall air quality. */
        subject ioniser : AirIoniser;
    }

    requirement def IonGenerationCapability {
        doc /* The system shall generate at least 5 million negative ions per cubic 
             * centimeter to effectively neutralize airborne contaminants. */
        subject ioniser : AirIoniser;
        assert constraint {
            ioniser.maxIonOutput >= 5000000.0
        }
    }

    requirement def CoverageAreaRequirement {
        doc /* The air ioniser shall effectively purify air in a coverage area of 
             * at least 35 square meters. */
        subject ioniser : AirIoniser;
        assert constraint {
            ioniser.coverageArea >= 35.0 [m^2]
        }
    }

    requirement def PowerEfficiencyRequirement {
        doc /* The total power consumption shall not exceed 30 watts during 
             * continuous operation at maximum settings. */
        subject ioniser : AirIoniser;
        assert constraint {
            ioniser.totalPowerConsumption <= 30.0 [W]
        }
    }

    requirement def OzoneEmissionLimit {
        doc /* The ozone catalyst shall reduce ozone emissions to safe levels, 
             * with conversion efficiency of at least 90%. */
        subject catalyst : OzoneCatalyst;
        assert constraint {
            catalyst.conversionEfficiency >= 0.90
        }
    }

    requirement def NoiseRequirement {
        doc /* The circulation fan shall operate at a noise level not exceeding 
             * 35 dB at maximum speed. */
        subject fan : CirculationFan;
        assert constraint {
            fan.noiseLevel <= 35.0
        }
    }

    requirement def FilterEfficiencyRequirement {
        doc /* The pre-filter shall remove at least 95% of airborne particles 
             * before air reaches the ionization chamber. */
        subject prefilter : PreFilter;
        assert constraint {
            prefilter.efficiency >= 0.95
        }
    }

    part airIoniserSystem : AirIoniser {
        attribute :>> operatingMode = OperatingMode::auto;
        attribute :>> coverageArea = 40.0 [m^2];
        attribute :>> totalMass = 2.8 [kg];
        attribute :>> totalPowerConsumption = 25.0 [W];
        attribute :>> maxIonOutput = 6000000.0;

        perform action purifyAir : PurifyAir;
        exhibit state ioniserBehavior : AirIoniserStateMachine;
    }

    satisfy AirPurificationRequirement by airIoniserSystem;
    satisfy IonGenerationCapability by airIoniserSystem;
    satisfy CoverageAreaRequirement by airIoniserSystem;
    satisfy PowerEfficiencyRequirement by airIoniserSystem;
    satisfy OzoneEmissionLimit by airIoniserSystem.ozoneCatalyst;
    satisfy NoiseRequirement by airIoniserSystem.circulationFan;
    satisfy FilterEfficiencyRequirement by airIoniserSystem.preFilter;
}
