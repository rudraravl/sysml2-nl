package PyranometerMeasurementSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def IrradianceValue :> ISQ::PowerPerAreaValue {
        doc /* Solar irradiance in watts per square meter (W/m²) */
    }
    
    attribute def SensorVoltageValue :> ISQ::ElectricPotentialValue {
        doc /* Thermopile output voltage in millivolts (mV) */
    }
    
    attribute def AmbientTemperatureValue :> ISQ::ThermodynamicTemperatureValue {
        doc /* Ambient temperature in Kelvin (K) */
    }
    
    attribute def CalibrationConstant :> Real {
        doc /* Calibration factor in (W/m²)/mV */
    }
    
    attribute def TimestampValue :> String {
        doc /* ISO 8601 timestamp */
    }
    
    item def IrradianceMeasurement {
        attribute timestamp : TimestampValue;
        attribute irradiance : IrradianceValue;
        attribute temperature : AmbientTemperatureValue;
        attribute rawVoltage : SensorVoltageValue;
    }
    
    port def SolarRadiationInputPort {
        in item incidentRadiation : IrradianceValue;
    }
    
    port def ThermopileOutputPort {
        out item thermopileVoltage : SensorVoltageValue;
    }
    
    port def AnalogInputPort {
        in item analogSignal : SensorVoltageValue;
    }
    
    port def DigitalOutputPort {
        out item digitalData : IrradianceMeasurement;
    }
    
    port def CommunicationPort {
        out item transmittedData : IrradianceMeasurement;
    }
    
    port def PowerSupplyPort {
        in item supplyVoltage : ISQ::ElectricPotentialValue;
    }
    
    part def ThermopileSensor {
        doc /* 
            Thermopile detector that converts incident solar radiation 
            into a proportional electrical voltage signal 
        */
        
        attribute sensitivity : CalibrationConstant;
        attribute spectralRange : String;
        attribute viewAngle : Real;
        
        port radiationInput : SolarRadiationInputPort;
        port voltageOutput : ThermopileOutputPort;
        
        perform action convertRadiationToVoltage {
            in solarFlux : IrradianceValue;
            out outputVoltage : SensorVoltageValue;
        }
    }
    
    part def GlassDomeAssembly {
        doc /* 
            Protective glass dome with specific spectral transmission 
            characteristics for solar spectrum 
        */
        
        attribute transmittance : Real;
        attribute spectralBandwidth : String;
        attribute domeThickness : ISQ::LengthValue;
        
        port externalRadiation : SolarRadiationInputPort;
        port transmittedRadiation : SolarRadiationInputPort;
        
        perform action transmitRadiation {
            in incomingFlux : IrradianceValue;
            out transmittedFlux : IrradianceValue;
        }
    }
    
    part def TemperatureCompensationSensor {
        doc /* Internal temperature sensor for thermal compensation */
        
        attribute accuracy : AmbientTemperatureValue;
        attribute range : String;
        
        perform action measureAmbientTemperature {
            out ambientTemp : AmbientTemperatureValue;
        }
    }
    
    part def SignalConditioner {
        doc /* 
            Amplifies and conditions the thermopile signal 
            for analog-to-digital conversion 
        */
        
        attribute gain : Real;
        attribute bandwidth : ISQ::FrequencyValue;
        
        port analogInput : AnalogInputPort;
        port conditionedOutput : ThermopileOutputPort;
        port powerIn : PowerSupplyPort;
        
        perform action amplifyAndFilter {
            in rawSignal : SensorVoltageValue;
            out conditionedSignal : SensorVoltageValue;
        }
    }
    
    part def DataAcquisitionUnit {
        doc /* 
            Converts analog voltage to digital irradiance values 
            using calibration constants and temperature compensation 
        */
        
        attribute resolution : Integer;
        attribute samplingRate : ISQ::FrequencyValue;
        attribute calibrationFactor : CalibrationConstant;
        
        port analogIn : AnalogInputPort;
        port dataOut : DigitalOutputPort;
        port powerIn : PowerSupplyPort;
        
        perform action convertAndCalibrate {
            in voltage : SensorVoltageValue;
            in temperature : AmbientTemperatureValue;
            in calibration : CalibrationConstant;
            out measurement : IrradianceMeasurement;
        }
    }
    
    part def DataStorageModule {
        doc /* Stores measurement data with timestamps */
        
        attribute capacity : Integer;
        attribute memoryUsed : Integer;
        attribute storedMeasurements : IrradianceMeasurement[*];
        
        port dataInput : DigitalOutputPort;
        port powerIn : PowerSupplyPort;
        
        perform action storeMeasurement {
            in newMeasurement : IrradianceMeasurement;
        }
    }
    
    part def CommunicationInterface {
        doc /* Transmits measurement data to external systems */
        
        attribute protocol : String;
        attribute baudRate : Integer;
        
        port dataIn : DigitalOutputPort;
        port commOut : CommunicationPort;
        port powerIn : PowerSupplyPort;
        
        perform action transmitData {
            in measurement : IrradianceMeasurement;
            out transmittedPacket : IrradianceMeasurement;
        }
    }
    
    part def PowerManagementUnit {
        doc /* Manages power distribution to all subsystems */
        
        attribute inputVoltage : ISQ::ElectricPotentialValue;
        attribute outputVoltage : ISQ::ElectricPotentialValue;
        attribute efficiency : Real;
        
        port externalPower : PowerSupplyPort;
        port regulatedOutput : PowerSupplyPort;
        
        perform action regulatePower {
            in inputPower : ISQ::ElectricPotentialValue;
            out outputPower : ISQ::ElectricPotentialValue;
        }
    }
    
    part def PyranometerInstrument {
        doc /* 
            Complete pyranometer instrument assembly for measuring 
            global horizontal solar irradiance 
        */
        
        attribute serialNumber : String;
        attribute calibrationDate : TimestampValue;
        attribute operatingTemperatureRange : String;
        attribute measurementRange : String;
        
        part dome : GlassDomeAssembly {
            attribute :>> transmittance = 0.95;
            attribute :>> spectralBandwidth = "285-2800 nm";
        }
        
        part thermopile : ThermopileSensor {
            attribute :>> sensitivity = 10.0;
            attribute :>> spectralRange = "300-2800 nm";
            attribute :>> viewAngle = 180.0;
        }
        
        part tempSensor : TemperatureCompensationSensor {
            attribute :>> accuracy = 0.5;
            attribute :>> range = "233-353 K";
        }
        
        part conditioner : SignalConditioner {
            attribute :>> gain = 100.0;
            attribute :>> bandwidth = 10.0;
        }
        
        part daq : DataAcquisitionUnit {
            attribute :>> resolution = 16;
            attribute :>> samplingRate = 1.0;
            attribute :>> calibrationFactor = 10.0;
        }
        
        part storage : DataStorageModule {
            attribute :>> capacity = 100000;
            attribute :>> memoryUsed = 0;
        }
        
        part comms : CommunicationInterface {
            attribute :>> protocol = "RS-485";
            attribute :>> baudRate = 9600;
        }
        
        part power : PowerManagementUnit {
            attribute :>> inputVoltage = 12.0;
            attribute :>> outputVoltage = 5.0;
            attribute :>> efficiency = 0.85;
        }
        
        connect dome.transmittedRadiation to thermopile.radiationInput;
        connect thermopile.voltageOutput to conditioner.analogInput;
        connect conditioner.conditionedOutput to daq.analogIn;
        connect daq.dataOut to storage.dataInput;
        connect storage.dataInput to comms.dataIn;
        connect power.regulatedOutput to conditioner.powerIn;
        connect power.regulatedOutput to daq.powerIn;
        connect power.regulatedOutput to storage.powerIn;
        connect power.regulatedOutput to comms.powerIn;
    }
    
    action def MeasureSolarIrradiance {
        doc /* 
            Primary measurement action that continuously monitors 
            and records solar irradiance 
        */
        
        in incidentSolarRadiation : IrradianceValue;
        out recordedMeasurements : IrradianceMeasurement[*];
        
        first start;
        then merge continuousMeasurement;
        
        action filterRadiation {
            in incomingRadiation : IrradianceValue;
            out filteredRadiation : IrradianceValue;
        }
        
        then action generateThermopileVoltage {
            in solarFlux : IrradianceValue;
            out thermopileSignal : SensorVoltageValue;
        }
        
        then action conditionSignal {
            in rawVoltage : SensorVoltageValue;
            out amplifiedVoltage : SensorVoltageValue;
        }
        
        then action measureTemperature {
            out currentTemperature : AmbientTemperatureValue;
        }
        
        then action convertToIrradiance {
            in voltage : SensorVoltageValue;
            in temperature : AmbientTemperatureValue;
            out irradianceReading : IrradianceValue;
        }
        
        then action createMeasurementRecord {
            in irradiance : IrradianceValue;
            in temp : AmbientTemperatureValue;
            in voltage : SensorVoltageValue;
            out record : IrradianceMeasurement;
        }
        
        then action storeRecord {
            in measurement : IrradianceMeasurement;
        }
        
        then action transmitRecord {
            in measurement : IrradianceMeasurement;
        }
        
        then continuousMeasurement;
    }
    
    attribute def PowerOnCommand;
    attribute def MaintenanceRequest;
    attribute def ShutdownCommand;
    
    state def PyranometerOperationalStates {
        doc /* State machine governing pyranometer operational modes */
        
        attribute selfTestPassed : Boolean;
        attribute thermallyStable : Boolean;
        attribute calibrationLoaded : Boolean;
        attribute maintenanceComplete : Boolean;
        
        entry; then powerOff;
        
        state powerOff {
            doc /* System is not powered */
        }
        
        transition powerOff_to_initialization
            first powerOff
            accept powerOnCmd : PowerOnCommand
            then initialization;
        
        state initialization {
            doc /* System initialization and self-test */
            entry action performSelfTest;
        }
        
        transition initialization_to_warmup
            first initialization
            if selfTestPassed
            then warmup;
        
        state warmup {
            doc /* Thermal stabilization period */
            entry action stabilizeThermopile;
        }
        
        transition warmup_to_calibration
            first warmup
            if thermallyStable
            then calibration;
        
        state calibration {
            doc /* Apply calibration constants */
            entry action loadCalibrationData;
        }
        
        transition calibration_to_measuring
            first calibration
            if calibrationLoaded
            then measuring;
        
        state measuring {
            doc /* Active continuous measurement mode */
            entry action startContinuousSampling;
            do action acquireAndRecordData;
        }
        
        transition measuring_to_maintenance
            first measuring
            accept maintReq : MaintenanceRequest
            then maintenance;
        
        state maintenance {
            doc /* Maintenance and recalibration mode */
            entry action pauseMeasurement;
            do action performMaintenance;
        }
        
        transition maintenance_to_measuring
            first maintenance
            if maintenanceComplete
            then measuring;
        
        transition measuring_to_powerOff
            first measuring
            accept shutdownCmd : ShutdownCommand
            then powerOff;
        
        action def performSelfTest;
        action def stabilizeThermopile;
        action def loadCalibrationData;
        action def startContinuousSampling;
        action def acquireAndRecordData;
        action def pauseMeasurement;
        action def performMaintenance;
    }
    
    requirement def AccuracyRequirement {
        doc /* Measurement accuracy requirement */
        
        subject instrument : PyranometerInstrument;
        
        require constraint {
            doc /* Daily total irradiance accuracy shall be within ±2% */
            instrument.daq.calibrationFactor > 0.0
        }
    }
    
    requirement def SpectralRangeRequirement {
        doc /* Spectral response requirement */
        
        subject sensor : ThermopileSensor;
        
        require constraint {
            doc /* Spectral range shall cover 300-2800 nm */
            sensor.spectralRange == "300-2800 nm"
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* Response time requirement */
        
        subject system : PyranometerInstrument;
        
        require constraint {
            doc /* 95% response time shall be less than 5 seconds */
            system.daq.samplingRate >= 1.0
        }
    }
    
    requirement def OperatingRangeRequirement {
        doc /* Operating temperature range requirement */
        
        subject instrument : PyranometerInstrument;
        
        require constraint {
            doc /* Operating range shall be -40°C to +80°C */
            instrument.operatingTemperatureRange == "233-353 K"
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level system requirements */
        
        require accuracy : AccuracyRequirement;
        require spectralRange : SpectralRangeRequirement;
        require responseTime : ResponseTimeRequirement;
        require operatingRange : OperatingRangeRequirement;
    }
    
    part pyranometerSystem : PyranometerInstrument {
        doc /* 
            The pyranometer system measures global horizontal solar irradiance 
            on a planar surface. Its primary function is to continuously monitor 
            and accurately record the total hemispherical solar radiation received 
            from a 180-degree field of view. The system converts incident solar 
            radiation into calibrated electrical signals using a thermopile detector, 
            applies temperature compensation for ambient conditions, digitizes the 
            signal with high-resolution analog-to-digital conversion, and outputs 
            standardized irradiance measurements in watts per square meter (W/m²). 
            This data is essential for solar energy resource assessment, photovoltaic 
            system performance monitoring, meteorological observations, and climate 
            research applications.
        */
        
        attribute :>> serialNumber = "PYR-2024-SN-12345";
        attribute :>> calibrationDate = "2024-01-15T10:00:00Z";
        attribute :>> operatingTemperatureRange = "233-353 K";
        attribute :>> measurementRange = "0-2000 W/m²";
        
        perform action measureIrradiance : MeasureSolarIrradiance;
        
        exhibit state operationalStates : PyranometerOperationalStates;
    }
}
