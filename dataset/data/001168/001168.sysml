package 'Oscillating U-Tube Densitometer System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def FluidDensity :> ISQ::MassDensityValue;
    attribute def OscillationFrequency :> ISQ::FrequencyValue;
    attribute def OscillationPeriod :> ISQ::TimeValue;
    attribute def FluidTemperature :> ISQ::ThermodynamicTemperatureValue;
    attribute def FluidPressure :> ISQ::PressureValue;
    attribute def FluidViscosity :> ISQ::DynamicViscosityValue;
    attribute def TubeDisplacement :> ISQ::LengthValue;
    attribute def PhaseAngle :> Real;
    attribute def MassFlowRate :> ISQ::MassFlowRateValue;
    attribute def VolumeFlowRate :> ISQ::VolumeFlowRateValue;
    attribute def CalibrationConstant :> Real;
    
    attribute def TubeGeometry {
        attribute innerDiameter : ISQ::LengthValue;
        attribute wallThickness : ISQ::LengthValue;
        attribute totalLength : ISQ::LengthValue;
        attribute bendRadius : ISQ::LengthValue;
    }

    item def ProcessFluid {
        attribute density : FluidDensity;
        attribute temperature : FluidTemperature;
        attribute pressure : FluidPressure;
        attribute viscosity : FluidViscosity;
        attribute massFlowRate : MassFlowRate;
    }

    port def FluidPort {
        in item fluid : ProcessFluid;
        attribute pressure : FluidPressure;
        attribute temperature : FluidTemperature;
    }

    port def SignalPort {
        out attribute signal : Real;
    }

    port def ControlPort {
        in attribute command : Real;
        out attribute status : Real;
    }

    port def DataPort {
        out attribute density : FluidDensity;
        out attribute massFlow : MassFlowRate;
        out attribute temperature : FluidTemperature;
    }

    part def UTubeSensor {
        attribute geometry : TubeGeometry;
        attribute tubeMaterial : String;
        attribute springConstant : Real;
        attribute dampingCoefficient : Real;
        attribute resonantFrequency : OscillationFrequency;
        
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port mechanicalOutput : SignalPort;
    }

    part def ElectromagneticDriver {
        attribute driveFrequency : OscillationFrequency;
        attribute driveAmplitude : ISQ::ElectricCurrentValue;
        attribute drivePower : ISQ::PowerValue;
        
        port controlInput : ControlPort;
        port mechanicalDrive : SignalPort;
    }

    part def OpticalSensor {
        attribute samplingRate : OscillationFrequency;
        attribute resolution : TubeDisplacement;
        attribute measurementRange : TubeDisplacement;
        
        port mechanicalInput : SignalPort;
        port digitalOutput : SignalPort;
    }

    part def TemperatureTransducer {
        attribute accuracy : FluidTemperature;
        attribute responseTime : ISQ::TimeValue;
        
        port measurementPoint : FluidPort;
        port temperatureOutput : SignalPort;
    }

    part def PressureTransducer {
        attribute accuracy : FluidPressure;
        attribute measurementRange : FluidPressure;
        
        port measurementPoint : FluidPort;
        port pressureOutput : SignalPort;
    }

    part def DigitalSignalProcessor {
        attribute processingRate : OscillationFrequency;
        attribute filterBandwidth : OscillationFrequency;
        
        port sensorInput1 : SignalPort;
        port sensorInput2 : SignalPort;
        port temperatureInput : SignalPort;
        port pressureInput : SignalPort;
        port dataOutput : DataPort;
        port controlOutput : ControlPort;
    }

    action def InitializeDrive {
        in targetFrequency : OscillationFrequency;
        in targetAmplitude : Real;
        out driveSignal : Real;
    }

    action def MeasureTubeDisplacement {
        in opticalSignal : Real;
        out displacement : TubeDisplacement;
        out instantaneousFrequency : OscillationFrequency;
    }

    action def CalculateOscillationPeriod {
        in displacementHistory : TubeDisplacement[*];
        in timeStamps : ISQ::TimeValue[*];
        out period : OscillationPeriod;
        out frequency : OscillationFrequency;
    }

    action def ComputeDensity {
        in oscillationPeriod : OscillationPeriod;
        in calibrationK1 : CalibrationConstant;
        in calibrationK2 : CalibrationConstant;
        in referenceTemperature : FluidTemperature;
        in measuredTemperature : FluidTemperature;
        out density : FluidDensity;
    }

    action def CompensateTemperature {
        in rawDensity : FluidDensity;
        in temperature : FluidTemperature;
        in temperatureCoefficient : Real;
        out compensatedDensity : FluidDensity;
    }

    action def CalculateMassFlow {
        in volumeFlowRate : VolumeFlowRate;
        in fluidDensity : FluidDensity;
        out massFlowRate : MassFlowRate;
    }

    action def ValidateMeasurement {
        in density : FluidDensity;
        in temperature : FluidTemperature;
        in pressure : FluidPressure;
        in frequency : OscillationFrequency;
        out isValid : Boolean;
        out qualityIndicator : Real;
    }

    action def PerformDensityMeasurement {
        in fluid : ProcessFluid;
        out measuredDensity : FluidDensity;
        out measuredMassFlow : MassFlowRate;
        out measurementQuality : Real;

        first start;
        then action initDrive : InitializeDrive;
        then merge continuousMeasurement;
        
        then fork parallelMeasurements;
        action measureDisplacement : MeasureTubeDisplacement parallel parallelMeasurements;
        action measureTemp parallel parallelMeasurements {
            out temperature : FluidTemperature;
        }
        action measurePress parallel parallelMeasurements {
            out pressure : FluidPressure;
        }
        
        then join synchronizeMeasurements;
        then action calcPeriod : CalculateOscillationPeriod {
            out period;
            out frequency;
        }
        then action computeDens : ComputeDensity {
            in oscillationPeriod = calcPeriod.period;
            in measuredTemperature = measureTemp.temperature;
            out density;
        }
        then action compensate : CompensateTemperature {
            in rawDensity = computeDens.density;
            in temperature = measureTemp.temperature;
            out compensatedDensity;
        }
        then action calcFlow : CalculateMassFlow {
            in fluidDensity = compensate.compensatedDensity;
            out massFlowRate;
        }
        then action validate : ValidateMeasurement {
            in density = compensate.compensatedDensity;
            in temperature = measureTemp.temperature;
            in pressure = measurePress.pressure;
            in frequency = calcPeriod.frequency;
            out isValid;
            out qualityIndicator;
        }
        then decide;
            if validate.isValid then updateOutput;
            if not validate.isValid then continuousMeasurement;
        
        action updateOutput {
            then assign measuredDensity := compensate.compensatedDensity;
            then assign measuredMassFlow := calcFlow.massFlowRate;
            then assign measurementQuality := validate.qualityIndicator;
        }
        then continuousMeasurement;
    }

    state def DensitometerStates {
        entry; then idle;
        
        state idle {
            doc /* System is powered but not actively measuring. */
        }
        
        transition idle_to_warmup
            first idle
            accept startCommand
            then warmup;
        
        state warmup {
            doc /* System is initializing sensors and establishing resonance. */
            entry; then initializeSensors;
            state initializeSensors;
            then establishResonance;
            state establishResonance;
        }
        
        transition warmup_to_calibration
            first warmup
            if resonanceStable
            then calibration;
        
        state calibration {
            doc /* System is performing zero-point and span calibration. */
            entry; then zeroCalibration;
            state zeroCalibration;
            then spanCalibration;
            state spanCalibration;
        }
        
        transition calibration_to_measuring
            first calibration
            if calibrationComplete
            then measuring;
        
        state measuring {
            doc /* System is actively measuring fluid density and mass flow. */
            entry; then activeMeasurement;
            state activeMeasurement {
                do action measure : PerformDensityMeasurement;
            }
        }
        
        transition measuring_to_maintenance
            first measuring
            accept maintenanceRequest
            then maintenance;
        
        transition measuring_to_fault
            first measuring
            if systemFault
            then fault;
        
        state maintenance {
            doc /* System is in maintenance mode for cleaning or recalibration. */
        }
        
        transition maintenance_to_calibration
            first maintenance
            accept recalibrateCommand
            then calibration;
        
        transition maintenance_to_idle
            first maintenance
            accept shutdownCommand
            then idle;
        
        state fault {
            doc /* System has detected a fault condition. */
            entry; then diagnostics;
            state diagnostics;
        }
        
        transition fault_to_idle
            first fault
            accept resetCommand
            then idle;
    }

    part def OscillatingUTubeDensitometer {
        doc /* 
            An oscillating U-tube densitometer measures fluid density by monitoring
            the resonant frequency of a vibrating U-shaped tube filled with the process fluid.
        */
        
        part uTube : UTubeSensor {
            attribute geometry : TubeGeometry {
                attribute innerDiameter = 3.0 [mm];
                attribute wallThickness = 0.5 [mm];
                attribute totalLength = 250.0 [mm];
                attribute bendRadius = 20.0 [mm];
            }
            attribute tubeMaterial = "Hastelloy C-276";
            attribute springConstant = 1500.0;
            attribute dampingCoefficient = 0.05;
            attribute resonantFrequency = 120.0 [Hz];
        }
        
        part driver : ElectromagneticDriver {
            attribute driveFrequency = uTube.resonantFrequency;
            attribute driveAmplitude = 0.5 [A];
            attribute drivePower = 2.0 [W];
        }
        
        part leftSensor : OpticalSensor {
            attribute samplingRate = 10000.0 [Hz];
            attribute resolution = 0.001 [mm];
            attribute measurementRange = 1.0 [mm];
        }
        
        part rightSensor : OpticalSensor {
            attribute samplingRate = 10000.0 [Hz];
            attribute resolution = 0.001 [mm];
            attribute measurementRange = 1.0 [mm];
        }
        
        part tempSensor : TemperatureTransducer {
            attribute accuracy = 0.05 [K];
            attribute responseTime = 2.0 [s];
        }
        
        part pressSensor : PressureTransducer {
            attribute accuracy = 0.1 [bar];
            attribute measurementRange = 100.0 [bar];
        }
        
        part processor : DigitalSignalProcessor {
            attribute processingRate = 50000.0 [Hz];
            attribute filterBandwidth = 500.0 [Hz];
        }
        
        part processFluid : ProcessFluid;
        
        connect driver.mechanicalDrive to uTube.mechanicalOutput;
        connect uTube.mechanicalOutput to leftSensor.mechanicalInput;
        connect uTube.mechanicalOutput to rightSensor.mechanicalInput;
        connect leftSensor.digitalOutput to processor.sensorInput1;
        connect rightSensor.digitalOutput to processor.sensorInput2;
        connect tempSensor.temperatureOutput to processor.temperatureInput;
        connect pressSensor.pressureOutput to processor.pressureInput;
        connect processor.controlOutput to driver.controlInput;
        connect tempSensor.measurementPoint to uTube.fluidInlet;
        connect pressSensor.measurementPoint to uTube.fluidInlet;
        
        flow processFluid from uTube.fluidInlet to uTube.fluidOutlet;
        
        perform action densityMeasurement : PerformDensityMeasurement {
            in fluid = processFluid;
            out measuredDensity;
            out measuredMassFlow;
            out measurementQuality;
        }
        
        exhibit state operatingStates : DensitometerStates;
    }

    requirement def MeasurementPerformanceRequirement {
        doc /* Defines accuracy and precision requirements for density measurement. */
        
        require constraint densityAccuracy {
            doc /* Density measurement accuracy shall be ±0.1 kg/m³ over the full range. */
        }
        
        require constraint repeatability {
            doc /* Measurement repeatability shall be ±0.05 kg/m³. */
        }
        
        require constraint responseTime {
            doc /* System response time to 95% of final value shall be less than 2 seconds. */
        }
    }

    requirement def OperatingRangeRequirement {
        doc /* Defines the operating envelope for the densitometer. */
        
        require constraint densityRange {
            doc /* Measurable density range shall be 0 to 3000 kg/m³. */
        }
        
        require constraint temperatureRange {
            doc /* Operating temperature range shall be -50°C to +200°C. */
        }
        
        require constraint pressureRange {
            doc /* Operating pressure range shall be 0 to 100 bar. */
        }
        
        require constraint viscosityRange {
            doc /* Measurable viscosity range shall be 0.1 to 1000 mPa·s. */
        }
    }

    requirement def ReliabilityRequirement {
        doc /* Defines reliability and availability requirements. */
        
        require constraint mtbf {
            doc /* Mean time between failures shall exceed 50,000 hours. */
        }
        
        require constraint calibrationInterval {
            doc /* Calibration interval shall be at least 12 months. */
        }
    }

    requirement def SafetyRequirement {
        doc /* Defines safety requirements for hazardous area operation. */
        
        require constraint explosionProtection {
            doc /* System shall be certified for Zone 1 hazardous areas. */
        }
        
        require constraint materialCompatibility {
            doc /* Wetted materials shall be compatible with corrosive process fluids. */
        }
    }

    requirement <'UTDS-001'> primarySystemRequirement {
        doc /* 
            The Oscillating U-Tube Densitometer System shall continuously measure
            the density and mass flow rate of process fluids by exploiting the principle
            that a fluid-filled vibrating tube's resonant frequency is directly related
            to the mass of fluid contained within it. The system induces controlled
            oscillations in a U-shaped tube at its natural frequency, then precisely
            measures the oscillation period. Since the tube's effective mass includes
            both the tube structure and the fluid inside, changes in fluid density
            directly alter the resonant frequency according to the relationship:
            density = K1 * period² - K2, where K1 and K2 are calibration constants.
            This enables non-intrusive, highly accurate density measurement across
            a wide range of process conditions, with simultaneous temperature
            compensation to ensure measurement integrity.
        */
        
        subject oscillatingUTubeDensitometer : OscillatingUTubeDensitometer;
        
        require measurementPerformance : MeasurementPerformanceRequirement;
        require operatingRange : OperatingRangeRequirement;
        require reliability : ReliabilityRequirement;
        require safety : SafetyRequirement;
        
        satisfy measurementPerformance.densityAccuracy by oscillatingUTubeDensitometer.densityMeasurement;
        satisfy operatingRange.densityRange by oscillatingUTubeDensitometer.uTube;
        satisfy reliability.mtbf by oscillatingUTubeDensitometer;
    }

    part oscillatingUTubeDensitometer : OscillatingUTubeDensitometer;
}
